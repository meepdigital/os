#!/bin/bash
# Ubuntu Meep provisioning module.

# Also allow this module to be invoked directly.
if ! declare -F meep_once >/dev/null; then
	. "$(dirname -- "${BASH_SOURCE[0]}")/cache.sh"
fi

# Install the MySQL client and server immediately on the running system.
MYSQL_PACKAGES=(
	mysql-client
	mysql-server
)

meep_apt_install "${MYSQL_PACKAGES[@]}"
