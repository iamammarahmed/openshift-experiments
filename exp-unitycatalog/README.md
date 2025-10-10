# Unity Catalog OSS on OpenShift with JupyterHub and NetApp Storage

This experiment demonstrates how to deploy the open-source Unity Catalog (UC) service on an OpenShift
cluster and integrate it with JupyterHub-backed Spark notebooks and a NetApp StorageGRID / ONTAP S3
object store.  The manifests intentionally avoid hard-coded secrets and are designed to be used with
a GitOps workflow (e.g. Argo CD) or with `oc apply -k`.

## Solution overview

```
┌────────────────────────────────────────────────────────────────────────────┐
│                              OpenShift Project                              │
│                                                                            │
│  ┌──────────────┐    ┌────────────────────┐    ┌────────────────────────┐  │
│  │  JupyterHub  │    │  Spark Cluster/Op  │    │     Unity Catalog      │  │
│  │ (Helm chart) │    │ (spark-defaults)   │    │  (OSS REST service)    │  │
│  └─────┬────────┘    └─────┬──────────────┘    └──────────┬────────────┘  │
│        │                   │                               │               │
│        │                   │  JDBC / REST                  │               │
│        │                   └──────────────┬────────────────┘               │
│        │                                  │                                │
│        ▼                                  ▼                                │
│  NetApp S3 bucket  <───────────  Unity Catalog metadata (PostgreSQL)       │
└────────────────────────────────────────────────────────────────────────────┘
```

* **Unity Catalog OSS** runs as a stateless deployment backed by a PostgreSQL metadata store and
  configured to use a NetApp S3 bucket for managed tables, volumes, and access control storage.
* **JupyterHub** is deployed with the "Zero to JupyterHub" Helm chart. Single-user notebook pods
  inject Spark configuration snippets that point to the Unity Catalog endpoint and S3 credentials.
* **Spark** notebooks (e.g. `pyspark`, SparkMagic, or Spark-on-K8s Operator) use the provided
  `spark-defaults.conf` to interact with Unity Catalog tables via the OSS REST protocol.

## Repository layout

```
exp-unitycatalog/
├── README.md                          # This document
├── kustomization.yaml                 # Stitch all base manifests together
├── namespace.yaml                     # Dedicated OpenShift project/namespace
├── secrets/
│   ├── netapp-s3-credentials.yaml
│   ├── unitycatalog-db-secret.yaml
│   └── unitycatalog-service-secret.yaml
├── unitycatalog/
│   ├── configmap.yaml                 # UC configuration (env + spark defaults)
│   ├── deployment.yaml                # UC API server pod + readiness probes
│   ├── postgresql.yaml                # Optional embedded PostgreSQL instance
│   ├── route.yaml                     # OpenShift Route for external access
│   └── service.yaml                   # ClusterIP service fronting UC pods
├── jupyterhub/
│   ├── values.yaml                    # Helm overrides for Z2JH
│   └── spark-defaults-configmap.yaml  # Inject Spark config + env vars
└── spark/
    └── serviceaccount.yaml            # RBAC + secrets for Spark pods
```

The manifests are designed so you can start with the namespace and secrets and then deploy the rest of
resources with Kustomize.

## Prerequisites

1. An OpenShift 4.11+ cluster with the following operators installed:
   * OpenShift Pipelines (optional for CI/CD)
   * OpenShift GitOps or Argo CD (optional but recommended)
   * Red Hat OpenShift Data Science or certified Spark Operator (for managed Spark clusters)
2. NetApp StorageGRID or ONTAP S3 endpoint with a dedicated bucket for Unity Catalog managed tables.
3. TLS certificates (self-signed or custom CA) that match the Unity Catalog Route hostname.
4. Unity Catalog OSS container image published to an accessible registry, e.g.
   `ghcr.io/databricks/unity-catalog-oss:latest`.
5. JupyterHub Helm chart repository added to your tooling (e.g. `helm repo add jupyterhub`).

## Usage

### 1. Create namespace and secrets

