prompt_for_device() {
  local entered_device

  if [[ -n "${DEVICE}" ]]; then
    return 0
  fi

  echo "Available block devices:"
  lsblk -d -o NAME,PATH,SIZE,MODEL,TRAN,TYPE
  echo
  read -r -p "Device to erase and use for persistence, for example /dev/sdd: " entered_device
  DEVICE="${entered_device}"
}

persist_phase_01_device() {
  ((BUILD_ONLY)) || prompt_for_device
}
