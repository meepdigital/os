#!/bin/bash

# Restrict the desktop menu to the explicit allowlist in md/menu_new.md.
# This script is sourced by os.sh and intentionally does not read md/menu.md.
set -euo pipefail

MENU_ALLOWLIST="${SCRIPT_DIR}/md/menu_new.md"
MENU_BACKUP=/var/lib/ubuntu-meep-menu/disabled
MENU_ICON_SOURCE="${SCRIPT_DIR}/assets/hand-open-symbolic.svg"
MENU_ICON_PATH=/usr/share/icons/hicolor/scalable/emblems/ubuntu-meep-hand-symbolic.svg
MENU_APPLET_DIR=/usr/share/cinnamon/applets/menu@cinnamon.org

[[ -r ${MENU_ALLOWLIST} ]] || {
	echo "Missing menu allowlist: ${MENU_ALLOWLIST}" >&2
	return 1
}

[[ -r ${MENU_ICON_SOURCE} ]] || {
	echo "Missing Meep menu icon: ${MENU_ICON_SOURCE}" >&2
	return 1
}

# Install the exact hand SVG used by the current local Cinnamon menu. The
# custom icon uses an absolute path so the result is independent of the
# selected icon theme.
install -D -m 0644 "${MENU_ICON_SOURCE}" "${MENU_ICON_PATH}"

# Cinnamon stores per-applet settings as JSON rather than in dconf. The
# override supplies defaults for new users; existing users are updated below.
if [[ -d ${MENU_APPLET_DIR} ]]; then
	cat >"${MENU_APPLET_DIR}/settings-override.json" <<EOF
{
    "menu-custom": {"override-props": true, "default": true},
    "menu-icon": {"override-props": true, "default": "${MENU_ICON_PATH}"},
    "menu-label": {"override-props": true, "default": ""}
}
EOF
else
	echo "Cinnamon menu applet directory not found: ${MENU_APPLET_DIR}" >&2
	return 1
fi

set_existing_menu_settings() {
	local config_file="$1"
	local config_tmp

	[[ -r ${config_file} ]] || return 0
	if ! command -v jq >/dev/null 2>&1; then
		echo "jq is required to update ${config_file}" >&2
		return 1
	fi

	config_tmp=$(mktemp)
	if jq \
		--arg icon "${MENU_ICON_PATH}" \
		'.["menu-custom"].value = true
		 | .["menu-icon"].value = $icon
		 | .["menu-label"].value = ""' \
		"${config_file}" >"${config_tmp}"; then
		chown --reference="${config_file}" "${config_tmp}"
		chmod --reference="${config_file}" "${config_tmp}"
		mv -- "${config_tmp}" "${config_file}"
	else
		rm -f -- "${config_tmp}"
		return 1
	fi
}

for home_dir in /home/* /root; do
	[[ -d ${home_dir} ]] || continue
	set_existing_menu_settings \
		"${home_dir}/.config/cinnamon/spices/menu@cinnamon.org/0.json"
done

allowlist_tmp=$(mktemp)
cleanup_menu_allowlist() {
	rm -f -- "${allowlist_tmp}"
}
trap cleanup_menu_allowlist EXIT

# Only Markdown bullet entries are accepted. A parenthetical documentation
# qualifier is removed, so e.g. "Minecraft (when the snap exposes...)" allows
# the actual desktop-entry name "Minecraft" and nothing else.
awk '
	/^- / {
		name = $0
		sub(/^- /, "", name)
		sub(/[[:space:]]+\([^)]*\)[[:space:]]*$/, "", name)
		if (name != "") print name
	}
' "${MENU_ALLOWLIST}" | LC_ALL=C sort -u >"${allowlist_tmp}"

[[ -s ${allowlist_tmp} ]] || {
	echo "Menu allowlist contains no bullet entries: ${MENU_ALLOWLIST}" >&2
	return 1
}

desktop_name_allowed() {
	local desktop_file="$1"
	local desktop_name

	while IFS= read -r desktop_name; do
		[[ -n ${desktop_name} ]] || continue
		if grep -Fqx -- "${desktop_name}" "${allowlist_tmp}"; then
			return 0
		fi
	done < <(
		awk -F= '
			/^Name(\[[^]]+\])?=/ {
				name = $0
				sub(/^[^=]*=/, "", name)
				print name
			}
		' "${desktop_file}"
	)

	return 1
}

disable_desktop_file() {
	local desktop_file="$1"
	local backup_file="${MENU_BACKUP}/${desktop_file#/}"

	install -d -m 0755 "$(dirname -- "${backup_file}")"
	mv -- "${desktop_file}" "${backup_file}"
	echo "Disabled menu item: ${desktop_file}"
}

install -d -m 0755 "${MENU_BACKUP}"

# Check system launchers and every existing user's launchers. The allowlist is
# the only source of permission; user-created launchers are not implicitly
# retained.
desktop_dirs=(
	/usr/share/applications
	/etc/xdg/applications
)
for home_dir in /home/* /root; do
	[[ -d ${home_dir} ]] || continue
	desktop_dirs+=("${home_dir}/.local/share/applications")
done

for desktop_dir in "${desktop_dirs[@]}"; do
	[[ -d ${desktop_dir} ]] || continue
	while IFS= read -r -d '' desktop_file; do
		if ! desktop_name_allowed "${desktop_file}"; then
			disable_desktop_file "${desktop_file}"
		fi
	done < <(find "${desktop_dir}" -maxdepth 1 -type f -name '*.desktop' -print0)
done

if command -v update-desktop-database >/dev/null 2>&1; then
	for desktop_dir in /usr/share/applications /etc/xdg/applications; do
		[[ -d ${desktop_dir} ]] || continue
		update-desktop-database "${desktop_dir}" >/dev/null 2>&1 || true
	done
fi

echo "Ubuntu Meep menu restricted to ${MENU_ALLOWLIST}"
echo "Cinnamon menu icon installed without a label: ${MENU_ICON_PATH}"
