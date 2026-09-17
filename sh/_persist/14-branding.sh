persist_phase_14_branding() {
  [[ ${CHROOT_INSTALL_SUCCEEDED} -eq 1 ]] || return 0
  # Local packages can replace the alternatives/kernel. Reapply Meep branding.
  chroot "${WORK}/root" /usr/bin/env MEEP_CHROOT=1 MEEP_LIVE_BUILD=1 \
    /bin/bash /home/casper/os/sh/meep --boot-only
}
