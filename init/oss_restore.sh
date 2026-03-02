#!/usr/bin/env bash
#
# Usage:
#   bash oss_restore.sh [--dry-run] [path1] [path2] ...
#
# Without path arguments, lists OSS top-level directories and
# prompts for which paths to restore. Press Enter for full restore.
#
# Examples:
#   bash oss_restore.sh docs ssh          # restore docs/ and ssh/ only
#   bash oss_restore.sh --dry-run docs    # dry-run
#   bash oss_restore.sh                   # interactive selection
#
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/oss_common.sh"

LOG_FILE="$HOME/oss_restore.log"

# Lock file to prevent concurrent runs
LOCK_FILE="/tmp/oss_restore.lock"
if [ -f "$LOCK_FILE" ]; then
    echo "ERROR: Another restore process is running (lockfile: $LOCK_FILE)" >&2
    exit 1
fi
trap 'rm -f "$LOCK_FILE"' EXIT
touch "$LOCK_FILE"

# Parse arguments: extract --dry-run, rest are paths
DRY_RUN=""
PATHS=()
for arg in "$@"; do
    case "$arg" in
        --dry-run) DRY_RUN="--dry-run" ;;
        *) PATHS+=("${arg%/}") ;;   # strip trailing slash
    esac
done

if [ -n "$DRY_RUN" ]; then
    echo "==== DRY RUN mode, no changes will be made ===="
fi

# Configure rclone
setup_rclone_remotes

# Without path arguments, list remote top-level dirs and prompt
if [ "${#PATHS[@]}" -eq 0 ]; then
    echo "==== OSS remote top-level directories ===="
    rclone lsd "$CRYPT_REMOTE:backup" 2>/dev/null | awk '{print "  " $NF}' || true
    echo ""
    echo "Enter paths to restore (space-separated, press Enter for full restore):"
    read -r user_input
    if [ -n "$user_input" ]; then
        read -ra PATHS <<< "$user_input"
        # Strip trailing slashes
        PATHS=("${PATHS[@]%/}")
    fi
fi

mkdir -p "$OSS_LOCAL_DIR"

# Restore a single path
restore_one() {
    local rel_path="$1"
    local remote="$CRYPT_REMOTE:backup/$rel_path"
    local local_path="$OSS_LOCAL_DIR/$rel_path"

    # Determine if remote path is a directory or file: try lsd, output means directory
    if rclone lsd "$remote" 2>/dev/null | grep -q .; then
        # Directory: use copy
        mkdir -p "$local_path"
        echo "==== Restoring directory $rel_path -> $local_path ===="
        rclone copy "$remote" "$local_path" \
          $DRY_RUN \
          --progress \
          --transfers "$RCLONE_TRANSFERS" \
          --checkers "$RCLONE_CHECKERS" \
          --log-file="$LOG_FILE" \
          --log-level INFO

        if [ -z "$DRY_RUN" ]; then
            echo "==== Verifying $rel_path ===="
            rclone check "$remote" "$local_path" \
              --checkers "$RCLONE_CHECKERS" \
              --log-file="$LOG_FILE" \
              --log-level INFO
            echo "==== Verification passed ===="
        fi
    else
        # File: use copyto
        mkdir -p "$(dirname "$local_path")"
        echo "==== Restoring file $rel_path -> $local_path ===="
        rclone copyto "$remote" "$local_path" \
          $DRY_RUN \
          --progress \
          --log-file="$LOG_FILE" \
          --log-level INFO

        if [ -z "$DRY_RUN" ]; then
            echo "==== Verifying $rel_path ===="
            rclone check "$(dirname "$remote")" "$(dirname "$local_path")" \
              --include "$(basename "$rel_path")" \
              --checkers "$RCLONE_CHECKERS" \
              --log-file="$LOG_FILE" \
              --log-level INFO
            echo "==== Verification passed ===="
        fi
    fi
}

if [ "${#PATHS[@]}" -eq 0 ]; then
    # Full restore
    echo "==== Full restore to $OSS_LOCAL_DIR ===="
    rclone copy "$CRYPT_REMOTE:backup" "$OSS_LOCAL_DIR" \
      $DRY_RUN \
      --progress \
      --transfers "$RCLONE_TRANSFERS" \
      --checkers "$RCLONE_CHECKERS" \
      --log-file="$LOG_FILE" \
      --log-level INFO

    if [ -z "$DRY_RUN" ]; then
        echo "==== Verifying file integrity ===="
        rclone check "$CRYPT_REMOTE:backup" "$OSS_LOCAL_DIR" \
          --checkers "$RCLONE_CHECKERS" \
          --log-file="$LOG_FILE" \
          --log-level INFO
        echo "==== Verification passed ===="
    fi
else
    for path in "${PATHS[@]}"; do
        restore_one "$path"
    done
fi

echo "==== Restore complete ===="
echo "Log file: $LOG_FILE"
