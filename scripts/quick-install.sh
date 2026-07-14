#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENV_FILE="${ENV_FILE:-${ROOT_DIR}/.env}"
source "${ROOT_DIR}/scripts/common.sh"
source "${ROOT_DIR}/scripts/stack-bootstrap.sh"

umask 077
cleanup_bootstrap_secrets() {
  unset ACR_USERNAME ACR_PASSWORD INITIAL_ADMIN_PASSWORD
  unset FD_STACK_BOOTSTRAP_JSON FD_STACK_DEPLOY_TOKEN FD_STACK_EXCHANGE_URL FD_STACK_PUBLIC_BASE_URL
}
trap cleanup_bootstrap_secrets EXIT

load_stack_bootstrap

for key in EDU_DOMAIN FD_EDU_RUNTIME_IMAGE ACR_USERNAME ACR_PASSWORD INITIAL_ORGANIZATION_NAME INITIAL_ADMIN_EMAIL INITIAL_ADMIN_DISPLAY_NAME INITIAL_ADMIN_PASSWORD; do
  require_value "${key}"
done

POSTGRES_DB="${POSTGRES_DB:-$(get_env_value "${ENV_FILE}" POSTGRES_DB)}"
POSTGRES_DB="${POSTGRES_DB:-fd_edu}"
POSTGRES_USER="${POSTGRES_USER:-$(get_env_value "${ENV_FILE}" POSTGRES_USER)}"
POSTGRES_USER="${POSTGRES_USER:-fd_edu}"
POSTGRES_PASSWORD="${POSTGRES_PASSWORD:-$(get_env_value "${ENV_FILE}" POSTGRES_PASSWORD)}"
POSTGRES_PASSWORD="${POSTGRES_PASSWORD:-$(generate_secret 24)}"
JWT_SECRET="${JWT_SECRET:-$(get_env_value "${ENV_FILE}" JWT_SECRET)}"
JWT_SECRET="${JWT_SECRET:-$(generate_secret 32)}"
SETTINGS_ENCRYPTION_KEY="${SETTINGS_ENCRYPTION_KEY:-$(get_env_value "${ENV_FILE}" SETTINGS_ENCRYPTION_KEY)}"
SETTINGS_ENCRYPTION_KEY="${SETTINGS_ENCRYPTION_KEY:-$(generate_secret 32)}"
PARENT_TOKEN_SECRET="${PARENT_TOKEN_SECRET:-$(get_env_value "${ENV_FILE}" PARENT_TOKEN_SECRET)}"
PARENT_TOKEN_SECRET="${PARENT_TOKEN_SECRET:-$(generate_secret 32)}"
FD_BOUND_HOST="${FD_BOUND_HOST:-${EDU_DOMAIN}}"
FD_DOMAIN_BINDING_SOURCE="${FD_DOMAIN_BINDING_SOURCE:-primaryDomain}"

