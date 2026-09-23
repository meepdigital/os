#!/bin/bash
# Ubuntu Meep provisioning module.

# Keep apt and package hooks non-interactive so the upgrader can run cleanly on
# an already booted Ubuntu machine without pausing for prompts.
export DEBIAN_FRONTEND=noninteractive
export NEEDRESTART_MODE=a

# The installed disk boots directly from its ext4 root.  These files are only
# valid when building a live ISO; leaving BOOT=casper in the installed root
# makes initramfs search for /dev/sr0 and fail when no optical medium exists.
if [[ ${MEEP_LIVE_BUILD:-0} != 1 ]]; then
	rm -f /etc/initramfs-tools/conf.d/default-boot-to-casper.conf \
		/etc/initramfs-tools/conf.d/default-layer.conf
	# The target is a disk installation, so no live-media service may probe
	# /dev/sr0 during boot or shutdown. Mask the units even if casper is present
	# in the source image for ISO construction.
	install -d -m 0755 /etc/systemd/system
	for live_unit in casper-md5check.service casper.service; do
		rm -f "/etc/systemd/system/multi-user.target.wants/${live_unit}" \
			"/etc/systemd/system/final.target.wants/${live_unit}"
		ln -sfn /dev/null "/etc/systemd/system/${live_unit}"
	done
	# Remove the live-media checker and shutdown helper themselves as a final
	# guard; the installed disk has no legitimate /cdrom workflow.
	rm -f /etc/casper.conf /usr/sbin/casper-stop /usr/lib/casper/casper-md5check \
		/lib/systemd/system/casper.service /lib/systemd/system/casper-md5check.service
fi

# Create the directories that later repository setup and service packages expect
# to exist. Doing this up front keeps Apache and apt keyring setup predictable.
install -d -m 0755 /etc/apt/keyrings
install -d -m 0755 /usr/share/keyrings
install -d -m 0755 /var/log/apache2
install -d -m 0755 -o www-data -g root /var/run/apache2
install -d -m 0755 -o www-data -g root /run/lock/apache2
install -d -m 0755 /usr/local/sbin

# Snap operations happen during the main install now, so expose one shared wait
# helper that later parts can reuse before they install or remove snap packages.
wait_for_snapd_ready() {
	local attempts="${1:-60}"
	local attempt

	if ! command -v snap >/dev/null 2>&1; then
		echo "snap is not available on this system" >&2
		return 1
	fi

	if command -v systemctl >/dev/null 2>&1 && [[ -d /run/systemd/system ]]; then
		systemctl enable --now snapd.socket snapd.service >/dev/null 2>&1 || true
	fi

	for attempt in $(seq 1 "${attempts}"); do
		if snap version >/dev/null 2>&1; then
			break
		fi
		sleep 2
	done

	if ! snap version >/dev/null 2>&1; then
		echo "snapd did not become ready in time" >&2
		return 1
	fi

	snap wait system seed.loaded >/dev/null 2>&1 || true
}
