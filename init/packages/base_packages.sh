#!/usr/bin/env bash
set -euo pipefail

sudo apt-get update -qq
sudo apt-get install -y -qq \
    rclone \
    git \
    curl \
    wget \
    build-essential \
    git-lfs \
    xz-utils \
    ca-certificates \
    gnupg \
    software-properties-common \
    apt-transport-https \
    tmux \
    vim \
    proxychains4 \
    netcat-openbsd \
    docker.io
