#!/usr/bin/env bash
set -euo pipefail

run_root_cmd() {
  if [[ "${EUID}" -eq 0 ]]; then "$@"; else sudo "$@"; fi
}

if [[ ! -f /etc/os-release ]]; then
  echo "Unsupported system: /etc/os-release is missing."
  exit 1
fi

source /etc/os-release
if [[ "${ID:-}" != "debian" && "${ID:-}" != "ubuntu" ]]; then
  echo "Only Debian and Ubuntu are currently supported."
  exit 1
fi

run_root_cmd apt-get update
run_root_cmd apt-get install -y ca-certificates curl git jq openssl

if ! command -v docker >/dev/null 2>&1 || ! docker compose version >/dev/null 2>&1; then
  run_root_cmd install -m 0755 -d /etc/apt/keyrings
  curl -fsSL "https://download.docker.com/linux/${ID}/gpg" | run_root_cmd tee /etc/apt/keyrings/docker.asc >/dev/null
  run_root_cmd chmod a+r /etc/apt/keyrings/docker.asc
  codename="${VERSION_CODENAME:-${UBUNTU_CODENAME:-}}"
  arch="$(dpkg --print-architecture)"
  printf 'deb [arch=%s signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/%s %s stable\n' "${arch}" "${ID}" "${codename}" | run_root_cmd tee /etc/apt/sources.list.d/docker.list >/dev/null
  run_root_cmd apt-get update
  run_root_cmd apt-get install -y containerd.io docker-buildx-plugin docker-ce docker-ce-cli docker-compose-plugin
fi

if command -v systemctl >/dev/null 2>&1; then
  run_root_cmd systemctl enable --now docker
fi

docker version >/dev/null
docker compose version >/dev/null

