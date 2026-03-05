#!/usr/bin/env bash
#
# Encrypt OSS credentials into rclone_key.enc
# Output: rclone_key.enc in the current directory
#
set -euo pipefail

OUTPUT="$(pwd)/rclone_key.enc"

read -rp "AccessKeyID: " access_key_id
read -s -p "AccessKeySecret: " access_key_secret
echo ""
read -s -p "Encryption password: " password
echo ""
read -s -p "Confirm password: " password2
echo ""

if [[ "$password" != "$password2" ]]; then
    echo "ERROR: Passwords do not match" >&2
    exit 1
fi

printf '%s\n%s' "$access_key_id" "$access_key_secret" \
    | openssl enc -aes-256-cbc -pbkdf2 -iter 1000000 \
        -out "$OUTPUT" \
        -pass "pass:$password"

echo "Encrypted credentials saved to: $OUTPUT"
