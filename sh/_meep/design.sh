#!/bin/bash

# Runtime performance design for Ubuntu Meep. This is intentionally limited to
# disposable data: the installed OS, package database, user data, and the
# persistence overlay remain durable. It is safe to run repeatedly.

echo "Designing Ubuntu Meep performance profile..."

install -d -m 0755 /usr/local/sbin /etc/systemd/system

cat >/usr/local/sbin/meep-zram-start <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

command -v modprobe >/dev/null 2>&1 || exit 0
command -v zramctl >/dev/null 2>&1 || exit 0
command -v swapon >/dev/null 2>&1 || exit 0

if [[ ! -e /sys/block/zram0 ]]; then
	modprobe zram num_devices=1 || exit 0
fi
[[ -e /dev/zram0 ]] || exit 0

if ! swapon --show=NAME --noheadings | grep -Fxq /dev/zram0; then
	mem_kib="$(awk '/^MemTotal:/ { print $2; exit }' /proc/meminfo)"
	size_mib=$((mem_kib / 2048))
	((size_mib < 512)) && size_mib=512
	((size_mib > 8192)) && size_mib=8192

	if [[ "$(cat /sys/block/zram0/disksize 2>/dev/null || echo 0)" == 0 ]]; then
		zramctl --reset /dev/zram0 2>/dev/null || true
		zramctl --algorithm zstd --size "${size_mib}M" /dev/zram0 || exit 0
	fi
	if ! blkid -o value -s TYPE /dev/zram0 2>/dev/null | grep -Fxq swap; then
		mkswap -L meep-zram /dev/zram0 >/dev/null
	fi
	swapon --priority 100 /dev/zram0
fi
EOF
chmod 0755 /usr/local/sbin/meep-zram-start

cat >/etc/systemd/system/meep-zram.service <<'EOF'
[Unit]
Description=Ubuntu Meep compressed RAM swap
DefaultDependencies=no
After=systemd-modules-load.service
Before=swap.target
ConditionPathExists=/sys/block

[Service]
Type=oneshot
ExecStart=/usr/local/sbin/meep-zram-start
RemainAfterExit=yes

[Install]
WantedBy=swap.target
EOF

# /tmp is always disposable. The apt archive is also disposable: package
# downloads are recreated when needed, while installed packages remain in the
# durable dpkg filesystem. Size limits prevent these caches consuming all RAM.
cat >/etc/systemd/system/tmp.mount <<'EOF'
[Unit]
Description=Ubuntu Meep RAM-backed temporary directory
Before=local-fs.target

[Mount]
What=tmpfs
Where=/tmp
Type=tmpfs
Options=mode=1777,nosuid,nodev,size=25%

[Install]
WantedBy=local-fs.target
EOF

cat >/etc/systemd/system/var-cache-apt-archives.mount <<'EOF'
[Unit]
Description=Ubuntu Meep RAM-backed APT download cache
Before=local-fs.target
ConditionPathIsDirectory=/var/cache/apt/archives

[Mount]
What=tmpfs
Where=/var/cache/apt/archives
Type=tmpfs
Options=mode=0755,nosuid,nodev,size=10%

[Install]
WantedBy=local-fs.target
EOF

if command -v systemctl >/dev/null 2>&1; then
	systemctl daemon-reload || true
	systemctl enable meep-zram.service tmp.mount var-cache-apt-archives.mount || true
	# In a live chroot there is normally no systemd PID 1. Enabling is still
	# useful; starting is attempted only when a real system manager is present.
	if [[ ${MEEP_CHROOT:-0} != 1 && -d /run/systemd/system ]]; then
		systemctl start meep-zram.service tmp.mount var-cache-apt-archives.mount || true
	fi
fi

install -d -m 0755 /etc/ubuntu-meep
cat >/etc/ubuntu-meep/performance.conf <<'EOF'
# Ubuntu Meep performance profile
# Persistent Live: durable OverlayFS writes, disposable caches, zram enabled.
# Fast RAM Live: adds casper's toram boot option; durable writes still use the
# persistence partition so the custom Ubuntu Meep installer can consume the
# current merged live system.
EOF

echo "Ubuntu Meep performance design installed (tmpfs caches + zram)."
