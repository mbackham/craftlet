#!/usr/bin/env bash
# =============================================================================
# PostgreSQL Automated Backup Script
# =============================================================================
# Usage: bash scripts/pg_backup.sh
# Cron:  0 2 * * * /home/rails/projects/craftlet/scripts/pg_backup.sh >> /var/log/pg_backup.log 2>&1
#
# Retention Policy:
#   - Daily backups: kept for 7 days
#   - Weekly backups (Sunday): kept for 4 weeks
# =============================================================================

set -euo pipefail

# --- Configuration -----------------------------------------------------------
APP_NAME="craftlet"
BACKUP_DIR="${BACKUP_DIR:-/var/backups/postgresql}"
DB_NAME="${DB_NAME:-craftlet_production}"
DB_USER="${DB_USER:-rails}"
DB_HOST="${DB_HOST:-localhost}"
DB_PORT="${DB_PORT:-5432}"

DAILY_RETAIN_DAYS=7
WEEKLY_RETAIN_DAYS=28

TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
DAY_OF_WEEK=$(date +"%u")  # 1=Monday, 7=Sunday

# --- Prepare directories ----------------------------------------------------
DAILY_DIR="${BACKUP_DIR}/daily"
WEEKLY_DIR="${BACKUP_DIR}/weekly"
mkdir -p "$DAILY_DIR" "$WEEKLY_DIR"

# --- Perform backup ----------------------------------------------------------
BACKUP_FILE="${DAILY_DIR}/${APP_NAME}_${TIMESTAMP}.sql.gz"

echo "[$(date)] Starting backup: ${DB_NAME} → ${BACKUP_FILE}"

pg_dump \
  --host="$DB_HOST" \
  --port="$DB_PORT" \
  --username="$DB_USER" \
  --format=custom \
  --compress=9 \
  --verbose \
  "$DB_NAME" > "$BACKUP_FILE"

FILESIZE=$(du -h "$BACKUP_FILE" | cut -f1)
echo "[$(date)] Backup completed: ${BACKUP_FILE} (${FILESIZE})"

# --- Weekly rotation (copy Sunday's backup) -----------------------------------
if [ "$DAY_OF_WEEK" = "7" ]; then
  WEEKLY_FILE="${WEEKLY_DIR}/${APP_NAME}_weekly_${TIMESTAMP}.sql.gz"
  cp "$BACKUP_FILE" "$WEEKLY_FILE"
  echo "[$(date)] Weekly backup copied: ${WEEKLY_FILE}"
fi

# --- Cleanup old backups ------------------------------------------------------
echo "[$(date)] Cleaning daily backups older than ${DAILY_RETAIN_DAYS} days..."
find "$DAILY_DIR" -name "*.sql.gz" -mtime +"$DAILY_RETAIN_DAYS" -delete -print

echo "[$(date)] Cleaning weekly backups older than ${WEEKLY_RETAIN_DAYS} days..."
find "$WEEKLY_DIR" -name "*.sql.gz" -mtime +"$WEEKLY_RETAIN_DAYS" -delete -print

echo "[$(date)] Backup process finished."
