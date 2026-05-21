#!/bin/bash

# manage_db_backups.sh
#
# This script manages database backup retention for CloudPanel-managed databases.
# It operates in two stages for each database:
#
# STAGE 1 — Local Archive (cold storage)
#   Moves older backups into a "local" subfolder under each DB directory:
#     BASE_DIR/USER/backups/databases/DB_NAME/local/YYYY-MM-DD/
#   Within each day in local/, only the N_KEEP_LOCAL_BACKUPS_PER_DAY most recent
#   dumps are kept. Days older than LOCAL_BACKUP_MAX_AGE are deleted entirely.
#   The "local" folder should be added to CloudPanel's rclone Excludes list so it
#   is never uploaded to remote storage.
#
# STAGE 2 — Remote-ready (hot) backups
#   After archiving, only the single most recent .sql.gz across ALL date folders
#   (outside of local/) is kept. Everything else is deleted and empty date dirs
#   are removed. This is what rclone will pick up and upload.
#
# Directory structure after this script runs:
#
#   /home/USER/backups/databases/
#   └── DB_NAME/
#       ├── 2026-05-20/
#       │   └── db_1779280801.sql.gz   ← single latest dump (uploaded to remote)
#       └── local/
#           ├── 2026-05-19/
#           │   └── db_1779194401.sql.gz
#           ├── 2026-05-18/
#           │   └── db_1779108001.sql.gz
#           └── ... (up to LOCAL_BACKUP_MAX_AGE days)
#
# Usage:
#   Place in /usr/local/bin/manage_db_backups.sh
#   chmod +x /usr/local/bin/manage_db_backups.sh
#
# Cron (run 5 minutes before remote backup so hot area is clean before rclone):
#   */30 * * * * /usr/local/bin/manage_db_backups.sh >> /var/log/manage_db_backups.log 2>&1
#
# CloudPanel rclone Excludes — add this line:
#   /home/*/backups/databases/*/local/**
#
# Requirements:
#   - bash 4+, find, sort, awk, mv, rm (all standard on Ubuntu)
#   - Script must run as root (needs write access under /home/*)

set -euo pipefail

# ---------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------
BASE_DIR="/home"

# How many dumps to keep per day in the local archive folder
N_KEEP_LOCAL_BACKUPS_PER_DAY=1

# How many days of dumps to retain in the local archive folder
LOCAL_BACKUP_MAX_AGE=7
# ---------------------------------------------------------------------------

log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*"; }

# Returns epoch mtime for a file (portable across Linux)
file_mtime() { stat -c '%Y' "$1"; }

# Returns YYYY-MM-DD for an epoch timestamp
epoch_to_date() { date -d "@$1" '+%Y-%m-%d'; }

# ---------------------------------------------------------------------------
# Process one database directory
# e.g. /home/xenfi-alpha-db/backups/databases/main
# ---------------------------------------------------------------------------
process_db() {
    local DB_DIR="$1"
    local LOCAL_DIR="$DB_DIR/local"
    local db_name
    db_name=$(basename "$DB_DIR")

    log "  DB: $db_name"

    # Collect every .sql.gz that is NOT already inside local/
    mapfile -t all_dumps < <(
        find "$DB_DIR" -maxdepth 2 -name "*.sql.gz" \
            ! -path "$LOCAL_DIR/*" \
            -printf '%T@ %p\n' | sort -rn | awk '{print $2}'
    )

    if [ ${#all_dumps[@]} -eq 0 ]; then
        log "    No hot dumps found, skipping"
        return
    fi

    local latest="${all_dumps[0]}"
    log "    Keeping hot (remote-ready): $(basename "$latest")"

    # ------------------------------------------------------------------
    # STAGE 1 — Move non-latest dumps into local archive
    # ------------------------------------------------------------------
    for dump in "${all_dumps[@]:1}"; do
        local dump_date
        dump_date=$(epoch_to_date "$(file_mtime "$dump")")
        local dest_dir="$LOCAL_DIR/$dump_date"

        mkdir -p "$dest_dir"
        mv "$dump" "$dest_dir/"
        log "    Archived to local/$dump_date/$(basename "$dump")"
    done

    # ------------------------------------------------------------------
    # STAGE 1b — Enforce N_KEEP_LOCAL_BACKUPS_PER_DAY within each day
    #            in the local archive
    # ------------------------------------------------------------------
    if [ -d "$LOCAL_DIR" ]; then
        for day_dir in "$LOCAL_DIR"/*/; do
            [ -d "$day_dir" ] || continue

            # List dumps newest-first; delete everything beyond the keep limit
            mapfile -t day_dumps < <(
                find "$day_dir" -maxdepth 1 -name "*.sql.gz" \
                    -printf '%T@ %p\n' | sort -rn | awk '{print $2}'
            )

            local count=0
            for dump in "${day_dumps[@]}"; do
                count=$((count + 1))
                if [ "$count" -gt "$N_KEEP_LOCAL_BACKUPS_PER_DAY" ]; then
                    rm -f "$dump"
                    log "    Pruned excess local dump: $(basename "$dump") ($day_dir)"
                fi
            done
        done

        # ------------------------------------------------------------------
        # STAGE 1c — Delete local day-folders older than LOCAL_BACKUP_MAX_AGE
        # ------------------------------------------------------------------
        local cutoff_epoch
        cutoff_epoch=$(date -d "-${LOCAL_BACKUP_MAX_AGE} days" '+%s')

        for day_dir in "$LOCAL_DIR"/*/; do
            [ -d "$day_dir" ] || continue
            local dir_date
            dir_date=$(basename "$day_dir")

            # Validate it looks like a date folder before doing anything
            if [[ ! "$dir_date" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]]; then
                continue
            fi

            local dir_epoch
            dir_epoch=$(date -d "$dir_date" '+%s' 2>/dev/null || echo 0)

            if [ "$dir_epoch" -lt "$cutoff_epoch" ]; then
                rm -rf "$day_dir"
                log "    Expired local archive: $dir_date (older than ${LOCAL_BACKUP_MAX_AGE}d)"
            fi
        done
    fi

    # ------------------------------------------------------------------
    # STAGE 2 — Clean up hot area: remove any remaining non-latest dumps
    #           and empty date dirs (safety net; should already be clean)
    # ------------------------------------------------------------------
    find "$DB_DIR" -maxdepth 2 -name "*.sql.gz" \
        ! -path "$LOCAL_DIR/*" \
        ! -path "$latest" \
        -delete

    # Remove empty date dirs (but never remove local/ itself)
    find "$DB_DIR" -mindepth 1 -maxdepth 1 -type d \
        ! -name "local" \
        -empty -delete
}

# ---------------------------------------------------------------------------
# Main loop
# ---------------------------------------------------------------------------
log "=== Backup cleanup started ==="

for USER_DIR in "$BASE_DIR"/*/; do
    [ -d "$USER_DIR/backups/databases" ] || continue
    log "User: $(basename "$USER_DIR")"

    for DB_DIR in "$USER_DIR/backups/databases"/*/; do
        [ -d "$DB_DIR" ] || continue

        # Never process the local archive as if it were a DB folder
        [ "$(basename "$DB_DIR")" = "local" ] && continue

        process_db "$DB_DIR"
    done
done

log "=== Backup cleanup complete ==="