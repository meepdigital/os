#!/bin/bash

set -euo pipefail

if [[ "${EUID}" -ne 0 ]]; then
	echo "Run this script as root." >&2
	exit 1
fi

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
SH_DIR="${SCRIPT_DIR}/sh"
case ${1:-} in
    --boot-only)
        # shellcheck source=/dev/null
        . "${SH_DIR}/boot.sh"
        exit 0 ;;
    '') ;;
    *) echo "Usage: os.sh [--boot-only]" >&2; exit 1 ;;
esac

export MEEP_CHROOT=${MEEP_CHROOT:-0}
if systemd-detect-virt --chroot --quiet; then
    export MEEP_CHROOT=1
fi

source_part() {
	local name="$1"
	local path="${SH_DIR}/${name}.sh"

	# shellcheck source=/dev/null
	. "${path}"
}

source_part setup
source_part base
source_part repo
source_part core
source_part spotify
source_part teams
source_part go
source_part firewall
source_part php
source_part mysql
source_part npm
source_part purge
source_part boot
source_part appearance
source_part design
source_part snap
source_part menu
source_part panel
