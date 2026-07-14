#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENV_FILE="${ENV_FILE:-${ROOT_DIR}/.env}"
source "${ROOT_DIR}/scripts/common.sh"
[[ -f "${ENV_FILE}" ]] || exit 0
load_env_file "${ENV_FILE}"

if [[ -z "${FD_STACK_DEPLOYMENT_ID:-}" || -z "${FD_STACK_STATUS_REPORT_URL:-}" || -z "${FD_STACK_STATUS_REPORT_TOKEN:-}" ]]; then
  exit 0
fi

payload="$(jq -n \
  --arg deploymentId "${FD_STACK_DEPLOYMENT_ID}" \
  --arg token "${FD_STACK_STATUS_REPORT_TOKEN}" \
  --arg current "${FD_EDU_RUNTIME_IMAGE:-}" \
  --arg available "${AVAILABLE_FD_EDU_RUNTIME_IMAGE:-}" \
  --arg offeredAt "${LAST_RUNTIME_IMAGE_OFFERED_AT:-}" \
  --arg appliedAt "${LAST_RUNTIME_IMAGE_APPLIED_AT:-}" \
  'def optional: if length > 0 then . else null end; {deploymentId:$deploymentId,token:$token,runtimeAssets:{current:{"fd-edu-runtime-image":($current|optional)},available:{"fd-edu-runtime-image":($available|optional)},offeredAt:($offeredAt|optional),appliedAt:($appliedAt|optional)}}')"

curl -fsSL -X POST "${FD_STACK_STATUS_REPORT_URL}" -H 'content-type: application/json' -d "${payload}" >/dev/null
