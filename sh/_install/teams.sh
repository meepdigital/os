#!/bin/bash
# Ubuntu Meep provisioning module.

# Also allow this module to be invoked directly.
if ! declare -F meep_once >/dev/null; then
	. "$(dirname -- "${BASH_SOURCE[0]}")/cache.sh"
fi

if meep_package_installed teams-for-linux; then
	echo "Already installed: teams-for-linux; skipping."
else
	curl -fsSL https://repo.teamsforlinux.de/install.sh | bash
fi
