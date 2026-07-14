#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENV_FILE="${ENV_FILE:-${ROOT_DIR}/.env}"
source "${ROOT_DIR}/scripts/common.sh"
load_env_file "${ENV_FILE}"
require_value AVAILABLE_FD_EDU_RUNTIME_IMAGE

bash "${ROOT_DIR}/scripts/backup.sh"
env_backup="${ENV_FILE}.backup-runtime-$(date +%Y%m%d-%H%M%S)"
cp "${ENV_FILE}" "${env_backup}"
current_image="${FD_EDU_RUNTIME_IMAGE}"
next_image="${AVAILABLE_FD_EDU_RUNTIME_IMAGE}"

set_env_value "${ENV_FILE}" FD_EDU_RUNTIME_IMAGE "${next_image}"
set_env_value "${ENV_FILE}" APP_VERSION "${next_image##*:}"
unset_env_value "${ENV_FILE}" AVAILABLE_FD_EDU_RUNTIME_IMAGE
set_env_value "${ENV_FILE}" LAST_RUNTIME_IMAGE_APPLIED_AT "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
export FD_EDU_RUNTIME_IMAGE="${next_image}"
export APP_VERSION="${next_image##*:}"
unset AVAILABLE_FD_EDU_RUNTIME_IMAGE

compose=(docker compose --project-directory "${ROOT_DIR}" --env-file "${ENV_FILE}" -f "${ROOT_DIR}/docker-compose.yml")
if ! "${compose[@]}" pull api worker || ! "${compose[@]}" run --rm --no-deps api npm run db:migrate; then
  cp "${env_backup}" "${ENV_FILE}"
  export FD_EDU_RUNTIME_IMAGE="${current_image}"
  export APP_VERSION="$(get_env_value "${ENV_FILE}" APP_VERSION)"
  echo "Image update failed before services were recreated; restored ${current_image}."
  exit 1
fi

"${compose[@]}" up -d --no-deps --force-recreate api worker

healthy=false
for attempt in $(seq 1 30); do
  if "${compose[@]}" exec -T api node -e "fetch('http://127.0.0.1:8090/ready',{headers:{host:process.env.FD_BOUND_HOST}}).then(r=>process.exit(r.ok?0:1)).catch(()=>process.exit(1))"; then
    healthy=true
    break
  fi
  sleep 3
done

if [[ "${healthy}" != "true" ]]; then
  cp "${env_backup}" "${ENV_FILE}"
  export FD_EDU_RUNTIME_IMAGE="${current_image}"
  export APP_VERSION="$(get_env_value "${ENV_FILE}" APP_VERSION)"
  "${compose[@]}" up -d --no-deps --force-recreate api worker
  echo "New image failed readiness checks; restored ${current_image}. Database backup is available for manual recovery if the migration was not backward-compatible."
  exit 1
fi

bash "${ROOT_DIR}/scripts/report-deployment-status.sh" || true
