materialize_custom_root() {
  echo "Materializing the merged live root as the Ubuntu Meep source of truth..."
  rm -rf "${WORK}/rootfs"
  mkdir -p "${WORK}/rootfs"
  rsync -aHAX --numeric-ids --delete \
    --exclude '/dev/***' --exclude '/proc/***' --exclude '/sys/***' \
    --exclude '/run/***' --exclude '/tmp/***' --exclude '/cdrom/***' \
    --exclude '/rofs/***' --exclude '/media/***' --exclude '/mnt/***' \
    "${WORK}/root/" "${WORK}/rootfs/"
  install -d -m 0755 "${WORK}/rootfs/"{dev,proc,sys,run,cdrom,rofs,media,mnt}
  install -d -m 1777 "${WORK}/rootfs/tmp"
  if [[ -e ${WORK}/meep-created-policy-rc.d ]]; then
    rm -f "${WORK}/rootfs/usr/sbin/policy-rc.d"
  fi
  rm -f "${WORK}/rootfs/etc/resolv.conf"
  ln -s ../run/systemd/resolve/stub-resolv.conf "${WORK}/rootfs/etc/resolv.conf"
}

persist_phase_15_materialize() {
  materialize_custom_root
}
