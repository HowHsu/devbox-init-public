# devbox_init

One-command setup for my Ubuntu development environment — from bare metal to fully configured workstation.

## Overview

```
bare metal  ──►  autoinstall USB  ──►  Ubuntu Desktop  ──►  bootstrap.sh  ──►  ready
```

1. **autoinstall/** — Build a USB drive (or ISO) that installs Ubuntu Desktop unattended
2. **init/bootstrap.sh** — Install all dev tools, restore backups, configure dotfiles
3. **init/oss_\*.sh** — Encrypted backup/restore to Alibaba Cloud OSS via rclone
4. **daily/** — Day-to-day utility scripts

## Quick Start

### On a new machine (after Ubuntu is installed)

```bash
git clone https://github.com/HowHsu/devbox_init ~/devbox_init
cd ~/devbox_init && bash init/bootstrap.sh
```

The bootstrap script will ask whether to install in **Desktop** or **Server** mode, then walk through two phases:

| Phase | Prerequisite | What gets installed |
|-------|-------------|---------------------|
| Phase 1 | Direct internet | base packages, Docker, WeChat, HexChat, OSS restore, SSH keys, dotfiles, Trojan proxy |
| Phase 2 | Proxy available (port 1081) | GitHub CLI, Firefox, Chrome, Claude Code, Cursor, Signal |

Each step is tracked in `init/bootstrap_done` — safe to re-run if interrupted.

### Make an autoinstall USB

```bash
cd ~/devbox_init/autoinstall
bash make_usb.sh
```

The script will:
1. Query the latest Ubuntu LTS/stable versions
2. Download the Desktop ISO (tries Chinese mirrors first, falls back to official + proxychains)
3. Verify SHA256 checksum (always fetched from `releases.ubuntu.com`)
4. Inject autoinstall config and repack the ISO
5. Optionally write to USB

See [autoinstall/README.md](autoinstall/README.md) for details and VM testing workflow.

## Project Structure

```
devbox_init/
├── autoinstall/              # Unattended Ubuntu installer
│   ├── make_usb.sh           #   main script: download, verify, repack, write
│   ├── user-data             #   cloud-init autoinstall template
│   └── meta-data
├── init/                     # Bootstrap & backup
│   ├── bootstrap.sh          #   orchestrator: runs packages/*.sh in order
│   ├── bootstrap_done        #   step completion tracker
│   ├── packages/             #   one script per software
│   │   ├── base_packages.sh
│   │   ├── docker.sh
│   │   ├── trojan.sh
│   │   ├── claude_code.sh
│   │   └── ...
│   ├── oss_common.sh         #   shared rclone config (OSS + encryption)
│   ├── oss_restore.sh        #   restore from OSS (interactive or scripted)
│   └── oss_encrypted_backup.sh  # encrypted backup to OSS
├── daily/                    # Day-to-day utilities
│   └── oss_download.sh       #   interactive OSS file browser
├── qemu_test_box/            # QEMU VM for testing (git submodule)
└── README.md
```

## OSS Backup & Restore

Files are encrypted client-side using rclone crypt and stored on Alibaba Cloud OSS. Credentials are entered interactively on first run — never stored in the repo.

```bash
# Backup (copy mode — only adds, never deletes remote files)
bash init/oss_encrypted_backup.sh [--dry-run]

# Restore specific paths
bash init/oss_restore.sh ssh_keys trojan

# Restore everything
bash init/oss_restore.sh

# Interactive file browser
bash daily/oss_download.sh
```

## Requirements

- Ubuntu 24.04+ (Desktop or Server)
- Internet access (Chinese mirrors supported; proxychains for GFW bypass)

## License

MIT
