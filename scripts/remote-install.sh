#!/usr/bin/env bash
set -euo pipefail

INSTALL_DIR="${INSTALL_DIR:-/opt/fd-edu-system}"
REPO_URL="${REPO_URL:-https://github.com/FutureDecade/fd-edu-system-delivery.git}"
REPO_BRANCH="${REPO_BRANCH:-main}"

run_root_cmd() {
  if [[ "${EUID}" -eq 0 ]]; then "$@"; else sudo "$@"; fi
}

run_root_cmd apt-get update
run_root_cmd apt-get install -y ca-certificates curl git jq

if [[ -d "${INSTALL_DIR}/.git" ]]; then
  run_root_cmd git -C "${INSTALL_DIR}" pull --ff-only origin "${REPO_BRANCH}"
elif [[ -e "${INSTALL_DIR}" ]]; then
  echo "Install path exists and is not a Git repository: ${INSTALL_DIR}"
  exit 1
else
  run_root_cmd mkdir -p "$(dirname "${INSTALL_DIR}")"
  run_root_cmd git clone --branch "${REPO_BRANCH}" --depth 1 "${REPO_URL}" "${INSTALL_DIR}"
fi

run_root_cmd bash "${INSTALL_DIR}/scripts/prepare-server.sh"
run_root_cmd env \
  FD_STACK_DEPLOY_TOKEN="${FD_STACK_DEPLOY_TOKEN:-}" \
  FD_STACK_EXCHANGE_URL="${FD_STACK_EXCHANGE_URL:-}" \
  FD_STACK_PUBLIC_BASE_URL="${FD_STACK_PUBLIC_BASE_URL:-}" \
  bash "${INSTALL_DIR}/scripts/quick-install.sh"

