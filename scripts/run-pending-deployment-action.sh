#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENV_FILE="${ENV_FILE:-${ROOT_DIR}/.env}"
source "${ROOT_DIR}/scripts/common.sh"
[[ -f "${ENV_FILE}" ]] || exit 0
load_env_file "${ENV_FILE}"

if [[ -z "${FD_STACK_DEPLOYMENT_ID:-}" || -z "${FD_STACK_STATUS_REPORT_TOKEN:-}" || -z "${FD_STACK_ACTION_PULL_URL:-}" || -z "${FD_STACK_ACTION_COMPLETE_URL:-}" ]]; then
  exit 0
fi

response="$(curl -fsSL -X POST "${FD_STACK_ACTION_PULL_URL}" -H 'content-type: application/json' -d "$(jq -n --arg deploymentId "${FD_STACK_DEPLOYMENT_ID}" --arg token "${FD_STACK_STATUS_REPORT_TOKEN}" '{deploymentId:$deploymentId,token:$token}')")"
action_id="$(printf '%s' "${response}" | jq -r '.action.id // empty')"
action_kind="$(printf '%s' "${response}" | jq -r '.action.kind // empty')"
[[ -n "${action_id}" ]] || exit 0

status=completed
message=""
case "${action_kind}" in
  apply_runtime_images)
    if ! bash "${ROOT_DIR}/scripts/apply-runtime-image-update.sh"; then status=failed; message="Failed to apply FD Edu runtime image"; fi
    ;;
  ignore_runtime_images)
    unset_env_value "${ENV_FILE}" AVAILABLE_FD_EDU_RUNTIME_IMAGE
    unset_env_value "${ENV_FILE}" LAST_RUNTIME_IMAGE_OFFERED_AT
    ;;
  *) status=failed; message="Unsupported action for FD Edu: ${action_kind}" ;;
esac

payload="$(jq -n --arg deploymentId "${FD_STACK_DEPLOYMENT_ID}" --arg token "${FD_STACK_STATUS_REPORT_TOKEN}" --arg actionId "${action_id}" --arg status "${status}" --arg message "${message}" '{deploymentId:$deploymentId,token:$token,actionId:$actionId,status:$status,message:(if ($message|length)>0 then $message else null end)}')"
curl -fsSL -X POST "${FD_STACK_ACTION_COMPLETE_URL}" -H 'content-type: application/json' -d "${payload}" >/dev/null
bash "${ROOT_DIR}/scripts/report-deployment-status.sh" || true
