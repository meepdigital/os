#!/bin/bash
# Ubuntu Meep provisioning module.

# Also allow this module to be invoked directly.
if ! declare -F meep_once >/dev/null; then
	. "$(dirname -- "${BASH_SOURCE[0]}")/cache.sh"
fi

BASE_PACKAGES=(
	nodejs
	npm
	software-properties-common
	apt-transport-https
	ca-certificates
	curl
	gnupg
	git
	git-lfs
	zip
	gzip
	unzip
	7zip
	cmake
	jq
	wget
	nano
)

apt-get update
meep_apt_install "${BASE_PACKAGES[@]}"
