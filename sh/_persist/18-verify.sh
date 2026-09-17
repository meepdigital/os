persist_phase_18_verify() {
  if [[ ${MODE} == create && ${BUILD_ONLY} -eq 1 ]]; then
    [[ -f ${CUSTOM_ISO} ]] || { echo "Custom ISO was not created." >&2; exit 1; }
    echo "ISO built and boot files verified: ${CUSTOM_ISO}. Boot and persistence tests are still required."
  elif [[ ${MODE} == create ]]; then
    echo "USB written and read back. Persistence partition: ${PERSIST_PART}. Boot and reboot-persistence tests are still required."
  else
    echo "Resume complete. Boot ${DEVICE}; persistence is on ${PERSIST_PART}."
  fi
}
