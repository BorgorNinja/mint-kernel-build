#!/usr/bin/env bash
#
# tune.sh — apply the "mint-tuned" delta to a kernel .config
#
# Base: Ubuntu/Mint 24.04 HWE config (7.0.0-43-generic)
# Target hardware: Acer laptop —
#   CPU    Intel i5-10210U (Comet Lake-U, 4C/8T, HWP, VT-x)
#   GPU    Intel UHD (i915) + NVIDIA MX230 GP108M (proprietary 580 via DKMS)
#   Wi-Fi  Qualcomm Atheros QCA9377 (ath10k_pci) + QCA BT over USB (btusb)
#   NIC    Realtek RTL8111/8168 (r8169)
#   Disk   Kingston A1000 NVMe (root), SATA AHCI controller
#   RAM    4 GB + 7.5 GB zram (zstd) swap — zswap disabled at runtime
#   Boot   UEFI, Secure Boot DISABLED (no signing needed)
#   Distro needs: ext4, NTFS3/NTFS dual-boot partitions, squashfs+overlay
#                 (flatpak/docker), AppArmor, zram, TUN (zerotier), nf_tables
#                 (docker), UVC webcam, SOF/HDA audio, USB HID breadth
#   DKMS   nvidia-580, (VirtualBox vboxhost via vboxconfig)
#
# Usage: run from the top of the kernel source tree after copying .config in.
set -euo pipefail

cfg() { ./scripts/config --file .config "$@"; }
dis() { for opt in "$@"; do cfg --disable "$opt"; done; }
en()  { for opt in "$@"; do cfg --enable  "$opt"; done; }

# ---------------------------------------------------------------- versioning
cfg --set-str LOCALVERSION "-mint-tuned"
cfg --disable LOCALVERSION_AUTO

# ------------------------------------------------------------------- build
# -O3 for every performance-relevant path; no debug info (build speed,
# smaller kernel/modules on a 4 GB RAM machine; drop BTF/BPF CO-RE extras).
cfg --enable CC_OPTIMIZE_FOR_PERFORMANCE_O3
cfg --disable CC_OPTIMIZE_FOR_PERFORMANCE
cfg --enable DEBUG_INFO_NONE
cfg --disable GDB_SCRIPTS
cfg --disable WERROR          # newer gcc must not abort the build
cfg --disable KVM_WERROR

# ------------------------------------------------------- scheduling / latency
# Desktop responsiveness: full preemption as the PREEMPT_DYNAMIC default,
# HZ=1000 was already set by the base config.
cfg --disable PREEMPT_NONE
cfg --disable PREEMPT_VOLUNTARY
cfg --enable PREEMPT

# ---------------------------------------------------------------- mitigations
# User choice: mitigations=off compiled in (single-user personal machine).
# SPECULATION_MITIGATIONS=n removes all Spectre/MDS/GDS/Retbleed workarounds;
# PTI is pointless here (CPU reported "Not affected" for Meltdown).
cfg --disable SPECULATION_MITIGATIONS
cfg --disable PAGE_TABLE_ISOLATION
cfg --disable X86_KERNEL_IBT
# Cert paths from Ubuntu must go or the build fails; module signing keeps its
# auto-generated certs/signing_key.pem. Secure Boot is off anyway.
cfg --set-str SYSTEM_TRUSTED_KEYS ""
cfg --set-str SYSTEM_REVOCATION_KEYS ""

# ------------------------------------------------------------------ security
# Mint uses AppArmor; the other LSMs are dead weight here.
cfg --disable SECURITY_SELINUX
cfg --disable SECURITY_TOMOYO
cfg --disable SECURITY_SMACK
cfg --disable SECURITY_LOCKDOWN_LSM_EARLY

# ---------------------------------------------------------- virtualization
# Bare-metal host; drop guest paravirt backends, keep KVM for QEMU as module.
dis XEN HYPERV PARAVIRT KVM_GUEST KVM_AMD KVM_SW_PROTECTED_VM

# ------------------------------------------------------- buses / dead weight
dis INFINIBAND FUSION SCSI_LOW_LEVEL SCSI_SAS_ATTRS SCSI_SAS_LIBSAS \
    ISDN CAIF ATM PHONET NFC IEEE802154 AF_RXRPC AX25 HAMRADIO CAN \
    WAN UWB PCMCIA FIREWIRE EISA ISA APPLETALK STAGING USB_GADGET \
    USBIP_CORE AGP SND_PCM_OSS RC_CORE

