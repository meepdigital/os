build_custom_iso() {
  local manifest_full manifest manifest_size kernel_version

  kernel_version="$(find "${WORK}/rootfs/boot" -maxdepth 1 -type f -name 'vmlinuz-*' -printf '%f\n' | sed 's/^vmlinuz-//' | sort -V | tail -n 1)"
  [[ -n "${kernel_version}" && -s ${WORK}/rootfs/boot/initrd.img-${kernel_version} ]] || {
    echo "No matching generated kernel/initramfs pair; refusing to build." >&2
    exit 1
  }
  bash "${SCRIPT_DIR}/sh/_meep/plymouth.sh" --verify-initramfs \
    "${WORK}/rootfs/boot/initrd.img-${kernel_version}" "${SCRIPT_DIR}/assets/boot" \
    "${kernel_version}" live "${WORK}/casper-uuid-generic"
  for directory in dev proc sys run tmp; do
    [[ -d ${WORK}/rootfs/${directory} ]] || { echo "Missing boot mountpoint: /${directory}" >&2; exit 1; }
  done
  chroot "${WORK}/rootfs" /usr/bin/test -x /sbin/init

  CUSTOM_ISO="${SCRIPT_DIR}/$(basename "${ISO%.iso}")-persistent.iso"
  CUSTOM_SQUASHFS="${WORK}/minimal.squashfs"
  manifest_full="${WORK}/minimal.manifest.full"
  manifest="${WORK}/minimal.manifest"
  manifest_size="${WORK}/minimal.size"

  echo "Building the single Ubuntu Meep live filesystem from the merged root..."
  rm -f "${CUSTOM_SQUASHFS}"
  mksquashfs "${WORK}/rootfs" "${CUSTOM_SQUASHFS}" -comp xz -b 1M -noappend

  # dpkg-query, not this shell, expands these package fields.
  # shellcheck disable=SC2016
  chroot "${WORK}/rootfs" dpkg-query -W -f='${Package} ${Version}\n' | sort >"${manifest_full}"
  awk '{ print $1 }' "${manifest_full}" >"${manifest}"
  du -sx --block-size=1 "${WORK}/rootfs" | awk '{ print $1 }' >"${manifest_size}"

  xorriso -osirrox on -indev "${ISO}" -extract /md5sum.txt "${WORK}/md5sum.orig" >/dev/null 2>&1
  awk '$2 !~ /^\.\/casper\/minimal[.]/ && $2 !~ /^\.\/casper\/(vmlinuz|initrd)$/ &&
       $2 != "./boot/grub/grub.cfg" && $2 != "./boot/grub/loopback.cfg" && $2 != "./.disk/info" &&
       $2 != "./.disk/casper-uuid-generic" && $2 != "./md5sum.txt"' \
      "${WORK}/md5sum.orig" >"${WORK}/md5sum.txt"
  local source destination digest
  while read -r source destination; do
    digest=$(md5sum "${WORK}/${source}" | cut -d' ' -f1)
    printf '%s  ./%s\n' "${digest}" "${destination}" >>"${WORK}/md5sum.txt"
  done <<EOF
rootfs/boot/vmlinuz-${kernel_version} casper/vmlinuz
rootfs/boot/initrd.img-${kernel_version} casper/initrd
minimal.squashfs casper/minimal.squashfs
minimal.manifest.full casper/minimal.manifest.full
minimal.manifest casper/minimal.manifest
minimal.size casper/minimal.size
grub.cfg boot/grub/grub.cfg
loopback.cfg boot/grub/loopback.cfg
disk-info .disk/info
casper-uuid-generic .disk/casper-uuid-generic
EOF

  echo "Writing the Ubuntu Meep filesystem, manifests, and boot menu into the ISO..."
  rm -f "${CUSTOM_ISO}"
  xorriso -indev "${ISO}" -outdev "${CUSTOM_ISO}" -boot_image any replay \
      -rm \
        /casper/minimal.standard.live.squashfs \
        /casper/minimal.standard.live.manifest \
        /casper/minimal.standard.live.manifest.full \
        /casper/minimal.standard.live.size \
        /casper/minimal.standard.squashfs \
        /casper/minimal.standard.manifest \
        /casper/minimal.standard.manifest.full \
        /casper/minimal.standard.size \
      -- \
      -volid 'Ubuntu-Meep' \
      -map "${WORK}/rootfs/boot/vmlinuz-${kernel_version}" /casper/vmlinuz \
      -map "${WORK}/rootfs/boot/initrd.img-${kernel_version}" /casper/initrd \
      -map "${CUSTOM_SQUASHFS}" /casper/minimal.squashfs \
      -map "${WORK}/grub.cfg" /boot/grub/grub.cfg \
      -map "${WORK}/loopback.cfg" /boot/grub/loopback.cfg \
      -map "${WORK}/disk-info" /.disk/info \
      -map "${WORK}/casper-uuid-generic" /.disk/casper-uuid-generic \
      -map "${WORK}/md5sum.txt" /md5sum.txt \
      -map "${manifest_full}" /casper/minimal.manifest.full \
      -map "${manifest}" /casper/minimal.manifest \
      -map "${manifest_size}" /casper/minimal.size

  xorriso -osirrox on -indev "${CUSTOM_ISO}" \
    -extract /casper/vmlinuz "${WORK}/iso-vmlinuz" \
    -extract /casper/initrd "${WORK}/iso-initrd" >/dev/null 2>&1
  cmp "${WORK}/rootfs/boot/vmlinuz-${kernel_version}" "${WORK}/iso-vmlinuz"
  cmp "${WORK}/rootfs/boot/initrd.img-${kernel_version}" "${WORK}/iso-initrd"
  bash "${SCRIPT_DIR}/sh/_meep/plymouth.sh" --verify-initramfs \
    "${WORK}/iso-initrd" "${SCRIPT_DIR}/assets/boot" \
    "${kernel_version}" live "${WORK}/iso-casper-uuid-generic"
}

persist_phase_16_build_iso() {
  [[ ${MODE} == create ]] || return 0
  build_custom_iso
  sync
}
