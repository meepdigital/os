#!/usr/bin/env bash
set -euo pipefail
image=${1:?Usage: verify-initramfs.sh IMAGE ASSET_DIR KERNEL_VERSION [live]}
assets=${2:?Asset directory required}
kernel=${3:?Kernel version required}
mode=${4:-installed}
scratch=$(mktemp -d -t meep-initramfs.XXXXXXXX)
trap 'rm -rf -- "${scratch}"' EXIT
unmkinitramfs "${image}" "${scratch}"
root=${scratch}/main
[[ -d ${root} ]] || root=${scratch}
theme=usr/share/plymouth/themes/ubuntu-meep
cmp "${assets}/ubuntu-meep.plymouth" "${root}/${theme}/ubuntu-meep.plymouth"
for asset in "${assets}"/*.png "${assets}"/*.svg; do
    [[ -f ${asset} ]] || continue
    cmp "${asset}" "${root}/${theme}/$(basename "${asset}")"
done
[[ $(readlink "${root}/usr/share/plymouth/themes/default.plymouth") == /${theme}/ubuntu-meep.plymouth ]]
[[ -d ${root}/usr/lib/modules/${kernel} || -d ${root}/lib/modules/${kernel} ]]
if [[ ${mode} == live ]]; then
    [[ -f ${root}/scripts/casper ]]
    grep -Fx 'LAYERFS_PATH=minimal.squashfs' "${root}/conf/conf.d/default-layer.conf"
    [[ -s ${root}/conf/uuid.conf ]]
    if [[ -n ${5:-} ]]; then
        install -m 0644 "${root}/conf/uuid.conf" "$5"
    fi
fi
echo "Verified ${image}: selected Meep theme, all graphics, and ${kernel} modules."
