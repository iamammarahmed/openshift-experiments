# Hive Metastore Deployment Assets

This directory contains the Kubernetes resources and helper scripts required to
run a Hive metastore on OpenShift backed by NetApp StorageGRID object storage.
The repository restructure consolidated the manifests into logical folders and
renamed each asset with the `hms-` prefix to make their purpose immediately
clear.

## Directory layout

- **manifests/** – Declarative Kubernetes YAML for the service account, secrets,
  ConfigMap, backing PostgreSQL database, Hive metastore deployment, service,
  and the optional schema loader components.
- **scripts/** – Automation helpers for applying the manifests and validating a
  deployment from the command line.

## Manifest catalog

Apply the manifests in numerical order to provision every component:

1. `manifests/hms-serviceaccount-01.yaml` – Shared service account used by the
   metastore, database, and schema loader pods.
2. `manifests/hms-s3-secret-02.yaml` – NetApp StorageGRID credentials consumed
   by the Hive deployment and schema loader.
3. `manifests/hms-configmap-03.yaml` – Hive configuration (`hive-site.xml` and
   `core-site.xml`) pre-configured for StorageGRID S3 endpoints and warehouse
   buckets.
4. `manifests/hms-db-secret-04.yaml` – Sample secret providing credentials for
   the metastore database connection.
5. `manifests/hms-postgres-statefulset-05.yaml` – PostgreSQL StatefulSet and
   ClusterIP service for the metastore schema store.
6. `manifests/hms-service-06.yaml` – Service that exposes the metastore Thrift
   endpoint on port 9083.
7. `manifests/hms-deployment-07.yaml` – Hive metastore Deployment with mounts
   and environment variables to connect to StorageGRID and PostgreSQL.
8. `manifests/hms-schema-loader-pvc-08.yaml` – PersistentVolumeClaim that holds
   downloaded schema artifacts from StorageGRID.
9. `manifests/hms-schema-loader-deployment-09.yaml` – Auxiliary deployment that
   retrieves Hive DDL from S3 and runs it against the metastore.

All manifests share the label `app.kubernetes.io/part-of=hive-metastore`, so you
can monitor the complete stack with a single selector, for example `oc get pods
-l app.kubernetes.io/part-of=hive-metastore`.

## Helper scripts

- `scripts/hms-deploy.sh` – Applies the manifests in order using the `oc` CLI by
  default (override with `KUBECTL=kubectl`). Pass a namespace as the first
  argument to target a specific project.
- `scripts/hms-validate.sh` – Waits for the Hive metastore deployment to report
  as available, runs `schematool -info` inside the pod to confirm database
  connectivity, and probes the Thrift endpoint from within the container.

Run the deploy script first, then execute the validator to ensure the metastore
is healthy.

## Customization checklist

Before using these assets in a client environment, review the following items:

- **Namespace** – Supply the namespace to `scripts/hms-deploy.sh <namespace>` or
  edit the `metadata.namespace` fields directly.
- **Service account** – Update metadata in
  `manifests/hms-serviceaccount-01.yaml` and keep the `serviceAccountName`
  fields in dependent workloads in sync.
- **Secrets** – Replace placeholder values in
  `manifests/hms-s3-secret-02.yaml` and `manifests/hms-db-secret-04.yaml` with
  real credentials. Adjust names if organizational standards require it and
  update references in the deployments accordingly.
- **ConfigMap settings** – Modify S3 endpoints, warehouse paths, JDBC URLs, and
  other Hive properties in `manifests/hms-configmap-03.yaml` to suit the target
  environment.
- **Database configuration** – Adjust image tags, storage, or resource requests
  in `manifests/hms-postgres-statefulset-05.yaml`, or replace it with an
  external database and update the ConfigMap values.
- **Schema loader settings** – Point `SCHEMA_S3_PREFIX` in
  `manifests/hms-schema-loader-deployment-09.yaml` to the directory that holds
  the Hive DDL files, and resize the PVC if large artifacts are expected.
- **Labels and annotations** – Apply any required governance metadata across all
  manifests to align with cluster policy.

## StorageGRID integration notes

Ensure the following items are configured with environment-specific values:

- `accessKey`, `secretKey`, `endpoint`, `bucket`, and `region` in
  `manifests/hms-s3-secret-02.yaml`.
- Warehouse directories and `fs.s3a.endpoint` within
  `manifests/hms-configmap-03.yaml`.

The Hive deployment injects the S3 credentials as `AWS_ACCESS_KEY_ID` and
`AWS_SECRET_ACCESS_KEY` environment variables and mounts Hadoop configuration so
that the metastore can communicate with NetApp StorageGRID via the S3A
connector. Helper variables `S3_ENDPOINT` and `S3_BUCKET` are also exposed for
troubleshooting and downstream job configuration.

## Automatic schema registration

The schema loader deployment keeps table definitions synchronized with the
contents of the configured StorageGRID bucket:

1. An init container pulls the most recently modified object from
   `SCHEMA_S3_PREFIX` onto the PVC created by
   `manifests/hms-schema-loader-pvc-08.yaml`.
2. The main container runs the downloaded `.sql` or `.hql` file with the Hive
   CLI so any `CREATE TABLE` statements register in the metastore.
3. The pod remains running after success so you can inspect logs or trigger a
   rerun when new schema artifacts are available.

Update the prefix and verify the S3 credentials have read access before running
in production environments.
