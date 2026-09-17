prepare_chroot_mounts() {
  echo "Preparing chroot mounts..."
  mount --bind /dev "${WORK}/root/dev"
  mount --bind /dev/pts "${WORK}/root/dev/pts"
  mkdir -p "${WORK}/root/dev/shm"
  mount --bind /dev/shm "${WORK}/root/dev/shm"
  mount -t proc proc "${WORK}/root/proc"
  mount -t sysfs sysfs "${WORK}/root/sys"
  rm -f "${WORK}/root/etc/resolv.conf"
  cp -L /etc/resolv.conf "${WORK}/root/etc/resolv.conf"
  mount -t tmpfs -o mode=0755 tmpfs "${WORK}/root/run"
  if [[ ! -e ${WORK}/root/usr/sbin/policy-rc.d ]]; then
    printf '#!/bin/sh\nexit 101\n' >"${WORK}/root/usr/sbin/policy-rc.d"
    chmod 0755 "${WORK}/root/usr/sbin/policy-rc.d"
    touch "${WORK}/meep-created-policy-rc.d"
  fi
  if [[ -f "${WORK}/root/etc/apt/sources.list.d/cdrom.sources" ]]; then
    mv "${WORK}/root/etc/apt/sources.list.d/cdrom.sources" \
      "${WORK}/root/etc/apt/sources.list.d/cdrom.sources.disabled"
  fi
}

persist_phase_10_chroot_mounts() {
  prepare_chroot_mounts
}
