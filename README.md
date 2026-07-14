# FD Edu System Delivery

This is the thin delivery repository for the FD Edu private deployment product.
It contains deployment configuration and operations scripts only. The application
is delivered as a private ACR image; application source code is not included.

The supported installation path is the one-time command issued by FD Stack. It
targets a clean Debian or Ubuntu server with root or sudo access and requires the
customer's domain to resolve to that server.

## Operations

```bash
bash scripts/backup.sh
bash scripts/report-deployment-status.sh
bash scripts/run-pending-deployment-action.sh
```

Restore is intentionally explicit:

```bash
CONFIRM_RESTORE=yes bash scripts/restore.sh backups/fd-edu-YYYYmmdd-HHMMSS.sql.gz
```
