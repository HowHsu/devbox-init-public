#!/usr/bin/env bash
#
# Build an Ubuntu Desktop autoinstall USB
#
# Workflow:
#   1. Query the latest LTS and stable versions, let the user choose
#   2. Download the Desktop ISO (skip if already present)
#   3. Extract ISO, read available install types (source id) for selection
#   4. Inject autoinstall config (password hash, source id)
#   5. Patch grub.cfg to enable unattended install
#   6. Repack into a bootable ISO
#   7. Write to USB
#
# After install, manually:
#   1. Connect to WiFi
#   2. git clone https://github.com/HowHsu/devbox_init ~/devbox_init
#   3. cd ~/devbox_init && bash init/bootstrap.sh
#
# Dependencies: xorriso fdisk openssl wget curl awk
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORK_DIR="/tmp/ubuntu-autoinstall-work"

# Chinese mirrors first, official source as fallback
MIRRORS=(
    "https://mirrors.tuna.tsinghua.edu.cn/ubuntu-releases"
    "https://mirrors.aliyun.com/ubuntu-releases"
    "https://releases.ubuntu.com"
)

# ── Check dependencies ───────────────────────────────────────────
check_deps() {
    local missing=()
    for tool in xorriso fdisk openssl wget curl awk python3; do
        command -v "$tool" &>/dev/null || missing+=("$tool")
    done
    if [ "${#missing[@]}" -gt 0 ]; then
        echo "ERROR: Missing tools: ${missing[*]}" >&2
        echo "  sudo apt-get install -y xorriso fdisk openssl wget curl" >&2
        exit 1
    fi
}

# ── Query latest Ubuntu LTS and stable versions ─────────────────
fetch_versions() {
    echo "==> Querying latest Ubuntu versions..."

    local lts_meta stable_meta
    lts_meta=$(curl -sf --max-time 15 "https://changelogs.ubuntu.com/meta-release-lts") || {
        echo "ERROR: Cannot reach changelogs.ubuntu.com, check your network" >&2; exit 1
    }
    stable_meta=$(curl -sf --max-time 15 "https://changelogs.ubuntu.com/meta-release") || stable_meta="$lts_meta"

    # Get the version and codename of the last Supported: 1 entry
    LTS_VER=$(awk '/^Dist:/{d=$2; v=""} /^Version:/{v=$2} /^Supported: 1/{ver=v; dist=d} END{print ver}' <<< "$lts_meta")
    LTS_NAME=$(awk '/^Dist:/{d=$2} /^Supported: 1/{dist=d} END{print dist}' <<< "$lts_meta")

    STABLE_VER=$(awk '/^Dist:/{d=$2; v=""} /^Version:/{v=$2} /^Supported: 1/{ver=v; dist=d} END{print ver}' <<< "$stable_meta")
    STABLE_NAME=$(awk '/^Dist:/{d=$2} /^Supported: 1/{dist=d} END{print dist}' <<< "$stable_meta")
}

# ── Get ISO filename and checksum from official SHA256SUMS ───────
# Checksum must come from releases.ubuntu.com, never trust mirrors
# ver may include point release (e.g. 24.04.4), releases URL uses major.minor (24.04)
# Outputs two lines: filename, then SHA256
get_iso_info() {
    local ver="$1"
    local base_ver escaped_ver sha_content filename checksum
    base_ver=$(echo "$ver" | grep -oP '^\d+\.\d+')
    escaped_ver="${base_ver//./\\.}"
    local sha_url="https://releases.ubuntu.com/${base_ver}/SHA256SUMS"

    sha_content=$(curl -sf --max-time 15 "$sha_url" 2>/dev/null) \
        || sha_content=$(proxychains4 curl -sf --max-time 15 "$sha_url" 2>/dev/null) \
        || return 1
    filename=$(echo "$sha_content" \
        | grep -oP "ubuntu-${escaped_ver}[\d.]*-desktop-amd64\.iso" \
        | sort -V | tail -1)
    if [[ -n "$filename" ]]; then
        checksum=$(echo "$sha_content" | grep "$filename" | awk '{print $1}')
        echo "$filename"
        echo "$checksum"
        return 0
    fi
    return 1
}

# ── Patch grub.cfg to inject autoinstall parameters ──────────────
patch_grub() {
    local cfg="$1"
    [[ -f "$cfg" ]] || return 0
    chmod u+w "$cfg"
    sed -i 's|^set timeout=.*|set timeout=5|' "$cfg"
    # Insert autoinstall parameters before --- on the casper/vmlinuz line
    sed -i '/casper\/vmlinuz/ s|---|autoinstall ds=nocloud\\;s=/cdrom/ ---|' "$cfg"
}

# ════════════════════════════════════════════════════════════════
check_deps

# ── Select Ubuntu version ────────────────────────────────────────
fetch_versions

echo ""
if [[ "$LTS_VER" == "$STABLE_VER" ]]; then
    echo "Latest version: Ubuntu ${LTS_VER} LTS (${LTS_NAME}) — also the latest stable"
    CHOSEN_VER="$LTS_VER"
    CHOSEN_NAME="$LTS_NAME"
