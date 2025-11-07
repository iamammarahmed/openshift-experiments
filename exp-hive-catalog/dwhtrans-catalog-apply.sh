#!/usr/bin/env bash
set -euo pipefail

# Allow overriding the CLI via KUBECTL env var, default to oc for OpenShift.
KUBECTL_BIN="${KUBECTL:-oc}"
if ! command -v "${KUBECTL_BIN}" >/dev/null 2>&1; then
  echo "error: required CLI '${KUBECTL_BIN}' not found in PATH" >&2
  exit 1
fi

if ! command -v envsubst >/dev/null 2>&1; then
  echo "error: required CLI 'envsubst' not found in PATH" >&2
  exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="${SCRIPT_DIR}/dwhtrans-catalog-settings.env"

if [[ ! -f "${CONFIG_FILE}" ]]; then
  echo "error: configuration file ${CONFIG_FILE} not found" >&2
  exit 1
fi

# Collect variable names before sourcing so we can scope envsubst
declare -a CONFIG_VARS=()
declare -A SEEN_VARS=()
while IFS= read -r line || [[ -n "${line}" ]]; do
  [[ "${line}" =~ ^[A-Za-z_][A-Za-z0-9_]*= ]] || continue
  var_name="${line%%=*}"
  if [[ -z "${SEEN_VARS["${var_name}"]+x}" ]]; then
    CONFIG_VARS+=("${var_name}")
    SEEN_VARS["${var_name}"]=1
  fi
done < "${CONFIG_FILE}"

set -a
# shellcheck disable=SC1090
source "${CONFIG_FILE}"
set +a

envsubst_args=""
if [[ ${#CONFIG_VARS[@]} -gt 0 ]]; then
  envsubst_args="$(printf '${%s} ' "${CONFIG_VARS[@]}")"
  envsubst_args="${envsubst_args% }"
fi

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
  manifest_path="${SCRIPT_DIR}/${manifest}"
  if [[ ! -f "${manifest_path}" ]]; then
    echo "error: manifest ${manifest_path} not found" >&2
    exit 1
  fi

  echo "Applying ${manifest}"
  if [[ -n "${envsubst_args}" ]]; then
    envsubst "${envsubst_args}" < "${manifest_path}" | \
      "${KUBECTL_BIN}" apply -f - "${apply_args[@]}"
  else
    cat "${manifest_path}" | \
      "${KUBECTL_BIN}" apply -f - "${apply_args[@]}"
  fi
done
