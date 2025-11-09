#!/usr/bin/env bash
set -euo pipefail

KUBECTL_BIN="${KUBECTL:-oc}"
if ! command -v "${KUBECTL_BIN}" >/dev/null 2>&1; then
  echo "error: required CLI '${KUBECTL_BIN}' not found in PATH" >&2
  exit 1
fi

NAMESPACE="${1:-}" 

kubectl_args=()
if [[ -n "${NAMESPACE}" ]]; then
  kubectl_args+=("-n" "${NAMESPACE}")
fi

# Ensure the metastore deployment is reported as available before probing it.
echo "Waiting for Hive metastore deployment to become available..."
"${KUBECTL_BIN}" wait deployment/dwhtrans-catalog-deployment \
  --for=condition=Available --timeout=300s "${kubectl_args[@]}"

# Grab the first metastore pod managed by the deployment.
mapfile -t metastore_pods < <("${KUBECTL_BIN}" get pods "${kubectl_args[@]}" \
  -l app.kubernetes.io/name=dwhtrans-catalog,app.kubernetes.io/component=metastore \
  -o jsonpath='{range .items[*]}{.metadata.name}{"\n"}{end}')

if [[ ${#metastore_pods[@]} -eq 0 ]]; then
  echo "error: no metastore pods found" >&2
  exit 1
fi

METASTORE_POD="${metastore_pods[0]}"
echo "Using metastore pod ${METASTORE_POD}"

# Validate the metastore can reach and interrogate the backing PostgreSQL schema.
echo "Running schematool connectivity check..."
"${KUBECTL_BIN}" exec "${kubectl_args[@]}" "${METASTORE_POD}" -- \
  schematool -dbType postgres -info >/dev/null

echo "Probing metastore thrift port..."
"${KUBECTL_BIN}" exec "${kubectl_args[@]}" "${METASTORE_POD}" -- \
  bash -c 'exec 3<>/dev/tcp/localhost/9083 && exec 3>&- 3<&-'

echo "Hive metastore is reachable and responding."
