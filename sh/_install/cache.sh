#!/bin/bash
# Shared resume state belongs to the target root, not the source checkout.
MEEP_STATE_DIR=${MEEP_STATE_DIR:-/var/lib/ubuntu-meep/provisioning}
MEEP_CACHE_DIR=${MEEP_CACHE_DIR:-/var/cache/ubuntu-meep}
install -d -m 0755 "${MEEP_STATE_DIR}" "${MEEP_CACHE_DIR}"

meep_package_installed() {
	[[ $(dpkg-query -W -f='${Status}' "$1" 2>/dev/null) == 'install ok installed' ]]
}

meep_apt_install() {
	local package
	local missing=()
	for package in "$@"; do
		if meep_package_installed "${package}"; then
			echo "Already installed: ${package}; skipping."
		else
			missing+=("${package}")
		fi
	done
	if ((${#missing[@]})); then
		apt-get install -y "${missing[@]}"
	fi
}

# Do not invoke this helper in an if/&&/|| condition: Bash would disable
# errexit throughout the command being run. Record success only afterwards.
meep_once() {
	local key="$1" fingerprint stamp temporary
	shift
	fingerprint=$(printf '%s\0' "${MEEP_PHASE_FINGERPRINT:-}" "$@" | sha256sum)
	fingerprint=${fingerprint%% *}
	stamp="${MEEP_STATE_DIR}/${key}"
	if [[ -f ${stamp} && $(cat "${stamp}") == "${fingerprint}" ]]; then
		echo "Already completed: ${key}; skipping."
		return 0
	fi
	"$@"
	temporary=$(mktemp "${stamp}.XXXXXX")
	printf '%s\n' "${fingerprint}" >"${temporary}"
	mv -f -- "${temporary}" "${stamp}"
}

install_downloaded_deb() {
	local name="$1" url="$2" package="$3" digest deb
	if meep_package_installed "${package}"; then
		echo "Already installed: ${package}; skipping."
		return 0
	fi
	digest=$(printf '%s' "${url}" | sha256sum)
	deb="${MEEP_CACHE_DIR}/${name}-${digest%% *}.deb"
	if ! dpkg-deb --info "${deb}" >/dev/null 2>&1; then
		curl -fL --retry 3 --retry-delay 2 "${url}" -o "${deb}.partial"
		dpkg-deb --info "${deb}.partial" >/dev/null
		mv -f -- "${deb}.partial" "${deb}"
	fi
	apt-get install -y "${deb}"
}
