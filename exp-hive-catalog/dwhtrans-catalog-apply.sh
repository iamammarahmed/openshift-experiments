#!/usr/bin/env bash
set -euo pipefail

# Allow overriding the CLI via KUBECTL env var, default to oc for OpenShift.
KUBECTL_BIN="${KUBECTL:-oc}"
if ! command -v "${KUBECTL_BIN}" >/dev/null 2>&1; then
  echo "error: required CLI '${KUBECTL_BIN}' not found in PATH" >&2
  exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Optional namespace argument; leave empty to use the current CLI context.
NAMESPACE="${1:-}"

manifests=(
  "dwhtrans-catalog-serviceaccount-01.yaml"
  "dwhtrans-catalog-s3-secret-02.yaml"
  "dwhtrans-catalog-configmap-03.yaml"
  "dwhtrans-catalog-db-secret-04.yaml"
  "dwhtrans-catalog-postgres-05.yaml"
  "dwhtrans-catalog-service-06.yaml"
  "dwhtrans-catalog-deployment-07.yaml"
  "dwhtrans-catalog-schema-loader-pvc-08.yaml"
  "dwhtrans-catalog-schema-loader-deployment-09.yaml"

)

apply_args=()
if [[ -n "${NAMESPACE}" ]]; then
  apply_args+=("-n" "${NAMESPACE}")
fi

for manifest in "${manifests[@]}"; do
  echo "Applying ${manifest}"
  "${KUBECTL_BIN}" apply -f "${SCRIPT_DIR}/${manifest}" "${apply_args[@]}"
done
