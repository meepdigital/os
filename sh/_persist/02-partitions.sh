partition_path() {
  local number="$1"

  case "${DEVICE}" in
    *[0-9]) printf '%sp%s' "${DEVICE}" "${number}" ;;
    *) printf '%s%s' "${DEVICE}" "${number}" ;;
  esac
}

set_device_partitions() {
  ISO_PART="$(partition_path 1)"
  PERSIST_PART="$(partition_path 4)"
}

verify_device() {
  local device_size_bytes

  if [[ ! "${DEVICE}" =~ ^/dev/ ]]; then
    echo "Device must be an absolute /dev path, for example /dev/sdd" >&2
    exit 1
  fi
  if [[ ! -b "${DEVICE}" ]]; then
    echo "USB disk ${DEVICE} is not present. Check lsblk before continuing." >&2
    exit 1
  fi
  [[ $(lsblk -dnro TYPE "${DEVICE}") == disk ]] || {
    echo "Target must be a whole disk, not a partition or loop device." >&2
    exit 1
  }
  if lsblk -nrpo MOUNTPOINTS "${DEVICE}" | grep -Eq '^(/|/boot(/efi)?|/home|/usr|/var|/tmp|/srv|/opt|/usr/local|\[SWAP\])$'; then
    echo "Refusing a disk used by the running host: ${DEVICE}" >&2
    exit 1
  fi
  device_size_bytes="$(blockdev --getsize64 "${DEVICE}" 2>/dev/null || printf '0')"
  if [[ "${device_size_bytes}" -le 0 ]]; then
    echo "USB disk ${DEVICE} reports 0 bytes. Insert the USB media and check lsblk before continuing." >&2
    exit 1
  fi
}

persist_phase_02_partitions() {
  ((BUILD_ONLY)) && return 0
  set_device_partitions
  verify_device
}
