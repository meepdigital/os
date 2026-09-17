resolve_latest_iso() {
  local download_page release_dir release_url release_page iso_name iso_url sums_url expected_checksum

  echo "Resolving the latest Ubuntu desktop ISO..."
  download_page="$(curl -fsSL "${DOWNLOAD_PAGE_URL}")"
  release_dir="$(printf '%s' "${download_page}" | grep -Eom 1 'href="([[:alnum:].-]+)/"' | sed -E 's/^href="//; s#/"$##' || true)"
  [[ -n "${release_dir}" ]] || { echo "Could not find an Ubuntu release URL on ${DOWNLOAD_PAGE_URL}" >&2; exit 1; }
  release_url="${DOWNLOAD_PAGE_URL%/}/${release_dir}/"

  release_page="$(curl -fsSL "${release_url}")"
  iso_name="$(printf '%s' "${release_page}" | grep -Eom 1 'ubuntu-[0-9]+\.[0-9]+(\.[0-9]+)?-desktop-amd64\.iso' || true)"
  [[ -n "${iso_name}" ]] || { echo "Could not find an Ubuntu desktop AMD64 ISO on ${release_url}" >&2; exit 1; }

  iso_url="${release_url%/}/${iso_name}"
  sums_url="${release_url%/}/SHA256SUMS"
  ISO="${SCRIPT_DIR}/${iso_name}"
  CUSTOM_ISO="${SCRIPT_DIR}/${iso_name%.iso}-persistent.iso"
  if [[ -f "${ISO}" ]]; then
    echo "Using existing ISO: ${ISO}"
  else
    echo "Downloading ${iso_url}"
    curl -fL --progress-bar "${iso_url}" -o "${ISO}.part"
    mv "${ISO}.part" "${ISO}"
  fi

  echo "Verifying ${iso_name} against SHA256SUMS..."
  curl -fsSL "${sums_url}" -o "${WORK}/SHA256SUMS"
  expected_checksum="$(awk -v target="${iso_name}" '
    { sub(/\r$/, ""); filename=$2; sub(/^\*/, "", filename)
      if (filename == target && $1 ~ /^[[:xdigit:]]{64}$/) { print $1; exit } }
  ' "${WORK}/SHA256SUMS")"
  [[ -n "${expected_checksum}" ]] || { echo "No valid SHA-256 record found for ${iso_name} in ${WORK}/SHA256SUMS" >&2; exit 1; }
  printf '%s  %s\n' "${expected_checksum}" "${ISO}" | sha256sum -c -
}

persist_phase_06_source() {
  if [[ ${MODE} == create ]]; then
    [[ -n ${ISO} ]] || resolve_latest_iso
  else
    echo "Resuming chroot install on existing persistent USB."
    lsblk -o NAME,PATH,SIZE,FSTYPE,LABEL,MODEL,MOUNTPOINTS "${DEVICE}"
  fi
}