else
    echo "Select Ubuntu version:"
    echo "  1) ${LTS_VER} LTS (${LTS_NAME}) — long-term support, recommended"
    echo "  2) ${STABLE_VER} (${STABLE_NAME}) — latest stable, newer kernel and packages"
    read -rp "Choose [1/2, default 1]: " ver_choice
    case "$ver_choice" in
        2) CHOSEN_VER="$STABLE_VER"; CHOSEN_NAME="$STABLE_NAME" ;;
        *) CHOSEN_VER="$LTS_VER";    CHOSEN_NAME="$LTS_NAME" ;;
    esac
fi
echo "==> Selected: Ubuntu ${CHOSEN_VER} (${CHOSEN_NAME})"

# ── Get ISO filename and checksum ────────────────────────────────
echo "==> Querying ISO info..."
ISO_INFO=$(get_iso_info "$CHOSEN_VER") || true
if [[ -z "$ISO_INFO" ]]; then
    echo "ERROR: Cannot get Ubuntu ${CHOSEN_VER} Desktop ISO info" >&2
    exit 1
fi
ISO_FILENAME=$(echo "$ISO_INFO" | sed -n '1p')
ISO_SHA256=$(echo "$ISO_INFO" | sed -n '2p')
ISO_FILE="$SCRIPT_DIR/$ISO_FILENAME"
BASE_VER=$(echo "$CHOSEN_VER" | grep -oP '^\d+\.\d+')
echo "    File: $ISO_FILENAME"
echo "    SHA256: $ISO_SHA256"

# ── Set user password ────────────────────────────────────────────
echo ""
echo "==> Set password for user 'hao'"
while true; do
    read -rsp "Enter password: " password; echo
    read -rsp "Confirm password: " password2; echo
    [[ "$password" == "$password2" ]] && break
    echo "ERROR: Passwords do not match, please retry"
done
HASHED_PASSWORD=$(openssl passwd -6 "$password")

# ── Download ISO ─────────────────────────────────────────────────
if [[ ! -f "$ISO_FILE" ]]; then
    echo "==> Downloading ISO (~5-6GB), trying mirrors in order..."
    downloaded=false
    for mirror in "${MIRRORS[@]}"; do
        url="$mirror/${BASE_VER}/${ISO_FILENAME}"
        echo "    Trying: $url"
        if wget --timeout=30 --tries=1 --progress=bar:force -O "$ISO_FILE" "$url"; then
            downloaded=true
            break
        fi
        rm -f "$ISO_FILE"
    done
    if [[ "$downloaded" != "true" ]]; then
        echo "    All mirrors failed, retrying official source via proxychains4..."
        proxychains4 wget --progress=bar:force -O "$ISO_FILE" \
            "https://releases.ubuntu.com/${BASE_VER}/${ISO_FILENAME}"
    fi
else
    echo "==> ISO already exists, skipping download: $(basename "$ISO_FILE")"
fi

# ── Verify ISO ───────────────────────────────────────────────────
echo "==> Verifying SHA256..."
ACTUAL_SHA256=$(sha256sum "$ISO_FILE" | awk '{print $1}')
if [[ "$ACTUAL_SHA256" != "$ISO_SHA256" ]]; then
    echo "ERROR: SHA256 verification failed!" >&2
    echo "    Expected: $ISO_SHA256" >&2
    echo "    Actual:   $ACTUAL_SHA256" >&2
    echo "    Please delete $ISO_FILE and re-run" >&2
    exit 1
fi
echo "    Verification passed"

# ── Extract ISO ──────────────────────────────────────────────────
echo "==> Extracting ISO..."
rm -rf "$WORK_DIR"
mkdir -p "$WORK_DIR"
xorriso -osirrox on -indev "$ISO_FILE" -extract / "$WORK_DIR" 2>/dev/null
chmod -R u+w "$WORK_DIR"

# ── Read available source ids ────────────────────────────────────
SOURCES_FILE="$WORK_DIR/casper/install-sources.yaml"
SOURCE_ID="ubuntu-desktop-minimal"   # default

if [[ -f "$SOURCES_FILE" ]]; then
    echo ""
    echo "==> Available install types in this ISO:"
    # Print id and name for reference
    python3 - "$SOURCES_FILE" <<'EOF'
import sys, re
with open(sys.argv[1]) as f:
    content = f.read()
ids   = re.findall(r'^\s*id:\s*(.+)', content, re.M)
names = re.findall(r'^\s*name:\s*(.+)', content, re.M)
for i, (sid, sname) in enumerate(zip(ids, names), 1):
    print(f"  {i}) {sid.strip():<35} {sname.strip()}")
EOF
    echo ""
    read -rp "Enter source id (press Enter for ubuntu-desktop-minimal): " user_source
    [[ -n "$user_source" ]] && SOURCE_ID="$user_source"
else
    echo "    (install-sources.yaml not found, using default source id: $SOURCE_ID)"
fi
echo "==> source id: $SOURCE_ID"

# ── Generate user-data ───────────────────────────────────────────
echo "==> Generating user-data..."
sed \
    -e "s|__HASHED_PASSWORD__|${HASHED_PASSWORD}|g" \
    -e "s|__SOURCE_ID__|${SOURCE_ID}|g" \
    "$SCRIPT_DIR/user-data" > "$WORK_DIR/user-data"
