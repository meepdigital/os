#!/bin/bash

. "${SH_DIR}/plymouth.sh"

# Overlay build roots have no GRUB target disk. persist.sh owns their ISO menu.
if [[ ${MEEP_LIVE_BUILD:-0} != 1 ]] && command -v update-grub >/dev/null; then
    update-grub
fi

echo "Installing the Ubuntu Meep current-system installer entrypoint..."
INSTALL_APP_SRC="${SCRIPT_DIR}/install"
INSTALL_APP_DST=/usr/local/lib/meep-install
[[ -f ${INSTALL_APP_SRC}/index.js ]] || { echo "Missing installer entrypoint" >&2; exit 1; }
install -d -m 0755 "${INSTALL_APP_DST}" /usr/local/bin /etc/xdg/autostart
rsync -a --delete "${INSTALL_APP_SRC}/" "${INSTALL_APP_DST}/"
cat >/usr/local/bin/meep-install-current <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
grep -qw -- 'meep.install=1' /proc/cmdline || exit 0
cd /usr/local/lib/meep-install
exec /usr/bin/env node /usr/local/lib/meep-install/index.js
EOF
chmod 0755 /usr/local/bin/meep-install-current
cat >/etc/xdg/autostart/meep-install-current.desktop <<'EOF'
[Desktop Entry]
Type=Application
Name=Install Current Ubuntu Meep
Exec=/usr/local/bin/meep-install-current
NoDisplay=true
X-GNOME-Autostart-enabled=true
EOF
install -d -m 0755 /etc/systemd/user /etc/systemd/system
for service in ubuntu-cinnamon-installer.service ubuntu-desktop-installer.service \
    snap.ubuntu-desktop-bootstrap.subiquity-server.service; do
    ln -sfn /dev/null "/etc/systemd/user/${service}"
    ln -sfn /dev/null "/etc/systemd/system/${service}"
done
for desktop_dir in /usr/share/applications /etc/xdg/autostart; do
    [[ -d ${desktop_dir} ]] || continue
    while IFS= read -r -d '' installer_desktop; do
        rm -f "${installer_desktop}"
    done < <(find "${desktop_dir}" -maxdepth 1 -type f -name '*.desktop' -exec \
        grep -IlZ -e ubuntu-cinnamon-installer -e ubuntu-desktop-installer {} +)
done
if [[ ${MEEP_LIVE_BUILD:-0} == 1 ]]; then
    echo "Meep graphics verified in /boot initramfs images; persist.sh will export this kernel/initramfs into the live ISO."
else
    echo "Meep graphics verified in the installed /boot initramfs images. A live USB requires a new ISO export via persist.sh."
fi
