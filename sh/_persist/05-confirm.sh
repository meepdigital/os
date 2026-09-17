persist_phase_05_confirm() {
  ((BUILD_ONLY)) && return 0
  [[ ${MODE} == create ]] || return 0
  echo "About to ERASE and rewrite ${DEVICE}."
  lsblk -o NAME,PATH,SIZE,FSTYPE,LABEL,MODEL,MOUNTPOINTS "${DEVICE}"
  echo
  local confirm
  read -r -p "Type ${DEVICE} exactly to continue: " confirm
  [[ ${confirm} == "${DEVICE}" ]] || { echo "Confirmation did not match; aborting." >&2; exit 1; }
}
