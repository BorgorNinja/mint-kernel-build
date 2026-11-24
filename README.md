# mint-kernel-build

CI-built, hardware-tuned Linux kernel for this machine:

| | |
|---|---|
| Machine | Acer laptop, UEFI (Secure Boot **off**) |
| Distro | Linux Mint 22.3 "Zena" (Ubuntu 24.04 noble base) |
| Stock kernel | 7.0.0-43-generic |
| CPU | Intel i5-10210U — Comet Lake-U, 4C/8T, HWP, VT-x |
| GPU | Intel UHD (i915) + NVIDIA MX230 GP108M (proprietary **580.178.04**, DKMS) |
| Wi-Fi / BT | Qualcomm QCA9377 — `ath10k_pci` / `btusb` + `btqca` |
| Ethernet | Realtek RTL8111/8168 (`r8169`) |
| Storage | Kingston A1000 NVMe (root, ext4) + AHCI SATA |
| RAM | 4 GB + ~7.5 GB **zram** (zstd) swap; zswap disabled at runtime |
| Extras in use | Flatpak, Docker (overlayfs + nf_tables), zerotier (TUN), AppArmor, NTFS dual-boot partitions |

## What the tuning changes

Source: vanilla latest **7.x stable** from kernel.org, built with gcc-13 (same
major as the system compiler used by DKMS). Config starts from the running
stock config (`config/base-config`) and `scripts/tune.sh` applies:

**Performance**
- `-O3` optimization, `HZ=1000`, **full preemption** as the PREEMPT_DYNAMIC default
- All CPU speculation **mitigations compiled out** (`mitigations=off`), incl. PTI —
  this CPU is Meltdown-clean but was "Vulnerable" to GDS / MMIO-stale-data
- Multi-gen LRU kept enabled (big win at 4 GB RAM)
- No debug info / BTF — smaller kernel + modules, faster builds

**Size / trim** — drivers cut down to this hardware: i915 GPU family, NVMe,
AHCI, xHCI, ath10k (pci+usb), r8169, SOF/HDA audio, UVC webcam, USB HID,
USB-NIC/tethering stack. Dropped: every other GPU, WLAN, PCI NIC vendor
family, SAS/FC/InfiniBand, TV/radio/SDR, staging, legacy buses (ISA/EISA/
PCMCIA/FireWire/InfiniBand), NFS/9P/AFS/ceph and other unused filesystems,
SELinux/TOMOYO/SMACK (AppArmor stays), Xen/HyperV/KVM-guest paravirt.

**Deliberately kept for the distro**: ext4/btrfs/NTFS3/vfat/exFAT, squashfs +
overlayfs (flatpak/docker), zram/zsmalloc, nf_tables/bridge/veth/TUN
(docker/zerotier), USB broad support, uvcvideo, i2c-hid, KVM (module),
eBPF, AppArmor, UEFI + efivarfs, hibernate.

**Build fix**: Canonical's cert paths (`SYSTEM_TRUSTED_KEYS` etc.) nulled;
module signing keeps its auto-generated key. Secure Boot is disabled, so
nothing needs enrolling.

## Usage

1. **Build** — *Actions → build-kernel → Run workflow* (optionally pin a
   version; empty = latest 7.x stable). Pushes touching `config/` or
   `scripts/` also trigger builds. Result: `.deb` artifacts on every run,
   and a `v<ver>-mint-tuned` release for manual runs.
2. **Install** — download `linux-headers-*` + `linux-image-*` debs, then:
   ```bash
   sudo dpkg -i linux-headers-*.deb linux-image-*.deb
   sudo update-grub   # handled by install/install.sh, which also rebuilds VBox modules
   ```
   DKMS (NVIDIA 580) builds automatically via the kernel postinst hook —
   headers must be installed in the same `dpkg -i` call (install.sh sorts them).
3. **Verify** after reboot: `uname -r` → `…-mint-tuned`, `dkms status`,
   `nvidia-smi`, `cat /proc/sys/kernel/mitigations` (all "Vulnerable: no
   mitigation").

## Updating the base config

`config/base-config` is a snapshot of `/boot/config-7.0.0-43-generic`.
After installing a newer stock kernel, refresh it:

```bash
cp /boot/config-<new-version>-generic config/base-config
```

`make olddefconfig` handles renamed/new symbols, and `tune.sh` re-applies the
delta on top.

## Tuning further

Everything lives in `scripts/tune.sh` — one line per option. For example,
re-enable all mitigations: change `cfg --disable SPECULATION_MITIGATIONS` to
`--enable`. Commit → Actions builds → install.
