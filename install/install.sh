#!/usr/bin/env bash
#
# install.sh — install the built "mint-tuned" kernel debs on this Mint machine
#
# Usage:  ./install.sh linux-image-*.deb linux-headers-*.deb
#         (or just pass the whole directory of downloaded debs)
#
# Order matters: headers must be in place before the linux-image postinst
# hook triggers DKMS (nvidia-580) module builds.
set -euo pipefail

[ $# -gt 0 ] || { echo "usage: $0 linux-image-*.deb linux-headers-*.deb"; exit 1; }

headers=(); images=()
for f in "$@"; do
  case "$f" in
    *linux-headers-*) headers+=("$f") ;;
    *)                images+=("$f")  ;;
  esac
done

sudo dpkg -i "${headers[@]}" "${images[@]}"

# VirtualBox host modules are not dkms-managed here — rebuild explicitly.
if [ -x /usr/sbin/vboxconfig ]; then
  sudo /usr/sbin/vboxconfig || true
fi

sudo update-grub

KREL=$(dpkg -l 'linux-image-*' 2>/dev/null | awk '/mint-tuned/{print $2}' | tail -1 || true)
cat <<EOF

Installed. On next boot GRUB will default to the highest-versioned kernel
(i.e. the mint-tuned one). If the old stock kernel is preferred as fallback:
    sudoedit /etc/default/grub   # set GRUB_DEFAULT to the stock entry, then
    sudo update-grub

Verify after reboot:
    uname -r                     # expect ...-mint-tuned
    dkms status                  # nvidia/580.x built for the new kernel
    nvidia-smi
EOF
