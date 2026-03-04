#!/usr/bin/env bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../init/oss_common.sh"

LOG_FILE="$HOME/oss_backup.log"

# Lock file to prevent concurrent runs
LOCK_FILE="/tmp/oss_backup.lock"
if [ -f "$LOCK_FILE" ]; then
    echo "ERROR: Another backup process is running (lockfile: $LOCK_FILE)" >&2
    exit 1
fi
trap 'rm -f "$LOCK_FILE"' EXIT
touch "$LOCK_FILE"

# Parse arguments
DRY_RUN=""
for arg in "$@"; do
    case "$arg" in
        --dry-run) DRY_RUN="--dry-run" ;;
    esac
done

if [ -n "$DRY_RUN" ]; then
    echo "==== DRY RUN mode, no changes will be made ===="
fi

# Validate source directory
if [ ! -d "$OSS_LOCAL_DIR" ]; then
    echo "ERROR: OSS_LOCAL_DIR '$OSS_LOCAL_DIR' does not exist" >&2
    exit 1
fi

FILE_COUNT=$(find "$OSS_LOCAL_DIR" -maxdepth 1 -mindepth 1 | head -5 | wc -l)
if [ "$FILE_COUNT" -eq 0 ]; then
    echo "ERROR: OSS_LOCAL_DIR '$OSS_LOCAL_DIR' is empty, refusing to sync" >&2
    exit 1
fi

# Configure rclone
setup_rclone_remotes

# Pre-check: count files to transfer
echo "==== Pre-check changes ===="
DRY_OUTPUT=$(rclone copy "$OSS_LOCAL_DIR" "$CRYPT_REMOTE:backup" \
    --dry-run \
    -v \
    2>&1 || true)

TRANSFERS=$(echo "$DRY_OUTPUT" | grep -c "Skipped copy" || true)
echo "$TRANSFERS file(s) to transfer"

if [ "$TRANSFERS" -gt 0 ]; then
    echo "$DRY_OUTPUT" | grep "Skipped copy"
fi

# Run backup (copy mode: only adds, never deletes remote files)
echo "==== Starting encrypted backup ===="

rclone copy "$OSS_LOCAL_DIR" "$CRYPT_REMOTE:backup" \
  $DRY_RUN \
  --progress \
  --transfers "$RCLONE_TRANSFERS" \
  --checkers "$RCLONE_CHECKERS" \
  --log-file="$LOG_FILE" \
  --log-level INFO

echo "==== Backup complete ===="
echo "Log file: $LOG_FILE"
