# Platform Utilities

This directory hosts operational Kubernetes manifests that can be deployed on-demand or scheduled for routine upkeep tasks. None of these workloads are long-lived application services—they are all utilities you can launch when you need to troubleshoot, inspect resource usage, or clean up storage.

## Network Test Pods
- `ops-network-test-pod-pod.yaml` – Minimal Alpine-based pod preloaded with common networking tools for manual connectivity checks.
- `ops-network-test-pod-alt-pod.yaml` – Alternate build that adds OpenSSL support for TLS and certificate debugging.

## PVC Cleanup Deployments
- `ops-pvc-cleanup-deployment.yaml` – Watches a PVC and purges data when usage exceeds the configured threshold.
- `ops-pvc-cleanup-deployment-alt.yaml` – Variant tuned for the alternate namespace naming used in dwh environments.

## S3 Bucket Usage Monitors
- `ops-s3-bucket-usage-deployment.yaml` – Continuous deployment that monitors S3 usage and prunes stale objects when space is tight.
- `ops-s3-bucket-usage-job.yaml` – One-shot Job for ad-hoc bucket checks and cleanup.
- `ops-s3-bucket-usage-cronjob.yaml` – Scheduled CronJob that runs the same logic on an interval.
- `ops-s3-bucket-usage-deployment-alt.yaml` – Deployment variant configured for the dwh namespace and endpoint conventions.
- `ops-network-test-pod.yaml` – Minimal Alpine-based pod preloaded with common networking tools for manual connectivity checks.
- `ops-network-test-pod-alt.yaml` – Alternate build that adds OpenSSL support for TLS and certificate debugging.

## PVC Cleanup Deployments
- `ops-pvc-cleanup-dep.yaml` – Watches a PVC and purges data when usage exceeds the configured threshold.
- `ops-pvc-cleanup-dep-alt.yaml` – Variant tuned for the alternate namespace naming used in dwh environments.

## S3 Bucket Usage Monitors
- `ops-s3-bucket-usage-dep.yaml` – Continuous deployment that monitors S3 usage and prunes stale objects when space is tight.
- `ops-s3-bucket-usage-job.yaml` – One-shot Job for ad-hoc bucket checks and cleanup.
- `ops-s3-bucket-usage-cronjob.yaml` – Scheduled CronJob that runs the same logic on an interval.
- `ops-s3-bucket-usage-dep-alt.yaml` – Deployment variant configured for the dwh namespace and endpoint conventions.
- `ops-s3-bucket-usage-job-alt.yaml` – Job variant matching the dwh-specific configuration.
- `ops-s3-bucket-usage-cronjob-alt.yaml` – CronJob variant tuned for dwh cadence (every 20 minutes).

All manifests assume the necessary Kubernetes secrets and persistent volumes already exist in the target cluster.
