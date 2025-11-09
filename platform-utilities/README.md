# Platform Utilities

This directory contains operational Kubernetes manifests you can apply on demand or schedule for routine housekeeping. Each resource is a short-lived utility for debugging, monitoring usage, or cleaning up storage—none of them deploys an application service.

## Network Test Pods
- `ops-network-test-pod-pod.yaml` – Launches an Alpine pod with curl and other network tools for manual connectivity checks.
- `ops-network-test-pod-alt-pod.yaml` – Variant that also installs OpenSSL for TLS debugging while keeping the pod idle for interactive use.

## PVC Cleanup Deployments
- `ops-pvc-cleanup-deployment.yaml` – Monitors the `spark-scripts-pvc2` claim and wipes the volume if utilisation reaches 99%.
- `ops-pvc-cleanup-deployment-alt.yaml` – Same cleanup logic but preserves the `spark-scripts-pvc2-cleanup-dep` resource name used in certain clusters.

## S3 Bucket Usage Monitors
### General-purpose manifests
- `ops-s3-bucket-usage-deployment.yaml` – Continuous deployment that checks S3 consumption and deletes 30-day-old objects when usage exceeds 98%.
- `ops-s3-bucket-usage-cronjob.yaml` – Nightly CronJob performing the same threshold check and cleanup cycle.
- `ops-s3-bucket-usage-job.yaml` – One-shot Job you can trigger manually for ad-hoc bucket inspection and pruning.

### DWH-specific manifests
- `ops-s3-bucket-usage-deployment-alt.yaml` – Continuous deployment tuned for the dwh endpoint, enforcing a 60% threshold and restricting deletions to `dwh-spark/` and `dwh-airflow/` prefixes.
- `ops-s3-bucket-usage-cronjob-alt.yaml` – CronJob scheduled every 20 minutes with the same dwh-specific logic and verbose before/after reporting.

All manifests assume the necessary Kubernetes secrets and persistent volumes already exist in the target cluster.
