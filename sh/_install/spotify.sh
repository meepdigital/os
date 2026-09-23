#!/bin/bash

# Run in a subshell so options and cleanup do not affect the sourcing installer.
(
set -euo pipefail

if [[ ${EUID} -ne 0 ]]; then
	exec sudo bash "${BASH_SOURCE[0]}" "$@"
fi

if [[ $(dpkg-query -W -f='${Status}' spotify-client 2>/dev/null) == 'install ok installed' ]]; then
	echo "Already installed: spotify-client; skipping."
	exit 0
fi

keyring=$(mktemp)
trap 'rm -f "${keyring}"' EXIT
curl -fsSL --retry 3 --retry-delay 2 https://download.spotify.com/debian/pubkey_5384CE82BA52C83A.asc \
	| gpg --batch --dearmor --yes -o "${keyring}"
install -d -m 0755 /etc/apt/keyrings
install -m 0644 "${keyring}" /etc/apt/keyrings/spotify.gpg
echo "deb [arch=amd64 signed-by=/etc/apt/keyrings/spotify.gpg] https://repository.spotify.com stable non-free" \
	> /etc/apt/sources.list.d/spotify.list

apt-get update
apt-get install -y spotify-client
)
