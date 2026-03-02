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

setup_rclone_remotes() {
    if ! rclone listremotes | grep -q "$RAW_REMOTE"; then
        echo "==== First run, enter OSS credentials ===="
        read -p "AccessKeyID: " ACCESS_KEY_ID
        read -s -p "AccessKeySecret: " ACCESS_KEY_SECRET
        echo ""

        rclone config create $RAW_REMOTE s3 \
            provider Alibaba \
            access_key_id "$ACCESS_KEY_ID" \
            secret_access_key "$ACCESS_KEY_SECRET" \
            endpoint "$ENDPOINT" \
            env_auth false \
            no_check_bucket true

        echo "OSS remote created"
    fi

    if ! rclone listremotes | grep -q "$CRYPT_REMOTE"; then
        echo "==== Set encryption password (important — keep it safe) ===="
        read -s -p "Crypt password: " CRYPT_PASSWORD
        echo ""
        read -s -p "Salt (press Enter to skip): " CRYPT_SALT
        echo ""

        OBSCURED_PASS=$(rclone obscure "$CRYPT_PASSWORD")
        OBSCURED_SALT=$(rclone obscure "$CRYPT_SALT")

        rclone config create $CRYPT_REMOTE crypt \
            remote "$RAW_REMOTE:$BUCKET_NAME" \
            filename_encryption standard \
            directory_name_encryption true \
            password "$OBSCURED_PASS" \
            password2 "$OBSCURED_SALT"

        chmod 600 ~/.config/rclone/rclone.conf

        unset CRYPT_PASSWORD
        unset CRYPT_SALT

        echo "Crypt remote created"
    fi
}
