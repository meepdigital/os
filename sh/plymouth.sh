#!/bin/bash

# Install and verify the Plymouth theme that must be present in both the
# installed root and the live media initramfs.  This is deliberately separate
# from the rest of the OS provisioning so boot graphics can be repaired alone.
echo "Installing Ubuntu Meep Plymouth graphics..."

BOOT_ASSETS_DIR="${SCRIPT_DIR}/assets/boot"
MEEP_THEME_DIR=/usr/share/plymouth/themes/ubuntu-meep
MEEP_DESCRIPTOR="${MEEP_THEME_DIR}/ubuntu-meep.plymouth"

for tool in update-alternatives mkinitramfs unmkinitramfs depmod; do
    command -v "${tool}" >/dev/null || {
        echo "Required Plymouth tool missing: ${tool}" >&2
        exit 1
    }
done

[[ -f ${BOOT_ASSETS_DIR}/ubuntu-meep.plymouth ]] || {
    echo "Missing Meep Plymouth descriptor: ${BOOT_ASSETS_DIR}/ubuntu-meep.plymouth" >&2
    exit 1
}

install -d -m 0755 "${MEEP_THEME_DIR}" /etc/plymouth /etc/default/grub.d
install -m 0644 "${BOOT_ASSETS_DIR}"/*.png "${BOOT_ASSETS_DIR}"/*.svg \
    "${BOOT_ASSETS_DIR}/ubuntu-meep.plymouth" "${MEEP_THEME_DIR}/"

# Register and select the actual descriptor.  Plymouth's initramfs hook reads
# the alternatives database; changing only the visible symlink is insufficient.
update-alternatives --install /usr/share/plymouth/themes/default.plymouth \
    default.plymouth "${MEEP_DESCRIPTOR}" 200
update-alternatives --set default.plymouth "${MEEP_DESCRIPTOR}"

selected_descriptor="$(readlink -f /usr/share/plymouth/themes/default.plymouth)"
[[ ${selected_descriptor} == "${MEEP_DESCRIPTOR}" ]] || {
    echo "Plymouth alternative selected ${selected_descriptor}, expected ${MEEP_DESCRIPTOR}" >&2
    exit 1
}
update-alternatives --query default.plymouth | \
    grep -Fx "Value: ${MEEP_DESCRIPTOR}" >/dev/null || {
    echo "Plymouth alternatives database did not select the Meep descriptor" >&2
    exit 1
}

cat >/etc/plymouth/plymouthd.conf <<'EOF'
[Daemon]
Theme=ubuntu-meep
ShowDelay=0
EOF
cat >/etc/default/grub.d/99-meep.cfg <<'EOF'
GRUB_DISTRIBUTOR="Ubuntu Meep"
GRUB_CMDLINE_LINUX_DEFAULT="quiet splash"
EOF

# The two-step plugin only loads bgrt-fallback.png when firmware-background
# handling is enabled.  Keep the fallback visible even when firmware exposes
# no usable ACPI BGRT image.
if [[ ${MEEP_LIVE_BUILD:-0} == 1 ]]; then
    install -d -m 0755 /etc/initramfs-tools/conf.d
    printf '%s\n' 'LAYERFS_PATH=minimal.squashfs' >/etc/initramfs-tools/conf.d/default-layer.conf
    printf '%s\n' 'BOOT=casper' >/etc/initramfs-tools/conf.d/default-boot-to-casper.conf
fi

grep -q '^UseFirmwareBackground=true$' "${MEEP_DESCRIPTOR}" || {
    echo "Meep Plymouth descriptor does not enable firmware/BGRT backgrounds" >&2
    exit 1
}
grep -q '^DialogClearsFirmwareBackground=false$' "${MEEP_DESCRIPTOR}" || {
    echo "Meep Plymouth descriptor must preserve the firmware/BGRT background" >&2
    exit 1
}

INITRAMFS_FOUND=0
for kernel_image in /boot/vmlinuz-*; do
    [[ -f ${kernel_image} ]] || continue
    kernel_version=${kernel_image##*/vmlinuz-}
    [[ -d /lib/modules/${kernel_version} ]] || {
        echo "Missing modules for ${kernel_version}" >&2
        exit 1
    }
    INITRAMFS_FOUND=1
    depmod "${kernel_version}"
    mkinitramfs -m most -o "/boot/initrd.img-${kernel_version}.meep-new" "${kernel_version}"
    verify_mode=installed
    [[ ${MEEP_LIVE_BUILD:-0} == 1 ]] && verify_mode=live
    bash "${SCRIPT_DIR}/scripts/verify-initramfs.sh" \
        "/boot/initrd.img-${kernel_version}.meep-new" "${BOOT_ASSETS_DIR}" \
        "${kernel_version}" "${verify_mode}"
    mv "/boot/initrd.img-${kernel_version}.meep-new" \
        "/boot/initrd.img-${kernel_version}"
done

((INITRAMFS_FOUND)) || {
    echo "No installed kernel in /boot; cannot build Plymouth initramfs" >&2
    exit 1
}

echo "Ubuntu Meep Plymouth theme and initramfs verified."
