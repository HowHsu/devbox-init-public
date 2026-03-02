#!/usr/bin/env bash
set -euo pipefail

if nc -z 127.0.0.1 1081 2>/dev/null; then
    echo "    trojan already running on port 1081, skipping"
    exit 0
fi

if [ ! -d "$DOCKER_DEV_DEST/.git" ]; then
    rm -rf "$DOCKER_DEV_DEST"
    git clone git@github.com:HowHsu/docker_dev.git "$DOCKER_DEV_DEST"
fi

(
    cd "$DOCKER_DEV_DEST"
    git submodule update --init volumes/trojan
    cp "$OSS_DIR/trojan/config.json" volumes/trojan/config.json
    sg docker -c "bash scripts/import_image.sh trojan"
    sg docker -c "bash run_dockers/run_trojan.sh"
)

echo "==> Waiting for trojan proxy (port 1081)..."
for i in $(seq 1 30); do
    if nc -z 127.0.0.1 1081 2>/dev/null; then
        echo "    Proxy is ready."
        break
    fi
    sleep 1
done
if ! nc -z 127.0.0.1 1081 2>/dev/null; then
    echo "ERROR: Trojan proxy failed to start on port 1081" >&2
    exit 1
fi
