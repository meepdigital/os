#!/bin/bash

# Configure the Cinnamon bottom panel from the local Meep desktop profile.
# This script is sourced by sh/meep after all applications and snaps exist.
set -euo pipefail

PANEL_HEIGHT=30
BOTTOM_PANEL_ID=1
WORKSPACE_APPLET="panel1:right:0:workspace-switcher@cinnamon.org:15"
GROUPED_WINDOW_APPLET_DIR=/usr/share/cinnamon/applets/grouped-window-list@cinnamon.org
GROUPED_WINDOW_UUID=grouped-window-list@cinnamon.org
MENU_APPLET_UUID=menu@cinnamon.org

PINNED_APPS=(
	nemo.desktop
	google-chrome.desktop
	sublime_text.desktop
	android-studio_android-studio.desktop
	blender_blender.desktop
	gimp.desktop
	org.inkscape.Inkscape.desktop
	slack.desktop
	discord.desktop
	teams-for-linux_teams-for-linux.desktop
)

ENABLED_APPLETS="['panel1:left:0:menu@cinnamon.org:0', 'panel1:left:1:grouped-window-list@cinnamon.org:2', '${WORKSPACE_APPLET}', 'panel1:right:5:notifications@cinnamon.org:5', 'panel2:right:4:removable-drives@cinnamon.org:7', 'panel1:right:4:sound@cinnamon.org:11', 'panel1:right:7:calendar@cinnamon.org:13', 'panel1:right:8:cornerbar@cinnamon.org:14', 'panel2:right:2:color-picker@fmete:22', 'panel2:right:1:force-quit@cinnamon.org:23', 'panel2:right:6:xapp-status@cinnamon.org:28', 'panel1:right:6:user@cinnamon.org:29', 'panel2:right:3:trash@cinnamon.org:30', 'panel2:right:5:spacer@cinnamon.org:34']"

if [[ ! -d ${GROUPED_WINDOW_APPLET_DIR} ]]; then
	echo "Missing Cinnamon grouped-window-list applet: ${GROUPED_WINDOW_APPLET_DIR}" >&2
	return 1
fi

PINNED_JSON=$(printf '%s\n' "${PINNED_APPS[@]}" | jq -R . | jq -s .)

install -d -m 0755 /etc/dconf/db/local.d
cat >/etc/dconf/db/local.d/00-ubuntu-meep-panel <<EOF
[org/cinnamon]
panels-enabled=['1:0:bottom', '2:0:right']
panels-height=['1:${PANEL_HEIGHT}', '2:${PANEL_HEIGHT}']
enabled-applets=${ENABLED_APPLETS}
date-format='%a, %h %d %Y%l:%M %p'

[org/cinnamon/desktop/interface]
clock-show-date=true
clock-show-seconds=true
clock-use-24h=true
EOF
chmod 0644 /etc/dconf/db/local.d/00-ubuntu-meep-panel

# These applet overrides provide the same defaults when Cinnamon creates the
# per-instance JSON files for a new user.
cat >"${GROUPED_WINDOW_APPLET_DIR}/settings-override.json" <<EOF
{
    "pinned-apps": {"override-props": true, "default": ${PINNED_JSON}}
}
EOF

set_user_panel_settings() {
	local config_file="$1"
	local config_tmp

	[[ -r ${config_file} ]] || return 0
	config_tmp=$(mktemp)
	if jq \
		--argjson pinned "${PINNED_JSON}" \
		'.["pinned-apps"].value = $pinned' \
		"${config_file}" >"${config_tmp}"; then
		chown --reference="${config_file}" "${config_tmp}"
		chmod --reference="${config_file}" "${config_tmp}"
		mv -- "${config_tmp}" "${config_file}"
	else
		rm -f -- "${config_tmp}"
		return 1
	fi
}

set_user_clock_settings() {
	local home_dir="$1"
	local uid
	local bus

	uid=$(stat -c '%u' "${home_dir}")
	local user_name
	user_name=$(getent passwd "${uid}" | cut -d: -f1)
	[[ -n ${user_name} ]] || return 0
	bus="/run/user/${uid}/bus"
	[[ -S ${bus} ]] || return 0

	runuser -u "${user_name}" -- env \
		DBUS_SESSION_BUS_ADDRESS="unix:path=${bus}" \
		gsettings set org.cinnamon panels-enabled "['1:0:bottom', '2:0:right']" || true
	runuser -u "${user_name}" -- env \
		DBUS_SESSION_BUS_ADDRESS="unix:path=${bus}" \
		gsettings set org.cinnamon panels-height "['1:${PANEL_HEIGHT}', '2:${PANEL_HEIGHT}']" || true
	runuser -u "${user_name}" -- env \
		DBUS_SESSION_BUS_ADDRESS="unix:path=${bus}" \
		gsettings set org.cinnamon enabled-applets "${ENABLED_APPLETS}" || true
	runuser -u "${user_name}" -- env \
		DBUS_SESSION_BUS_ADDRESS="unix:path=${bus}" \
		gsettings set org.cinnamon date-format "%a, %h %d %Y%l:%M %p" || true
	runuser -u "${user_name}" -- env \
		DBUS_SESSION_BUS_ADDRESS="unix:path=${bus}" \
		gsettings set org.cinnamon.desktop.interface clock-show-date true || true
	runuser -u "${user_name}" -- env \
		DBUS_SESSION_BUS_ADDRESS="unix:path=${bus}" \
		gsettings set org.cinnamon.desktop.interface clock-show-seconds true || true
	runuser -u "${user_name}" -- env \
		DBUS_SESSION_BUS_ADDRESS="unix:path=${bus}" \
		gsettings set org.cinnamon.desktop.interface clock-use-24h true || true
}

for home_dir in /home/* /root; do
	[[ -d ${home_dir} ]] || continue
	for config_file in \
		"${home_dir}/.config/cinnamon/spices/${GROUPED_WINDOW_UUID}"/*.json; do
		[[ -f ${config_file} ]] || continue
		set_user_panel_settings "${config_file}"
	done
	set_user_clock_settings "${home_dir}"
done

dconf update
echo "Configured Cinnamon bottom panel at ${PANEL_HEIGHT}px with Meep pinned applications."
echo "Added workspace switcher to panel ${BOTTOM_PANEL_ID}."
