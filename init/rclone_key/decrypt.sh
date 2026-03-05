#!/usr/bin/env bash
#
# Decrypt rclone_key.enc and print the OSS credentials
#
set -euo pipefail

enc_file="$(pwd)/rclone_key.enc"

if [[ ! -f "$enc_file" ]]; then
    echo "ERROR: Encrypted file not found: $enc_file" >&2
    exit 1
fi

read -s -p "Decryption password: " password
echo ""

echo "==== Decrypted credentials ===="
openssl enc -d -aes-256-cbc -pbkdf2 -iter 1000000 \
    -in "$enc_file" \
    -pass "pass:$password"
echo ""
echo "==== End ===="
