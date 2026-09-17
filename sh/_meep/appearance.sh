#!/bin/bash

BACKGROUND_SOURCE="${SCRIPT_DIR}/assets/bg.svg"
BACKGROUND_DIR=/usr/share/backgrounds
BACKGROUND_PATH="${BACKGROUND_DIR}/bg.svg"
DCONF_DEFAULTS_DIR=/etc/dconf/db/local.d
DCONF_DEFAULTS_FILE="${DCONF_DEFAULTS_DIR}/00-ubuntu-meep-appearance"
LIGHTDM_DIR=/etc/lightdm
SLICK_GREETER_CONFIG="${LIGHTDM_DIR}/slick-greeter.conf"

if [[ ! -f "${BACKGROUND_SOURCE}" ]]; then
	echo "Missing background asset: ${BACKGROUND_SOURCE}" >&2
	exit 1
fi

install -d -m 0755 "${BACKGROUND_DIR}"
echo "Installing ${BACKGROUND_SOURCE} as ${BACKGROUND_PATH}..."
install -m 0644 "${BACKGROUND_SOURCE}" "${BACKGROUND_PATH}"
chmod 0644 "${BACKGROUND_PATH}"

# LightDM runs as its own greeter user and cannot use the source-tree path.
# Keep the greeter on the same installed asset as the desktop defaults.
install -d -m 0755 "${LIGHTDM_DIR}"
cat >"${SLICK_GREETER_CONFIG}" <<EOF
[Greeter]
background=${BACKGROUND_PATH}
background-color=#0d729e
draw-user-backgrounds=false
content-align=center
activate-numlock=true
show-a11y=false
show-power=false
show-keyboard=false
EOF
chmod 0644 "${SLICK_GREETER_CONFIG}"

install -d -m 0755 "${LIGHTDM_DIR}/lightdm.conf.d"
cat >"${LIGHTDM_DIR}/lightdm.conf.d/50-meep-greeter.conf" <<'EOF'
[Seat:*]
greeter-session=slick-greeter
EOF
chmod 0644 "${LIGHTDM_DIR}/lightdm.conf.d/50-meep-greeter.conf"

# Provisioning runs outside a user's graphical session, so install a dconf
# default for both Cinnamon and GNOME. This makes the setting active for the
# desktop user on first login instead of writing it only to root's profile.
install -d -m 0755 "${DCONF_DEFAULTS_DIR}"
{
	printf '%s\n' '[org/cinnamon]'
	printf '%s\n' "app-menu-icon-name='ubuntucinnamon-symbolic'"
	printf '\n%s\n' '[org/cinnamon/desktop/background]'
	printf '%s\n' "picture-uri='file://${BACKGROUND_PATH}'"
	printf '%s\n' "picture-uri-dark='file://${BACKGROUND_PATH}'"
	printf '%s\n' "picture-options='stretched'"
	printf '\n%s\n' '[org/gnome/desktop/background]'
	printf '%s\n' "picture-uri='file://${BACKGROUND_PATH}'"
	printf '%s\n' "picture-uri-dark='file://${BACKGROUND_PATH}'"
	printf '%s\n' "picture-options='stretched'"
} >"${DCONF_DEFAULTS_FILE}"
chmod 0644 "${DCONF_DEFAULTS_FILE}"

if ! command -v dconf >/dev/null 2>&1; then
	echo "dconf is required to activate the default background" >&2
	exit 1
fi

echo "Updating dconf database..."
dconf update
