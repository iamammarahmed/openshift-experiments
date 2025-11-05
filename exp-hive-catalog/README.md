# Hive Catalog Experiments

This directory contains manifests and experiments related to running a Hive
metastore-backed catalog on OpenShift with NetApp StorageGRID object storage.

## Contents

* `dwhtrans-catalog-serviceaccount-01.yaml` – Service account used by
  both the metastore and backing database pods.
* `dwhtrans-catalog-s3-secret-02.yaml` – Secret containing the NetApp S3
  access key, secret key, bucket, endpoint, and region values consumed by the
  metastore deployment.
* `dwhtrans-catalog-configmap-03.yaml` – Hive configuration bundled as a
  ConfigMap with starter `hive-site.xml` and `core-site.xml` files pointed at the
  NetApp StorageGRID warehouse buckets.
* `dwhtrans-catalog-db-secret-04.yaml` – Sample secret providing database
  credentials. Update the placeholder password prior to deployment.
* `dwhtrans-catalog-postgres-05.yaml` – PostgreSQL StatefulSet and
  Service for the metastore schema store.
* `dwhtrans-catalog-service-06.yaml` – ClusterIP service exposing the
  metastore thrift endpoint.
* `dwhtrans-catalog-deployment-07.yaml` – Deployment of the Hive
  metastore container with mounts and environment variables to reach NetApp S3.

Apply the manifests in the order listed to stand up a fully functional Hive
metastore suitable for experimentation. Ensure a compatible storage class is
available for the PostgreSQL persistent volume claim.

### One-step apply script

Run `./dwhtrans-catalog-apply.sh` from this directory to apply the manifests in
sequence with a single command. The script defaults to using the `oc` CLI, but
you can set `KUBECTL=kubectl` (or any other compatible binary) before running
it. Pass a namespace as the first argument if you want to apply the manifests to
something other than the current CLI context, for example:

```bash
KUBECTL=oc ./dwhtrans-catalog-apply.sh my-catalog-namespace
```

All manifests share the label `app.kubernetes.io/part-of=dwhtrans-catalog`, so a
simple `oc get pods -l app.kubernetes.io/part-of=dwhtrans-catalog` will return
every workload that belongs to this catalog experiment.

## Customizing for client deployments

When adapting the catalog stack for a specific client environment, review and
update the following items before applying the manifests or running the helper
script:

* **Namespace** – Pass the target namespace to
  `./dwhtrans-catalog-apply.sh <namespace>` or set `-n <namespace>` manually if
  you apply the manifests yourself.
* **Service account** – Change the metadata in
  `dwhtrans-catalog-serviceaccount-01.yaml` if the client requires a specific
  name or annotations, and make matching updates to the `serviceAccountName`
  fields in the PostgreSQL StatefulSet and Hive deployment manifests.
* **Secrets** – Replace the placeholder values in both
  `dwhtrans-catalog-s3-secret-02.yaml` and
  `dwhtrans-catalog-db-secret-04.yaml` with the client's S3 credentials and
  database passwords. Update the secret names if the organization enforces
  naming standards, keeping the references in the deployment and StatefulSet in
  sync.
* **ConfigMap settings** – Adjust warehouse directories, S3 endpoints, and any
  other Hive configuration settings in `dwhtrans-catalog-configmap-03.yaml` to
  match the client's environment.

## NetApp StorageGRID configuration

Update the following placeholders with environment-specific values before
applying the manifests:

* `accessKey`, `secretKey`, `endpoint`, `bucket`, and `region` in
  `dwhtrans-catalog-s3-secret-02.yaml`.
* Warehouse directories and S3 endpoint values in
  `dwhtrans-catalog-configmap-03.yaml`. The `fs.s3a.endpoint` value should
  be provided without a URL scheme (for example `storagegrid.example.com:10443`).

The deployment injects the S3 credentials as `AWS_ACCESS_KEY_ID` and
`AWS_SECRET_ACCESS_KEY` environment variables and mounts the Hadoop `core-site`
configuration so that Hive can access NetApp StorageGRID via the S3A connector.
Helper variables `S3_ENDPOINT` and `S3_BUCKET` are also exposed to simplify
debugging and downstream job configuration.
