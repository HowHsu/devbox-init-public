#!/usr/bin/env bash
#
# Interactive OSS remote browser — browse directories and download files to ~/oss/
#
# Usage:
#   bash oss_download.sh
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../init/oss_common.sh"

setup_rclone_remotes

REMOTE_ROOT="$CRYPT_REMOTE:backup"
CUR_PATH=""

# List directories and files at the current path
list_entries() {
    local remote="$REMOTE_ROOT"
    [[ -n "$CUR_PATH" ]] && remote="$remote/$CUR_PATH"

    DIRS=()
    FILES=()

    while IFS= read -r line; do
        [[ -n "$line" ]] && DIRS+=("$line")
    done < <(rclone lsd "$remote" 2>/dev/null | awk '{print $NF}' || true)

    while IFS= read -r line; do
        [[ -n "$line" ]] && FILES+=("$line")
    done < <(rclone lsf "$remote" --files-only 2>/dev/null || true)
}

# Display current path contents
show_menu() {
    echo ""
    if [[ -z "$CUR_PATH" ]]; then
        echo "==== OSS:/ ===="
    else
        echo "==== OSS:/$CUR_PATH ===="
    fi

    local idx=1
    for d in "${DIRS[@]}"; do
        printf "  %3d) %s/\n" "$idx" "$d"
        ((idx++))
    done
    for f in "${FILES[@]}"; do
        printf "  %3d) %s\n" "$idx" "$f"
        ((idx++))
    done

    if [[ ${#DIRS[@]} -eq 0 && ${#FILES[@]} -eq 0 ]]; then
        echo "  (empty directory)"
    fi

    echo ""
    echo "Actions: enter number to browse/download, .. to go up, q to quit"
}

download_item() {
    local rel_path="$1"
    local remote="$REMOTE_ROOT/$rel_path"
    local local_path="$OSS_LOCAL_DIR/$rel_path"

    # Determine directory or file:
    # List parent and check if entry has trailing / (rclone marks directories with /)
    local parent_dir
    parent_dir=$(dirname "$rel_path")
    local parent_remote="$REMOTE_ROOT"
    [[ "$parent_dir" != "." ]] && parent_remote="$parent_remote/$parent_dir"
    local base_name
    base_name=$(basename "$rel_path")
    if rclone lsf "$parent_remote" 2>/dev/null | grep -qxF "${base_name}/"; then
        mkdir -p "$local_path"
        echo "==== Downloading directory $rel_path -> $local_path ===="
        rclone copy "$remote" "$local_path" \
            --progress \
            --transfers "$RCLONE_TRANSFERS" \
            --checkers "$RCLONE_CHECKERS"
    else
        mkdir -p "$(dirname "$local_path")"
        echo "==== Downloading file $rel_path -> $local_path ===="
        rclone copyto "$remote" "$local_path" \
            --progress
    fi
    echo "==== Download complete ===="
}

while true; do
    list_entries
    show_menu
    read -rp "> " choice

    case "$choice" in
        q|Q|exit)
            echo "Exiting"
            break
            ;;
        ..)
            if [[ -n "$CUR_PATH" ]]; then
                CUR_PATH="${CUR_PATH%/*}"
            fi
            ;;
        ''|*[!0-9]*)
            echo "Invalid input"
            ;;
        *)
            total=$(( ${#DIRS[@]} + ${#FILES[@]} ))
            if [[ "$choice" -lt 1 || "$choice" -gt "$total" ]]; then
                echo "Number out of range"
                continue
            fi

            if [[ "$choice" -le ${#DIRS[@]} ]]; then
                # Enter subdirectory
                dir_name="${DIRS[$((choice - 1))]}"
                if [[ -z "$CUR_PATH" ]]; then
                    CUR_PATH="$dir_name"
                else
                    CUR_PATH="$CUR_PATH/$dir_name"
                fi
            else
                # Selected a file, confirm download
                file_idx=$((choice - ${#DIRS[@]} - 1))
                file_name="${FILES[$file_idx]}"
                if [[ -z "$CUR_PATH" ]]; then
                    rel="$file_name"
                else
                    rel="$CUR_PATH/$file_name"
                fi
                read -rp "Download $rel to $OSS_LOCAL_DIR/$rel? [Y/n] " confirm
                if [[ "$confirm" != [nN] ]]; then
                    download_item "$rel"
                fi
            fi
            ;;
    esac
done