Update the secret manifests under `secrets/` **and** the Helm override file in `jupyterhub/values.yaml`
with production values before applying them. The examples are intentionally annotated with
`app.kubernetes.io/part-of: unity-catalog` so you can keep track of related credentials.

```
oc apply -f exp-unitycatalog/namespace.yaml
oc apply -f exp-unitycatalog/secrets/netapp-s3-credentials.yaml
oc apply -f exp-unitycatalog/secrets/unitycatalog-db-secret.yaml
oc apply -f exp-unitycatalog/secrets/unitycatalog-service-secret.yaml
```

### 2. Deploy Unity Catalog components

```
oc apply -k exp-unitycatalog
```

This creates the PostgreSQL instance, Unity Catalog deployment, service, and OpenShift route. You can
swap out `unitycatalog/postgresql.yaml` with an external managed database if desired.

> **Do I need `server.properties` and `hibernate.properties`?**
>
> The upstream Unity Catalog OSS container can be configured entirely through environment variables,
> which is what the manifests in this repository do by default. If you would rather manage the
> traditional property files, use the sample `unitycatalog/properties-configmap.yaml` manifest and
> mount it into the deployment:
>
> ```shell
> # enable the sample config map
> oc apply -f exp-unitycatalog/unitycatalog/properties-configmap.yaml
>
> # add the config volume to the Unity Catalog pods
> oc patch deployment/unitycatalog \
>   -n unity-catalog \
>   --type merge \
>   -p '{
>     "spec": {
>       "template": {
>         "spec": {
>           "containers": [{
>             "name": "api",
>             "volumeMounts": [{
>               "name": "unitycatalog-properties",
>               "mountPath": "/opt/unitycatalog/conf",
>               "readOnly": true
>             }]
>           }],
>           "volumes": [{
>             "name": "unitycatalog-properties",
>             "configMap": {
>               "name": "unitycatalog-properties"
>             }
>           }]
>         }
>       }
>     }
>   }'
> ```
>
> Update the values in the config map to match your environment (for example, change the PostgreSQL
> host or adjust pool sizes) before rolling the deployment. Secrets such as the JDBC password continue
> to be sourced from Kubernetes secrets via environment variables, so they do not need to be duplicated
> in the property files.

### 3. Install JupyterHub (Helm)

The `jupyterhub/values.yaml` file contains overrides to inject the Unity Catalog connection
information into user pods. Update the Route hostname (`unitycatalog-unity-catalog.apps.example.com`)
to match your cluster and then install the chart:

```
helm upgrade --install jhub jupyterhub/jupyterhub \
  --namespace unity-catalog \
  --values exp-unitycatalog/jupyterhub/values.yaml
```

When a notebook starts, it mounts the `spark-defaults` config map so that PySpark or Scala Spark
sessions automatically register Unity Catalog as the default metastore.

### 4. Validate with a notebook

Launch a Jupyter notebook and run:

```python
from pyspark.sql import SparkSession

spark = SparkSession.builder \
    .appName("uc-smoke-test") \
    .config("spark.sql.catalog.unity", "com.databricks.unity.catalog") \
    .getOrCreate()

spark.sql("SHOW CATALOGS").show()
```

If everything is wired correctly you should see your Unity Catalog catalogs and schemas.

## Customisation tips

* Replace the bundled PostgreSQL definition with an enterprise-grade database (Amazon RDS, Cloud
  SQL, etc.) by updating the `UNITYCATALOG_JDBC_URL` in `unitycatalog/configmap.yaml`.
* To integrate with enterprise auth (e.g. OAuth2 / OIDC), mount an additional secret and add
  environment variables under the Unity Catalog container definition.
* Extend `jupyterhub/spark-defaults-configmap.yaml` with cluster-specific Spark tweaks (executor
  images, shuffle service settings, etc.).
* For highly available Unity Catalog, scale the deployment to `replicas: 3` and use a managed
  database with synchronous replication.

## Cleanup

```
oc delete -k exp-unitycatalog
```

This removes the Unity Catalog workload while leaving the secrets intact. Delete the secrets and
namespace manually if you no longer need them.
