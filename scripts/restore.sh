#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENV_FILE="${ENV_FILE:-${ROOT_DIR}/.env}"
BACKUP_FILE="${1:-}"
source "${ROOT_DIR}/scripts/common.sh"
require_value BACKUP_FILE
[[ -f "${BACKUP_FILE}" ]] || { echo "Backup not found: ${BACKUP_FILE}"; exit 1; }
[[ "${CONFIRM_RESTORE:-}" == "yes" ]] || { echo "Set CONFIRM_RESTORE=yes to restore."; exit 1; }
load_env_file "${ENV_FILE}"
compose=(docker compose --project-directory "${ROOT_DIR}" --env-file "${ENV_FILE}" -f "${ROOT_DIR}/docker-compose.yml")
"${compose[@]}" stop api worker
gzip -dc "${BACKUP_FILE}" | "${compose[@]}" exec -T postgres psql -v ON_ERROR_STOP=1 -U "${POSTGRES_USER}" "${POSTGRES_DB}"
"${compose[@]}" up -d api worker caddy
echo "Restore completed: ${BACKUP_FILE}"

