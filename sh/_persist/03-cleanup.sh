cleanup_existing_tree() {
  local base="$1" target loopdev
  [[ -d "${base}" ]] || return 0

  while read -r target; do
    [[ -n "${target}" ]] || continue
    if umount "${target}"; then
      continue
    fi
    echo "Mount is busy; lazily unmounting stale build mount: ${target}" >&2
    umount -l "${target}" || {
      echo "Could not remove stale build mount: ${target}" >&2
      return 1
    }
  done < <(findmnt -Rnr -o TARGET "${base}" | \
    awk -v base="${base}" '$0 == base || index($0, base "/") == 1 { print length, $0 }' | \
    sort -rn | cut -d' ' -f2-)

  while read -r loopdev; do
    [[ -n "${loopdev}" ]] || continue
    losetup -d "${loopdev}" >/dev/null 2>&1 || true
  done < <(losetup -a | awk -v base="${base}" 'index($0, base) { sub(/:.*/, "", $1); print $1 }')
}

cleanup() {
  set +e
  if [[ -f ${WORK}/meep-created-policy-rc.d ]]; then
    rm -f "${WORK}/root/usr/sbin/policy-rc.d"
  fi
  cleanup_existing_tree "${WORK_ROOT}/ubuntu-usb-build"
  cleanup_existing_tree "${WORK_ROOT}/ubuntu-usb-resume"
}

persist_phase_03_cleanup() {
  cleanup_existing_tree "${WORK_ROOT}/ubuntu-usb-build"
  cleanup_existing_tree "${WORK_ROOT}/ubuntu-usb-build"
  cleanup_existing_tree "${WORK_ROOT}/ubuntu-usb-resume"
  rm -rf "${WORK}"
  mkdir -p "${WORK}"
}
