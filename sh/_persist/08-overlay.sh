mount_overlay() {
  local lowerdirs="" idx=0 image name loopdev layer
  local images=()

  mkdir -p "${WORK}/iso" "${WORK}/persist" "${WORK}/root" "${WORK}/layers"
  if [[ -n "${ROOT_SOURCE}" ]]; then
    [[ ${MODE} == create ]] || { echo "--root cannot be used with --resume" >&2; exit 1; }
    echo "Copying ${ROOT_SOURCE} as the customized OS source..."
    rsync -aHAX --numeric-ids --exclude '/dev/***' --exclude '/proc/***' \
      --exclude '/sys/***' --exclude '/run/***' --exclude '/tmp/***' \
      --exclude '/boot/efi/***' --exclude '/cdrom/***' --exclude '/rofs/***' \
      --exclude '/mnt/***' --exclude '/media/***' --exclude '/meep/***' \
      "${ROOT_SOURCE}/" "${WORK}/root/"
    install -d -m 0755 "${WORK}/root/"{dev,proc,sys,run,cdrom,rofs,media,mnt}
    install -d -m 1777 "${WORK}/root/tmp"
    printf '# Live root is mounted by casper.\n' >"${WORK}/root/etc/fstab"
    rm -f "${WORK}/root/etc/initramfs-tools/conf.d/zz-meep-installed.conf"
    rm -f "${WORK}/root/etc/default/grub.d/98-meep-vm.cfg"
    return
  fi

  if [[ "${MODE}" == "create" ]]; then
    mount -o loop,ro "${ISO}" "${WORK}/iso"
  else
    mount -o ro "${ISO_PART}" "${WORK}/iso"
  fi
  cleanup_mounts+=("${WORK}/iso")
  if [[ "${MODE}" == "resume" ]]; then
    mount "${PERSIST_PART}" "${WORK}/persist"
    cleanup_mounts+=("${WORK}/persist")
  fi
  mkdir -p "${WORK}/persist/upper" "${WORK}/persist/work"

  echo "Mounting live filesystem overlay..."
  shopt -s nullglob
  if [[ -f ${WORK}/iso/casper/minimal.squashfs ]]; then
    images+=("${WORK}/iso/casper/minimal.squashfs")
    for name in minimal.standard.squashfs minimal.standard.live.squashfs; do
      [[ ! -f ${WORK}/iso/casper/${name} ]] || images+=("${WORK}/iso/casper/${name}")
    done
  elif [[ -f ${WORK}/iso/casper/filesystem.squashfs ]]; then
    images+=("${WORK}/iso/casper/filesystem.squashfs")
  else
    echo "Unsupported source layer layout; refusing to guess squashfs order." >&2
    exit 1
  fi
  for image in "${images[@]}"; do
    name="$(basename "${image}")"
    case "${name}" in ltsp.squashfs|server.squashfs) continue ;; esac
    idx=$((idx + 1))
    loopdev="$(losetup --find --show --read-only "${image}")"
    cleanup_loops+=("${loopdev}")
    layer="${WORK}/layers/${idx}-${name}"
    mkdir -p "${layer}"
    mount -t squashfs -o ro "${loopdev}" "${layer}"
    cleanup_mounts+=("${layer}")
    if [[ -z "${lowerdirs}" ]]; then lowerdirs="${layer}"; else lowerdirs="${layer}:${lowerdirs}"; fi
  done
  shopt -u nullglob
  [[ -n "${lowerdirs}" ]] || { echo "No squashfs layers found in the source ISO; aborting." >&2; exit 1; }
  mount -t overlay overlay \
    -o "upperdir=${WORK}/persist/upper,lowerdir=${lowerdirs},workdir=${WORK}/persist/work" \
    "${WORK}/root"
}

persist_phase_08_overlay() {
  mount_overlay
}
