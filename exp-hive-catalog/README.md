# Hive Catalog Experiments

This directory contains manifests and experiments related to running a Hive
metastore-backed catalog on OpenShift with NetApp StorageGRID object storage.

## Contents

* `dwhtrans-catalog-settings.env` – Central configuration file consumed by the
  manifests and helper scripts. Update the values in this file to tailor the
  deployment for a specific client before applying anything.
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

### Central configuration file

The `dwhtrans-catalog-settings.env` file captures every customizable value used
by the manifests, from resource names and container images to S3 endpoints,
credentials placeholders, and storage requests. Both helper scripts source the
file and the manifests are rendered with `envsubst`, so editing this single file
is all that is required to adapt the stack for a specific client. Default
entries act as documentation—replace the placeholder secrets and adjust the
resource settings before running any automation.

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

When adapting the catalog stack for a specific client environment, edit
`dwhtrans-catalog-settings.env` and adjust the groups of variables below before
applying the manifests or running either script:

* **Namespace** – Pass the target namespace to
  `./dwhtrans-catalog-apply.sh <namespace>` (or set `-n <namespace>` manually if
  applying manifests yourself). Namespaces are intentionally left out of the
  manifests so the same templates work across clusters.
* **Identity and labels** – Customize `DWT_APP_NAME`, `DWT_PART_OF_LABEL`,
  `DWT_LABEL_AREA`, and the component variables to align with client naming and
  governance standards. Every manifest references these settings for selectors
  and labels.
* **Service account** – Override `DWT_SERVICE_ACCOUNT_NAME` (and, if needed,
  add annotations directly to the YAML) when a client supplies a pre-created
  account or wants a different name.
* **S3 access** – Set `DWT_S3_ACCESS_KEY`, `DWT_S3_SECRET_KEY`, `DWT_S3_BUCKET`,
  `DWT_S3_ENDPOINT`, `DWT_S3_REGION`, and related toggles such as
  `DWT_S3_PATH_STYLE` or `DWT_S3_SSL_ENABLED` to match the NetApp StorageGRID
  environment. `DWT_S3_SCHEMA_PREFIX` determines which folder the schema loader
  monitors for new Hive DDL.
* **Database settings** – Adjust `DWT_DB_IMAGE`, `DWT_DB_NAME`,
  `DWT_DB_USERNAME`, `DWT_DB_PASSWORD`, `DWT_DB_STORAGE_SIZE`, and the resource
  requests/limits to match the client's policy or an external database service.
  Update `DWT_DB_SERVICE_NAME` and related variables if integrating with a
  managed PostgreSQL offering.
* **Metastore workload sizing** – Tune `DWT_METASTORE_IMAGE`,
  `DWT_METASTORE_REPLICAS`, the resource requests/limits, and
  `DWT_METASTORE_JAVA_TOOL_OPTIONS` for production-grade deployments.
* **Schema loader specifics** – Modify the schema loader images, replica count,
  and storage (`DWT_SCHEMA_*` variables) if the client needs different tooling or
  a larger scratch space for downloaded DDL artifacts.

After updating the environment file, rerun the apply script so that the rendered
manifests pick up the new values. Remember to rotate any secrets stored in the
file according to the client's credential lifecycle policies.

## NetApp StorageGRID configuration

Update the related entries in `dwhtrans-catalog-settings.env` before applying
the manifests so the rendered resources contain the correct NetApp details:

* `DWT_S3_ACCESS_KEY`, `DWT_S3_SECRET_KEY`, `DWT_S3_ENDPOINT`, `DWT_S3_BUCKET`,
  and `DWT_S3_REGION` populate the S3 secret and environment variables used by
  the Hive pods.
* Warehouse directories, `fs.s3a.endpoint`, region, and access style values
  (`DWT_S3_BUCKET`, `DWT_S3_ENDPOINT`, `DWT_S3_REGION`, `DWT_S3_PATH_STYLE`, and
  `DWT_S3_SSL_ENABLED`) shape the `hive-site.xml` and `core-site.xml` data in the
  ConfigMap. Provide the endpoint without a scheme (for example
  `storagegrid.example.com:10443`).

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

Before deploying to a client environment, set `DWT_S3_SCHEMA_PREFIX` in the
environment file to the folder that contains the DDL artifacts and confirm the
credentials injected from the S3 secret have permission to read the objects.
