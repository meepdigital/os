verify_required_paths() {
  local required_paths=("${OS_SRC}/sh/meep")
  local path

  if [[ "${MODE}" == "resume" ]]; then
    required_paths+=("${ISO_PART}" "${PERSIST_PART}")
  fi
  for path in "${required_paths[@]}"; do
    [[ -e "${path}" ]] || { echo "Missing required path: ${path}" >&2; exit 1; }
  done
}

persist_phase_04_required() {
  verify_required_paths
}
