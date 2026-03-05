#!/usr/bin/env bash
# Shared rclone remote config (used by both backup and restore)

############################
# Configurable parameters
############################
OSS_LOCAL_DIR="$HOME/oss"
BUCKET_NAME=""
ENDPOINT="oss-cn-hangzhou.aliyuncs.com"
RAW_REMOTE="oss-raw"
CRYPT_REMOTE="oss-crypt"
RCLONE_TRANSFERS="${RCLONE_TRANSFERS:-4}"
RCLONE_CHECKERS="${RCLONE_CHECKERS:-8}"
############################

# Try to load OSS credentials from the encrypted file in the repo.
# Sets ACCESS_KEY_ID and ACCESS_KEY_SECRET on success; returns 1 on any error.
_load_credentials_from_repo() {
    local _dir
    _dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    local enc_file="$_dir/rclone_key/rclone_key.enc"

    if [[ ! -f "$enc_file" ]]; then
        echo "ERROR: Encrypted credentials not found: $enc_file" >&2
        return 1
    fi

    read -s -p "Decryption password: " _password
    echo ""

    local decrypted
    if ! decrypted=$(openssl enc -d -aes-256-cbc -pbkdf2 -iter 1000000 -in "$enc_file" -pass "pass:$_password" 2>&1); then
        echo "ERROR: Failed to decrypt credentials: $decrypted" >&2
        return 1
    fi
    unset _password

    ACCESS_KEY_ID=$(printf '%s' "$decrypted" | sed -n '1p')
    ACCESS_KEY_SECRET=$(printf '%s' "$decrypted" | sed -n '2p')

    if [[ -z "$ACCESS_KEY_ID" || -z "$ACCESS_KEY_SECRET" ]]; then
        echo "ERROR: Decrypted file is missing AccessKeyID or AccessKeySecret" >&2
        return 1
    fi
}

setup_rclone_remotes() {
    # Both remotes already configured — nothing to do
    if rclone listremotes | grep -q "^${RAW_REMOTE}:" && \
       rclone listremotes | grep -q "^${CRYPT_REMOTE}:"; then
        return 0
    fi

    if ! rclone listremotes | grep -q "^${RAW_REMOTE}:"; then
        ACCESS_KEY_ID=""
        ACCESS_KEY_SECRET=""

        if _load_credentials_from_repo; then
            echo "Credentials loaded from encrypted file"
        else
            echo "==== Enter OSS credentials manually ===="
            read -p "AccessKeyID: " ACCESS_KEY_ID
            read -s -p "AccessKeySecret: " ACCESS_KEY_SECRET
            echo ""
        fi

        rclone config create "$RAW_REMOTE" s3 \
            provider Alibaba \
            access_key_id "$ACCESS_KEY_ID" \
            secret_access_key "$ACCESS_KEY_SECRET" \
            endpoint "$ENDPOINT" \
            env_auth false \
            no_check_bucket true

        unset ACCESS_KEY_ID ACCESS_KEY_SECRET
        echo "OSS remote created"
    fi

    if ! rclone listremotes | grep -q "^${CRYPT_REMOTE}:"; then
        echo "==== Set encryption password (important — keep it safe) ===="
        read -s -p "Crypt password: " CRYPT_PASSWORD
        echo ""
        read -s -p "Salt (press Enter to skip): " CRYPT_SALT
        echo ""

        OBSCURED_PASS=$(rclone obscure "$CRYPT_PASSWORD")
        OBSCURED_SALT=$(rclone obscure "$CRYPT_SALT")

        rclone config create "$CRYPT_REMOTE" crypt \
            remote "$RAW_REMOTE:$BUCKET_NAME" \
            filename_encryption standard \
            directory_name_encryption true \
            password "$OBSCURED_PASS" \
            password2 "$OBSCURED_SALT"

        chmod 600 ~/.config/rclone/rclone.conf

        unset CRYPT_PASSWORD CRYPT_SALT OBSCURED_PASS OBSCURED_SALT
        echo "Crypt remote created"
    fi
}
