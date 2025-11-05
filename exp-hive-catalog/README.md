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
* `dwhtrans-catalog-schema-loader-pvc-08.yaml` – PersistentVolumeClaim
  that stores the downloaded schema artifacts from NetApp S3 for the loader pod.
* `dwhtrans-catalog-schema-loader-deployment-09.yaml` – Auxiliary
  deployment that syncs the latest schema definition from S3 and executes the
  Hive DDL it contains against the metastore.
* `dwhtrans-catalog-validate.sh` – Helper script that waits for the
  deployment to become available and performs a basic health probe from inside
  the metastore pod.

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

### Validating the metastore

After the manifests are applied and the pods have started, execute
`./dwhtrans-catalog-validate.sh` (optionally passing the namespace as the first
argument) to confirm the deployment is healthy. The script:

1. Waits for `dwhtrans-catalog-deployment` to report as available.
2. Locates the metastore pod via the shared catalog labels.
3. Runs `schematool -info` inside the pod to verify connectivity with the
   PostgreSQL backing store.
4. Opens a local TCP connection to port 9083 from inside the pod to confirm the
   metastore thrift endpoint is accepting requests.

Any failure in these checks stops the script with a non-zero exit code so
automations can detect a problem quickly.

## Customizing for client deployments

When adapting the catalog stack for a specific client environment, review and
update the following items before applying the manifests or running the helper
script:

* **Namespace** – Pass the target namespace to
  `./dwhtrans-catalog-apply.sh <namespace>` or set `-n <namespace>` manually if
  you apply the manifests yourself. Rename the `metadata.namespace` fields
  embedded in any manifest if the client does not want to rely on CLI
  overrides.
* **Service account** – Change the metadata in
  `dwhtrans-catalog-serviceaccount-01.yaml` if the client requires a specific
  name or annotations, and make matching updates to the `serviceAccountName`
  fields in the PostgreSQL StatefulSet and Hive deployment manifests. The
  schema loader deployment also references the same service account.
* **Secrets** – Replace the placeholder values in both
  `dwhtrans-catalog-s3-secret-02.yaml` and
  `dwhtrans-catalog-db-secret-04.yaml` with the client's S3 credentials and
  database passwords. Update the secret names if the organization enforces
  naming standards, keeping the references in the deployment, StatefulSet, and
  schema loader manifests in sync. Rotate these secrets whenever the upstream
  credentials change.
* **ConfigMap settings** – Adjust warehouse directories, S3 endpoints, JDBC
  URLs, Hive metastore URIs, and any other Hive configuration settings in
  `dwhtrans-catalog-configmap-03.yaml` to match the client's environment.
  Ensure any additional properties required by security teams (for example TLS
  settings or proxy configuration) are present.
* **Database configuration** – Tweak the image tag, storage size, and resource
  requests in `dwhtrans-catalog-postgres-05.yaml` if the client provides a
  managed database or requires different sizing. Update the connection details
  in the Hive ConfigMap accordingly if an external database replaces the sample
  StatefulSet.
* **Schema loader specifics** – Update the `SCHEMA_S3_PREFIX` placeholder in
  `dwhtrans-catalog-schema-loader-deployment-09.yaml` so it targets the folder
  that holds the Hive DDL files in the client's NetApp S3 bucket. Increase the
  storage request in `dwhtrans-catalog-schema-loader-pvc-08.yaml` if the schema
  artifacts are large, and adjust the container image or command if the client
  uses a different Hive CLI wrapper.
* **Labels and annotations** – Apply any mandatory governance labels or
  annotations required by the client's cluster policy across all manifests to
  maintain consistency with organizational standards.

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

### Automatic schema registration

The schema loader deployment runs alongside the metastore to keep table
definitions in sync with the contents of a NetApp S3 folder:

1. An init container based on the AWS CLI lists the keys under
   `SCHEMA_S3_PREFIX` and copies the most recently modified object onto the PVC
   created by `dwhtrans-catalog-schema-loader-pvc-08.yaml`.
2. The main container uses the Hive CLI to run the downloaded `.sql` or `.hql`
   file so that any `CREATE TABLE` statements are registered in the metastore.
3. The pod remains running after a successful execution so you can inspect the
   logs or rerun the pod if a new schema needs to be applied.

Before deploying to a client environment, set the `SCHEMA_S3_PREFIX` value to
the folder that contains the DDL artifacts and confirm the credentials in
`dwhtrans-catalog-s3-secret-02.yaml` have permission to read the objects.
