#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENV_FILE="${ENV_FILE:-${ROOT_DIR}/.env}"
source "${ROOT_DIR}/scripts/common.sh"
NEW_IMAGE="${NEW_FD_EDU_RUNTIME_IMAGE:-${1:-}}"
require_value NEW_IMAGE
load_env_file "${ENV_FILE}"

if [[ "${NEW_IMAGE}" == "${FD_EDU_RUNTIME_IMAGE}" ]]; then
  unset_env_value "${ENV_FILE}" AVAILABLE_FD_EDU_RUNTIME_IMAGE
  exit 0
fi

set_env_value "${ENV_FILE}" AVAILABLE_FD_EDU_RUNTIME_IMAGE "${NEW_IMAGE}"
set_env_value "${ENV_FILE}" LAST_RUNTIME_IMAGE_OFFERED_AT "$(date -u +%Y-%m-%dT%H:%M:%SZ)"

if [[ "${FD_RUNTIME_IMAGE_UPDATE_POLICY:-manual}" == "auto" ]]; then
  bash "${ROOT_DIR}/scripts/apply-runtime-image-update.sh"
else
  bash "${ROOT_DIR}/scripts/report-deployment-status.sh" || true
fi