cp "$SCRIPT_DIR/meta-data" "$WORK_DIR/meta-data"

# ── Patch grub.cfg ───────────────────────────────────────────────
echo "==> Patching grub.cfg..."
patch_grub "$WORK_DIR/boot/grub/grub.cfg"
patch_grub "$WORK_DIR/EFI/boot/grub.cfg"
patch_grub "$WORK_DIR/boot/grub/loopback.cfg"

# ── Extract MBR and EFI partition ────────────────────────────────
echo "==> Extracting boot sectors..."
MBR_BIN="/tmp/ubuntu-autoinstall-mbr.bin"
EFI_IMG="/tmp/ubuntu-autoinstall-efi.img"

dd if="$ISO_FILE" bs=1 count=432 of="$MBR_BIN" 2>/dev/null

EFI_LINE=$(fdisk -l "$ISO_FILE" 2>/dev/null | grep "EFI" || true)
if [[ -z "$EFI_LINE" ]]; then
    echo "ERROR: Cannot find EFI partition in ISO" >&2
    exit 1
fi
EFI_START=$(echo "$EFI_LINE" | awk '{print $2}')
EFI_COUNT=$(echo "$EFI_LINE" | awk '{print $4}')
dd if="$ISO_FILE" bs=512 skip="$EFI_START" count="$EFI_COUNT" of="$EFI_IMG" 2>/dev/null

# ── Repack ISO ───────────────────────────────────────────────────
OUTPUT_ISO="/tmp/ubuntu-${CHOSEN_VER}-autoinstall.iso"
echo "==> Repacking ISO (may take a few minutes)..."
xorriso -as mkisofs \
    -r -V "Ubuntu-Autoinstall" \
    --grub2-mbr "$MBR_BIN" \
    --protective-msdos-label \
    -append_partition 2 28732ac11ff8d211ba4b00a0c93ec93b "$EFI_IMG" \
    -iso_mbr_part_type a2a0d0ebe5b9334487c068b6b72699c7 \
    -c '/boot.catalog' \
    -b '/boot/grub/i386-pc/eltorito.img' \
    -no-emul-boot -boot-load-size 4 -boot-info-table --grub2-boot-info \
    -eltorito-alt-boot \
    -e '--interval:appended_partition_2:::' \
    -no-emul-boot \
    -o "$OUTPUT_ISO" \
    "$WORK_DIR" \
    2>&1 | tail -3

# Clean up extracted directory
rm -rf "$WORK_DIR"

echo "==> ISO created: $OUTPUT_ISO"
echo "    Size: $(du -sh "$OUTPUT_ISO" | cut -f1)"

# ── Choose next action ───────────────────────────────────────────
echo ""
echo "ISO is ready. Choose next step:"
echo "  1) Keep ISO only (for VM testing)"
echo "  2) Write to USB drive (for physical machine install)"
read -rp "Choose [1/2, default 1]: " action_choice

if [[ "$action_choice" != "2" ]]; then
    echo ""
    echo "==> ISO path: $OUTPUT_ISO"
    echo ""
    echo "VM usage (QEMU example):"
    echo "  qemu-system-x86_64 -cdrom $OUTPUT_ISO -boot d \\"
    echo "    -m 4G -smp 2 -hda /path/to/disk.qcow2 -enable-kvm"
    exit 0
fi

# ── Write to USB ─────────────────────────────────────────────────
echo ""
echo "Current disk devices:"
lsblk -d -o NAME,SIZE,MODEL | grep -v "^loop"
echo ""
read -rp "Enter USB device name (e.g. sdb, without /dev/): " USB_DEV

if [[ -z "$USB_DEV" ]]; then
    echo "No device name entered, cancelled"
    exit 0
fi

USB_PATH="/dev/$USB_DEV"
if [[ ! -b "$USB_PATH" ]]; then
    echo "ERROR: $USB_PATH is not a block device" >&2
    exit 1
fi

USB_SIZE=$(lsblk -dno SIZE "$USB_PATH")
echo ""
echo "WARNING: About to overwrite $USB_PATH (${USB_SIZE}), all data will be lost!"
read -rp "Confirm write? [y/N] " confirm
if [[ "$confirm" != [yY] ]]; then
    echo "Cancelled"
    exit 0
fi

echo "==> Writing to USB (may take a few minutes)..."
sudo dd if="$OUTPUT_ISO" of="$USB_PATH" bs=4M status=progress oflag=sync
echo ""
echo "==> USB creation complete!"
echo ""
echo "Next steps:"
echo "  1. Insert USB, reboot, select USB boot in BIOS"
echo "  2. Wait for unattended install to finish (~10-20 min, no interaction needed)"
echo "  3. After install completes, system reboots automatically — remove USB"
echo "  4. Log in to desktop, connect to WiFi"
echo "  5. Open terminal and run:"
echo "       git clone https://github.com/HowHsu/devbox_init ~/devbox_init"
echo "       cd ~/devbox_init && bash init/bootstrap.sh"
