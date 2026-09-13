#!/usr/bin/env bash
# Unprivileged regression checks of the real initramfs verifier.
set -euo pipefail
repo=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
fixture=$(mktemp -d -t meep-boot-test.XXXXXXXX)
trap 'rm -rf -- "${fixture}"' EXIT
root=${fixture}/root
theme=${root}/usr/share/plymouth/themes/ubuntu-meep
mkdir -p "${theme}" "${root}/usr/lib/modules/test-kernel" "${root}/scripts" "${root}/conf/conf.d"
cp "${repo}/assets/boot/"* "${theme}/"
ln -s /usr/share/plymouth/themes/ubuntu-meep/ubuntu-meep.plymouth \
    "${root}/usr/share/plymouth/themes/default.plymouth"
touch "${root}/scripts/casper"
printf '%s\n' 'test-media-uuid' >"${root}/conf/uuid.conf"
printf '%s\n' 'LAYERFS_PATH=minimal.squashfs' >"${root}/conf/conf.d/default-layer.conf"
pack() {
    (cd "${root}"; find . -print0 | cpio --quiet --null -o -H newc) | gzip >"${fixture}/initrd"
}
verify() {
    bash "${repo}/scripts/verify-initramfs.sh" "${fixture}/initrd" "${repo}/assets/boot" test-kernel live
}
expect_rejection() {
    if verify >"${fixture}/result" 2>&1; then
        echo "FAIL: verifier accepted $1" >&2; exit 1
    fi
    echo "PASS: rejected $1"
}
pack
verify
printf 'wrong graphics' >"${theme}/watermark.png"
pack
expect_rejection 'changed watermark bytes'
cp "${repo}/assets/boot/watermark.png" "${theme}/"
ln -sfn /usr/share/plymouth/themes/ubuntucinnamon-spinner/ubuntucinnamon-spinner.plymouth \
    "${root}/usr/share/plymouth/themes/default.plymouth"
pack
expect_rejection 'stock Cinnamon theme selection'
ln -sfn /usr/share/plymouth/themes/ubuntu-meep/ubuntu-meep.plymouth \
    "${root}/usr/share/plymouth/themes/default.plymouth"
printf '%s\n' 'LAYERFS_PATH=minimal.standard.live.squashfs' >"${root}/conf/conf.d/default-layer.conf"
pack
expect_rejection 'obsolete three-layer configuration'
printf '%s\n' 'LAYERFS_PATH=minimal.squashfs' >"${root}/conf/conf.d/default-layer.conf"
rmdir "${root}/usr/lib/modules/test-kernel"
pack
expect_rejection 'missing kernel modules'
