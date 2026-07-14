#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

write_unit() {
  local path="$1"
  local content="$2"
  if [[ "${EUID}" -eq 0 ]]; then printf '%s\n' "${content}" > "${path}"; else printf '%s\n' "${content}" | sudo tee "${path}" >/dev/null; fi
}

run_root_cmd() { if [[ "${EUID}" -eq 0 ]]; then "$@"; else sudo "$@"; fi; }
command -v systemctl >/dev/null 2>&1 || exit 0

write_unit /etc/systemd/system/fd-edu-deployment-actions.service "[Unit]
Description=FD Edu deployment action runner
After=network-online.target
[Service]
Type=oneshot
WorkingDirectory=${ROOT_DIR}
ExecStart=${ROOT_DIR}/scripts/run-pending-deployment-action.sh"

write_unit /etc/systemd/system/fd-edu-deployment-actions.timer "[Unit]
Description=Poll FD Stack deployment actions
[Timer]
OnBootSec=2min
OnUnitActiveSec=1min
Persistent=true
[Install]
WantedBy=timers.target"

write_unit /etc/systemd/system/fd-edu-deployment-status.service "[Unit]
Description=Report FD Edu deployment status
After=network-online.target
[Service]
Type=oneshot
WorkingDirectory=${ROOT_DIR}
ExecStart=${ROOT_DIR}/scripts/report-deployment-status.sh"

write_unit /etc/systemd/system/fd-edu-deployment-status.timer "[Unit]
Description=Report FD Edu deployment status periodically
[Timer]
OnBootSec=3min
OnUnitActiveSec=5min
Persistent=true
[Install]
WantedBy=timers.target"

write_unit /etc/systemd/system/fd-edu-backup.service "[Unit]
Description=Back up FD Edu PostgreSQL
After=docker.service
[Service]
Type=oneshot
WorkingDirectory=${ROOT_DIR}
ExecStart=${ROOT_DIR}/scripts/backup.sh"

write_unit /etc/systemd/system/fd-edu-backup.timer "[Unit]
Description=Back up FD Edu PostgreSQL daily
[Timer]
OnCalendar=*-*-* 03:30:00
RandomizedDelaySec=30min
Persistent=true
[Install]
WantedBy=timers.target"

run_root_cmd systemctl daemon-reload
run_root_cmd systemctl enable --now fd-edu-deployment-actions.timer fd-edu-deployment-status.timer fd-edu-backup.timer
