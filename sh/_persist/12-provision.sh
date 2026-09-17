run_os_installer() {
  local chroot_status
  local os_args=()
  if ((OS_MINIMAL)); then os_args+=(--minimal); fi

  echo "Running /home/casper/os/sh/meep inside the persistent overlay chroot..."
  if ((OS_MINIMAL)); then
    echo "Running sh/meep in minimal mode."
    echo "Minimal mode: no optional snap installation will run before export."
  else
    echo "Snap installation will run in the target VM before export."
  fi
  set +e
  chroot "${WORK}/root" /usr/bin/env MEEP_CHROOT=1 MEEP_LIVE_BUILD=1 \
    /bin/bash -c 'bash /home/casper/os/sh/meep "$@"' os-installer "${os_args[@]}"
  chroot_status=$?
  set -e
  if [[ "${chroot_status}" -ne 0 ]]; then
    echo "Chroot installer failed with status ${chroot_status}; refusing to produce or write an incomplete OS." >&2
    exit "${chroot_status}"
  fi
  CHROOT_INSTALL_SUCCEEDED=1
  echo "Chroot installer completed successfully."
}

persist_phase_12_provision() {
  if [[ -n ${ROOT_SOURCE} ]]; then
    CHROOT_INSTALL_SUCCEEDED=1
  else
    run_os_installer
  fi
}
