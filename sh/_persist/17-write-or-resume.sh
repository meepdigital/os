unmount_device_partitions() {
  local partition_path
  echo "Unmounting existing ${DEVICE} partitions..."
  while read -r partition_path; do
    [[ -n "${partition_path}" ]] || continue
    if findmnt -rn -S "${partition_path}" >/dev/null; then
      umount "${partition_path}"
    fi
  done < <(lsblk -nrpo PATH "${DEVICE}" | tail -n +2 | tac)
}

write_usb() {
  local iso_bytes disk_bytes
  iso_bytes=$(stat -c %s "${CUSTOM_ISO}")
  disk_bytes=$(blockdev --getsize64 "${DEVICE}")
  ((disk_bytes > iso_bytes + 1073741824)) || { echo "Need at least 1 GiB beyond the ISO for persistence." >&2; exit 1; }
  echo "Writing ISO to ${DEVICE}..."
  dd if="${CUSTOM_ISO}" of="${DEVICE}" bs=4M status=progress conv=fsync
  sync
  partprobe "${DEVICE}" || true
  udevadm settle
  echo "Creating full-size persistence partition labeled writable..."
  sgdisk -e "${DEVICE}"
  sgdisk -n 4:0:0 -t 4:8300 -c 4:writable "${DEVICE}"
  partprobe "${DEVICE}" || true
  udevadm settle
  mkfs.ext4 -F -L writable "${PERSIST_PART}"
  [[ $(blkid -s LABEL -o value "${PERSIST_PART}") == writable ]]
  echo "Verifying the ISO data partition written to ${DEVICE}..."
  local start size
  start=$(lsblk -bnro START "${ISO_PART}")
  size=$(blockdev --getsize64 "${ISO_PART}")
  cmp -n "${size}" -i "$((start * 512)):0" "${CUSTOM_ISO}" "${ISO_PART}"
}

persist_phase_17_write_or_resume() {
  if [[ ${MODE} == create ]]; then
    ((BUILD_ONLY)) && return 0
    verify_device
    unmount_device_partitions
    write_usb
    return 0
  fi

  rsync -aHAX --numeric-ids --delete \
    --exclude '/dev/***' --exclude '/proc/***' --exclude '/sys/***' \
    --exclude '/run/***' --exclude '/tmp/***' --exclude '/cdrom/***' \
    --exclude '/rofs/***' --exclude '/media/***' --exclude '/mnt/***' \
    "${WORK}/rootfs/" "${WORK}/root/"
  sync
}
