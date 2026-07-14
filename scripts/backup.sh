#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENV_FILE="${ENV_FILE:-${ROOT_DIR}/.env}"
BACKUP_DIR="${BACKUP_DIR:-${ROOT_DIR}/backups}"
source "${ROOT_DIR}/scripts/common.sh"
load_env_file "${ENV_FILE}"
mkdir -p "${BACKUP_DIR}"
chmod 700 "${BACKUP_DIR}"
backup_file="${BACKUP_DIR}/fd-edu-$(date +%Y%m%d-%H%M%S).sql.gz"
temp_file="${backup_file}.tmp"
trap 'rm -f "${temp_file}"' EXIT

docker compose --project-directory "${ROOT_DIR}" --env-file "${ENV_FILE}" -f "${ROOT_DIR}/docker-compose.yml" exec -T postgres \
  pg_dump --clean --if-exists --no-owner --no-privileges -U "${POSTGRES_USER}" "${POSTGRES_DB}" | gzip -9 > "${temp_file}"
mv "${temp_file}" "${backup_file}"
chmod 600 "${backup_file}"
find "${BACKUP_DIR}" -type f -name 'fd-edu-*.sql.gz' -mtime +"${BACKUP_RETENTION_DAYS:-14}" -delete
echo "Backup created: ${backup_file}"
