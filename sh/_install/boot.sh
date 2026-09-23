#!/bin/bash
# Ubuntu Meep provisioning module.

. "${SH_DIR}/plymouth.sh"

if [[ ${MEEP_LIVE_BUILD:-0} != 1 ]]; then
	# Keep a disk installation permanently free of live-media probes, even if
	# a later package operation restores casper's units or initramfs settings.
	rm -f /etc/initramfs-tools/conf.d/default-boot-to-casper.conf \
		/etc/initramfs-tools/conf.d/default-layer.conf \
		/etc/systemd/system/multi-user.target.wants/casper-md5check.service \
		/etc/systemd/system/final.target.wants/casper.service \
		/etc/casper.conf /usr/sbin/casper-stop /usr/lib/casper/casper-md5check \
		/lib/systemd/system/casper.service /lib/systemd/system/casper-md5check.service
	install -d -m 0755 /etc/systemd/system
	ln -sfn /dev/null /etc/systemd/system/casper-md5check.service
	ln -sfn /dev/null /etc/systemd/system/casper.service
	update-initramfs -u -k all
fi

# Live build roots have no GRUB target disk.
if [[ ${MEEP_LIVE_BUILD:-0} != 1 ]] && command -v update-grub >/dev/null; then
    update-grub
fi

echo "Installing the Ubuntu Meep graphical installer..."
INSTALL_APP_SRC="${SCRIPT_DIR}/installer"
INSTALL_APP_DST=/usr/local/lib/meep-installer
[[ -f ${INSTALL_APP_SRC}/src/main/main.js ]] || { echo "Missing installer source" >&2; exit 1; }
install -d -m 0755 "${INSTALL_APP_DST}" /usr/local/bin /etc/xdg/autostart
rsync -a --delete "${INSTALL_APP_SRC}/" "${INSTALL_APP_DST}/"
if [[ -f ${SCRIPT_DIR}/installer/dist/main.js ]]; then
    rsync -a --delete "${SCRIPT_DIR}/installer/dist/" "${INSTALL_APP_DST}/dist/"
fi
INSTALL_ELECTRON="${SCRIPT_DIR}/installer/node_modules/electron/dist/electron"
if [[ ! -x ${INSTALL_ELECTRON} ]]; then
    INSTALL_ELECTRON="$(npm root -g 2>/dev/null)/electron/dist/electron"
fi
[[ -x ${INSTALL_ELECTRON} ]] || { echo "Electron setup did not produce a usable executable." >&2; exit 1; }
install -d -m 0755 "${INSTALL_APP_DST}/electron-dist"
rsync -a --delete "$(dirname -- "${INSTALL_ELECTRON}")/" "${INSTALL_APP_DST}/electron-dist/"
chmod 0755 "${INSTALL_APP_DST}/electron-dist/electron"
install -m 0755 "${SCRIPT_DIR}/installer/sh/run" "${INSTALL_APP_DST}/run.sh"
install -m 0755 "${SCRIPT_DIR}/installer/sh/start" /usr/local/bin/start-ubuntu-meep
cat >/usr/local/bin/install-ubuntu-meep <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
exec /usr/local/lib/meep-installer/run.sh "$@"
EOF
chmod 0755 /usr/local/bin/install-ubuntu-meep
install -d -m 0755 /etc/sudoers.d
cat >/etc/sudoers.d/ubuntu-meep-installer <<'EOF'
# The live desktop has no root password. Limit passwordless elevation to Meep's installer.
%sudo ALL=(root) NOPASSWD: /usr/local/bin/install-ubuntu-meep
casper ALL=(root) NOPASSWD: /usr/local/bin/install-ubuntu-meep
EOF
chmod 0440 /etc/sudoers.d/ubuntu-meep-installer
cat >/usr/local/bin/meep-install-current <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
grep -qw -- 'meep.install=1' /proc/cmdline || exit 0
exec /usr/local/bin/start-ubuntu-meep "$@"
EOF
chmod 0755 /usr/local/bin/meep-install-current
install -d -m 0755 /usr/share/applications /usr/share/icons/hicolor/128x128/apps /etc/skel/Desktop
install -m 0644 "${SCRIPT_DIR}/installer/assets/installer.png" /usr/share/icons/hicolor/128x128/apps/ubuntu-meep-installer.png
cat >/usr/share/applications/install-ubuntu-meep.desktop <<'EOF'
[Desktop Entry]
Type=Application
Name=Install Ubuntu Meep
Comment=Install Ubuntu Meep on this computer
Exec=/usr/local/bin/start-ubuntu-meep
Icon=ubuntu-meep-installer
Terminal=false
Categories=System;Settings;
EOF
install -m 0755 /usr/share/applications/install-ubuntu-meep.desktop /etc/skel/Desktop/install-ubuntu-meep.desktop
cat >/etc/xdg/autostart/meep-install-current.desktop <<'EOF'
[Desktop Entry]
Type=Application
Name=Install Ubuntu Meep (boot mode)
Exec=/usr/local/bin/meep-install-current
NoDisplay=true
X-GNOME-Autostart-enabled=true
EOF
install -d -m 0755 /etc/systemd/user /etc/systemd/system
for service in ubuntu-desktop-installer.service \
    snap.ubuntu-desktop-bootstrap.subiquity-server.service; do
    ln -sfn /dev/null "/etc/systemd/user/${service}"
    ln -sfn /dev/null "/etc/systemd/system/${service}"
done
for desktop_dir in /usr/share/applications /etc/xdg/autostart; do
    [[ -d ${desktop_dir} ]] || continue
    while IFS= read -r installer_desktop; do
        rm -f "${installer_desktop}"
    done <<< "$(find "${desktop_dir}" -maxdepth 1 -type f -name '*.desktop' -exec \
        grep -Il -e ubuntu-desktop-installer {} +)"
done
echo "Meep graphics verified in /boot initramfs images."