# ------------------------------------------------------------ Ethernet NICs
# Keep Realtek r8169 + the whole USB-NIC/tethering stack; drop every PCI
# vendor family we don't have.
dis NET_VENDOR_3COM NET_VENDOR_ADAPTEC NET_VENDOR_AGERE NET_VENDOR_ALACRITECH \
    NET_VENDOR_ALTEON NET_VENDOR_AMAZON NET_VENDOR_AMD NET_VENDOR_AQUANTIA \
    NET_VENDOR_ARC NET_VENDOR_ASIX NET_VENDOR_ATHEROS NET_VENDOR_BROADCOM \
    NET_VENDOR_CAVIUM NET_VENDOR_CHELSIO NET_VENDOR_CIRRUS NET_VENDOR_CORTINA \
    NET_VENDOR_DAVICOM NET_VENDOR_DEC NET_VENDOR_DL2K NET_VENDOR_DLINK \
    NET_VENDOR_EMULEX NET_VENDOR_ENGLEDER NET_VENDOR_EZCHIP NET_VENDOR_FARADAY \
    NET_VENDOR_FREESCALE NET_VENDOR_FUJITSU NET_VENDOR_GOOGLE NET_VENDOR_HISILICON \
    NET_VENDOR_HP NET_VENDOR_HUAWEI NET_VENDOR_I825XX NET_VENDOR_IBM \
    NET_VENDOR_INTEL NET_VENDOR_LSI NET_VENDOR_MARVELL NET_VENDOR_MELLANOX \
    NET_VENDOR_MICROCHIP NET_VENDOR_MICROSEMI NET_VENDOR_MSCC NET_VENDOR_MYRI \
    NET_VENDOR_NATSEMI NET_VENDOR_NETERION NET_VENDOR_NETRONOME NET_VENDOR_NI \
    NET_VENDOR_NUVOTON NET_VENDOR_NXP NET_VENDOR_OKI NET_VENDOR_PACKETHQ \
    NET_VENDOR_PENSANDO NET_VENDOR_QLOGIC NET_VENDOR_QUALCOMM NET_VENDOR_RDC \
    NET_VENDOR_RENESAS NET_VENDOR_SAMSUNG NET_VENDOR_SEEQ NET_VENDOR_SILICOM \
    NET_VENDOR_SIS NET_VENDOR_SMSC NET_VENDOR_SOCIONEXT NET_VENDOR_SOLARFLARE \
    NET_VENDOR_STMICRO NET_VENDOR_SUN NET_VENDOR_SYNOPSYS NET_VENDOR_TEHUTI \
    NET_VENDOR_TI NET_VENDOR_VIA NET_VENDOR_WIZNET NET_VENDOR_XILINX

# ---------------------------------------------------------------------- WLAN
# Keep the ath family (QCA9377 = ath10k_pci; ath9k/htc for cheap USB dongles).
dis WLAN_VENDOR_ADMTEK WLAN_VENDOR_ATMEL WLAN_VENDOR_BROADCOM WLAN_VENDOR_CISCO \
    WLAN_VENDOR_INTEL WLAN_VENDOR_INTERSIL WLAN_VENDOR_MARVELL WLAN_VENDOR_MEDIATEK \
    WLAN_VENDOR_RALINK WLAN_VENDOR_REALTEK WLAN_VENDOR_RSI WLAN_VENDOR_ST \
    WLAN_VENDOR_TI WLAN_VENDOR_ZYDAS WLAN_VENDOR_QUANTENNA
dis ATH6KL ATH11K ATH12K CARL9170

# ---------------------------------------------------------------- Bluetooth
# QCA9377 BT is a USB device: btusb + btqca/btath3k is all that's needed.
dis BT_INTEL BT_BCM BT_MTK BT_HCIUART BT_HCIBCM203X BT_HCIBFUSB BT_HCIBTSDIO \
    BT_HCIVHCI BT_MRVL BT_NXPUART

# ---------------------------------------------------------------------- GPU
# i915 (in use) + simpledrm (early boot); the NVIDIA module comes from DKMS.
dis DRM_NOUVEAU DRM_RADEON DRM_AMDGPU DRM_XE DRM_VMWGFX DRM_GMA500 DRM_UDL \
    DRM_AST DRM_MGAG200 DRM_QXL DRM_VIRTIO_GPU DRM_BOCHS DRM_CIRRUS_QEMU \
    DRM_HISI_HIBMC DRM_LOONGSON DRM_GM12U320

# -------------------------------------------------------------------- media
# Webcam (Quanta UVC) is USB; drop PCI capture/TV/radio/SDR/platform video.
dis MEDIA_PCI_SUPPORT MEDIA_ANALOG_TV_SUPPORT MEDIA_DIGITAL_TV_SUPPORT \
    MEDIA_RADIO_SUPPORT MEDIA_SDR_SUPPORT MEDIA_PLATFORM_SUPPORT \
    MEDIA_TEST_SUPPORT DVB_CORE

# -------------------------------------------------------------------- input
# Built-in HID keyboard/touchpad + USB mouse/hubs stay; exotic input goes.
dis INPUT_JOYSTICK GAMEPORT INPUT_TABLET INPUT_TOUCHSCREEN

# -------------------------------------------------------------- filesystems
# Keep: ext4, btrfs, vfat, ntfs3, exfat, fuse, squashfs, overlay, iso9660,
# udf, autofs, cifs (SMB shares), efivarfs, pstore.
# Drop: network + museum filesystems we never mount.
dis XFS_FS NILFS2_FS F2FS_FS ADFS_FS AFFS_FS AFS_FS BEFS_FS BFS_FS \
    CEPH_FS CODA_FS CRAMFS_FS EFS_FS EROFS_FS HFS_FS HFSPLUS_FS HPFS_FS \
    MINIX_FS NFS_FS NFSD SUNRPC NET_9P 9P_FS NTFS_FS OCFS2_FS OMFS_FS \
    QNX4FS_FS QNX6FS_FS ROMFS_FS SYSV_FS UFS_FS VXFS_FS JFFS2_FS

# --------------------------------------------------------------- misc cores
dis LIVEPATCH FW_LOADER_USER_HELPER FW_LOADER_DEBUG

# --------------------------------------------------------------------- apply
make O=. olddefconfig

echo
echo "=== Effective changes vs base config ==="
BASE="${BASE_CONFIG:-../config/base-config}"
diff -u "$BASE" .config | grep -E '^[+-]CONFIG' | sort -u || true
