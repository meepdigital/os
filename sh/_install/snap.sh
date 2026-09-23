#!/bin/bash
# Ubuntu Meep provisioning module.

# Install the requested desktop and tooling snaps during the main run. Existing
# installs are skipped so interrupted provisioning can resume cheaply.
if [[ ${MEEP_CHROOT:-0} == 1 ]]; then
	echo "Snap installation needs a running target; rerun sh/install after booting the target."
	return 0
fi
DIRECT_SNAPS=(
	plex-desktop
	mc-installer
	snap-store
	canonical-livepatch
)

CLASSIC_SNAPS=(
	flutter
	blender
	android-studio
)

wait_for_snapd_ready

for snap_name in "${DIRECT_SNAPS[@]}"; do
	if snap list "${snap_name}" >/dev/null 2>&1; then
		echo "Already installed: ${snap_name}; skipping."
	else
		snap install "${snap_name}"
	fi
done

for snap_name in "${CLASSIC_SNAPS[@]}"; do
	if snap list "${snap_name}" >/dev/null 2>&1; then
		echo "Already installed: ${snap_name}; skipping."
	else
		snap install "${snap_name}" --classic
	fi
done
