# Ubuntu Autoinstall USB Builder

## Files

| File | Description |
|------|-------------|
| `make_usb.sh` | Main script: query versions, download ISO, inject autoinstall config, repack, optionally write to USB |
| `user-data` | Autoinstall config template (password and source id are substituted by the script) |
| `meta-data` | Required empty file for cloud-init |

## Dependencies

```bash
sudo apt-get install -y xorriso fdisk openssl wget curl
```

## Usage

```bash
cd ~/devbox_init/autoinstall
bash make_usb.sh
```

The script will:
1. Query the latest LTS and stable versions, let you choose
2. Download the Desktop ISO from `releases.ubuntu.com` (skip if already present)
3. Extract the ISO, read available install types (`ubuntu-desktop` / `ubuntu-desktop-minimal`) for selection
4. Prompt for user password (hashed with `openssl passwd -6`, plaintext is never stored)
5. Inject config into ISO, patch grub.cfg for unattended install
6. Repack into a bootable ISO

Then ask for next step:

```
ISO is ready. Choose next step:
  1) Keep ISO only (for VM testing)
  2) Write to USB drive (for physical machine install)
```

## VM Testing Workflow

Before writing to a real USB, it's recommended to test the ISO in a VM first.

### Step 1: Generate autoinstall ISO

```bash
cd ~/devbox_init/autoinstall
bash make_usb.sh
# Choose 1 (ISO only, don't write to USB)
# ISO output: /tmp/ubuntu-<version>-autoinstall.iso
```

### Step 2: Test with QEMU

```bash
cd ~/devbox_init/qemu_test_box
bash test_autoinstall.sh
```

The script automatically finds `/tmp/ubuntu-*-autoinstall.iso`, creates a 25G blank test disk, and starts a QEMU window for unattended install (~10-20 min, no interaction needed).

You can also specify the ISO path manually:

```bash
bash test_autoinstall.sh /path/to/ubuntu-xxx-autoinstall.iso
```

After install, the VM reboots automatically and boots from disk. Verify that the desktop login works.

> SSH port: 2223 (`ssh -p 2223 hao@localhost`), to avoid conflict with `run_vm.sh`'s port 2222.

### Step 3: Write to USB after verification

```bash
bash make_usb.sh
# Choose 2 (write to USB)
# Enter device name when prompted, e.g. sdb
```

## Physical Machine Install

1. Insert USB, reboot, select USB boot in BIOS
2. Wait for unattended install to finish (~10-20 min, no interaction needed)
3. After install completes, system reboots automatically — remove USB
4. Log in to desktop, connect to WiFi
5. Open terminal and run:

```bash
git clone https://github.com/HowHsu/devbox_init ~/devbox_init
cd ~/devbox_init && bash init/bootstrap.sh
```