touch "${ENV_FILE}"
set_env_value "${ENV_FILE}" NODE_ENV production
set_env_value "${ENV_FILE}" APP_NAME fd-edu-system
set_env_value "${ENV_FILE}" APP_VERSION "${FD_EDU_RUNTIME_IMAGE##*:}"
set_env_value "${ENV_FILE}" API_HOST 0.0.0.0
set_env_value "${ENV_FILE}" API_PORT 8090
set_env_value "${ENV_FILE}" LOG_LEVEL info
set_env_value "${ENV_FILE}" EDU_DOMAIN "${EDU_DOMAIN}"
set_env_value "${ENV_FILE}" PUBLIC_BASE_URL "https://${EDU_DOMAIN}"
set_env_value "${ENV_FILE}" PUBLIC_WEB_BASE_URL "https://${EDU_DOMAIN}"
set_env_value "${ENV_FILE}" PUBLIC_WEB_ORIGIN "https://${EDU_DOMAIN}"
set_env_value "${ENV_FILE}" APP_BASE_URL "https://${EDU_DOMAIN}"
set_env_value "${ENV_FILE}" CORS_ORIGIN "https://${EDU_DOMAIN}"
set_env_value "${ENV_FILE}" POSTGRES_DB "${POSTGRES_DB}"
set_env_value "${ENV_FILE}" POSTGRES_USER "${POSTGRES_USER}"
set_env_value "${ENV_FILE}" POSTGRES_PASSWORD "${POSTGRES_PASSWORD}"
set_env_value "${ENV_FILE}" DATABASE_URL "postgres://${POSTGRES_USER}:${POSTGRES_PASSWORD}@postgres:5432/${POSTGRES_DB}"
set_env_value "${ENV_FILE}" REDIS_URL redis://redis:6379
set_env_value "${ENV_FILE}" JWT_SECRET "${JWT_SECRET}"
set_env_value "${ENV_FILE}" SETTINGS_ENCRYPTION_KEY "${SETTINGS_ENCRYPTION_KEY}"
set_env_value "${ENV_FILE}" PARENT_TOKEN_SECRET "${PARENT_TOKEN_SECRET}"
set_env_value "${ENV_FILE}" FD_EDU_RUNTIME_IMAGE "${FD_EDU_RUNTIME_IMAGE}"
set_env_value "${ENV_FILE}" FD_DOMAIN_BINDING_SOURCE "${FD_DOMAIN_BINDING_SOURCE}"
set_env_value "${ENV_FILE}" FD_BOUND_HOST "${FD_BOUND_HOST}"
set_env_value "${ENV_FILE}" FD_RUNTIME_IMAGE_UPDATE_POLICY "${FD_RUNTIME_IMAGE_UPDATE_POLICY:-manual}"

for key in FD_STACK_DEPLOYMENT_ID FD_STACK_STATUS_REPORT_URL FD_STACK_STATUS_REPORT_TOKEN FD_STACK_ACTION_PULL_URL FD_STACK_ACTION_COMPLETE_URL; do
  set_env_value "${ENV_FILE}" "${key}" "${!key:-}"
done
chmod 600 "${ENV_FILE}"

registry="$(detect_registry_host "${FD_EDU_RUNTIME_IMAGE}")"
printf '%s' "${ACR_PASSWORD}" | docker login "${registry}" --username "${ACR_USERNAME}" --password-stdin >/dev/null

compose=(docker compose --project-directory "${ROOT_DIR}" --env-file "${ENV_FILE}" -f "${ROOT_DIR}/docker-compose.yml")
"${compose[@]}" config >/dev/null
"${compose[@]}" pull api worker
"${compose[@]}" up -d postgres
"${compose[@]}" run --rm --no-deps api npm run db:migrate
"${compose[@]}" run --rm --no-deps \
  -e INITIAL_ADMIN_EMAIL -e INITIAL_ADMIN_PASSWORD -e INITIAL_ADMIN_DISPLAY_NAME \
  -e INITIAL_ORGANIZATION_NAME -e INITIAL_ORGANIZATION_BRAND_NAME \
  -e INITIAL_ORGANIZATION_PHONE -e INITIAL_ORGANIZATION_ADDRESS \
  api npm run db:bootstrap
"${compose[@]}" up -d --remove-orphans api worker caddy

for attempt in $(seq 1 40); do
  if "${compose[@]}" exec -T api node -e "fetch('http://127.0.0.1:8090/ready',{headers:{host:process.env.FD_BOUND_HOST}}).then(r=>process.exit(r.ok?0:1)).catch(()=>process.exit(1))"; then
    break
  fi
  if [[ "${attempt}" -eq 40 ]]; then
    "${compose[@]}" logs --tail 100 api postgres
    exit 1
  fi
  sleep 3
done

bash "${ROOT_DIR}/scripts/install-deployment-timers.sh"
bash "${ROOT_DIR}/scripts/report-deployment-status.sh" || true

echo "FD Edu deployment completed: https://${EDU_DOMAIN}"
echo "Admin login: https://${EDU_DOMAIN}/admin/"
echo "Initial administrator: ${INITIAL_ADMIN_EMAIL}"
