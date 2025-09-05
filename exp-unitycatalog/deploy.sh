#!/usr/bin/env bash
# Deploy Unity Catalog resources on OpenShift
# Usage: ./deploy.sh [restart]
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# shellcheck source=/dev/null
source "${SCRIPT_DIR}/uc-config.env"

OBJECTS=(configmap.yaml secret.yaml deployment.yaml service.yaml route.yaml)

if [[ ${1:-} == "restart" ]]; then
  echo "Deleting existing Unity Catalog resources..."
  for obj in "${OBJECTS[@]}"; do
    envsubst < "${SCRIPT_DIR}/${obj}" | oc delete -f - --ignore-not-found
  done
fi

echo "Applying Unity Catalog resources..."
for obj in "${OBJECTS[@]}"; do
  envsubst < "${SCRIPT_DIR}/${obj}" | oc apply -f -
done
