#!/bin/bash
# Ubuntu Meep provisioning module.

set -euo pipefail

NODULAR_SOURCE="${SCRIPT_DIR}/nodular"
NODULAR_BUILD_DIR="${NODULAR_SOURCE}/build"
NODULAR_PREFIX=/usr/local/lib/nodular

[[ -f ${NODULAR_BUILD_DIR}/js/session.mjs && -f ${NODULAR_BUILD_DIR}/js/main.mjs && -f ${NODULAR_BUILD_DIR}/js/wm.mjs ]] || {
	echo "Missing Nodular build output. Run: npm --prefix nodular install && npm --prefix nodular run build" >&2
	exit 1
}
[[ -f ${NODULAR_BUILD_DIR}/Release/x11wm.node && -d ${NODULAR_SOURCE}/node_modules ]] || {
	echo "Nodular native build or dependencies are missing. Run: npm --prefix nodular run build" >&2
	exit 1
}

echo "Installing Nodular as the default Ubuntu Meep window manager..."
if [[ -r /var/lib/ubuntu-meep/electron-path ]]; then
	export NODULAR_ELECTRON="$(< /var/lib/ubuntu-meep/electron-path)"
fi
if [[ ${MEEP_LIVE_BUILD:-0} == 1 && -z ${NODULAR_USER:-} ]]; then
	# The casper account is created only when the live system boots, so it is
	# not present in the build chroot's passwd database.
	export NODULAR_USER=casper
fi
# A freshly seeded Ubuntu live root has no regular account until casper creates
# it at boot. Configure Nodular for that account during image provisioning.
if [[ -z ${NODULAR_USER:-} ]] && ! getent passwd | awk -F: '$3 >= 1000 && $3 < 65534 && $6 ~ /^\/home\// { found=1; exit } END { exit !found }'; then
	export MEEP_LIVE_BUILD=1
	export NODULAR_USER=casper
fi

# Nodular owns the X11 root window.  Remove the window managers that may have
# arrived with the Ubuntu desktop source before installing Nodular, otherwise
# the first session can still start one of them or leave it competing for the
# root window.  The package-name check covers the normal Ubuntu packages; the
# executable-owner check also catches a differently named package.
wm_packages=()
while IFS= read -r package; do
	case ${package} in
		muffin|muffin:*) wm_packages+=("${package}") ;;
		gnome-shell|gnome-shell:*) wm_packages+=("${package}") ;;
		metacity|metacity:*) wm_packages+=("${package}") ;;
		compiz|compiz:*) wm_packages+=("${package}") ;;
		kwin*|xfwm4|xfwm4:*) wm_packages+=("${package}") ;;
		openbox|openbox:*) wm_packages+=("${package}") ;;
		i3|i3:*) wm_packages+=("${package}") ;;
		sway|sway:*) wm_packages+=("${package}") ;;
		fluxbox|fluxbox:*) wm_packages+=("${package}") ;;
		awesome|awesome:*) wm_packages+=("${package}") ;;
		bspwm|bspwm:*) wm_packages+=("${package}") ;;
	esac
done < <(dpkg-query -W -f='${binary:Package}\t${db:Status-Status}\n' 2>/dev/null |
	awk -F '\t' '$2 == "installed" { print $1 }')

for wm_binary in muffin gnome-shell metacity compiz kwin_x11 kwin_wayland xfwm4 \
	openbox i3 sway fluxbox awesome bspwm; do
	wm_path="/usr/bin/${wm_binary}"
	[[ -x ${wm_path} ]] || continue
	while IFS= read -r owner; do
		[[ -n ${owner} ]] && wm_packages+=("${owner}")
	done < <(dpkg-query -S "${wm_path}" 2>/dev/null | cut -d: -f1 | sort -u)
done

if ((${#wm_packages[@]})); then
	mapfile -t wm_packages < <(printf '%s\n' "${wm_packages[@]}" | sort -u)
	echo "Removing Ubuntu window-manager packages: ${wm_packages[*]}"
	apt-get purge -y "${wm_packages[@]}"
	apt-get autoremove -y
else
	echo "No Ubuntu window-manager packages detected."
fi

# Removing the desktop can also remove LightDM and Xorg when the source image
# marked them as automatic dependencies.  Nodular still needs both: LightDM
# starts the X server and launches the Nodular session.
echo "Installing the LightDM/Xorg/background runtime for the Nodular session..."
apt-get install -y lightdm slick-greeter xserver-xorg feh
install -d -m 0755 /etc/X11
printf '%s\n' /usr/sbin/lightdm >/etc/X11/default-display-manager
if command -v systemctl >/dev/null 2>&1; then
	systemctl enable lightdm.service >/dev/null 2>&1 || true
fi

if [[ -r /var/lib/ubuntu-meep/electron-path ]]; then
	export NODULAR_ELECTRON="$(< /var/lib/ubuntu-meep/electron-path)"
fi
if [[ -z ${NODULAR_ELECTRON:-} ]]; then
	for candidate in "${NODULAR_SOURCE}/node_modules/electron/dist/electron" /usr/local/lib/node_modules/electron/dist/electron; do
		if [[ -x ${candidate} ]]; then NODULAR_ELECTRON=${candidate}; break; fi
	done
fi
[[ -x ${NODULAR_ELECTRON:-} ]] || { echo "No Electron executable found; complete the npm phase first." >&2; exit 1; }

install -d -m 0755 "${NODULAR_PREFIX}"
cp -a "${NODULAR_BUILD_DIR}/." "${NODULAR_PREFIX}/"
cp -a "${NODULAR_SOURCE}/package.json" "${NODULAR_SOURCE}/package-lock.json" "${NODULAR_PREFIX}/"
cp -a "${NODULAR_SOURCE}/node_modules" "${NODULAR_PREFIX}/"
install -d -m 0755 "${NODULAR_PREFIX}/src/templates" "${NODULAR_PREFIX}/src/assets"
cp -a "${NODULAR_SOURCE}/src/templates/." "${NODULAR_PREFIX}/src/templates/"
[[ -f ${NODULAR_SOURCE}/src/assets/bg.svg ]] && cp -a "${NODULAR_SOURCE}/src/assets/bg.svg" "${NODULAR_PREFIX}/src/assets/bg.svg"

install -d -m 0755 /usr/local/bin
cat >/usr/local/bin/nodular-session <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
runtime="$(mktemp -d "${XDG_RUNTIME_DIR:-/tmp}/nodular.XXXXXX")"
cleanup() { rm -rf -- "${runtime}"; }
trap cleanup EXIT
export NODULAR_RUNTIME_DIR="${runtime}"
exec /usr/bin/node /usr/local/lib/nodular/js/session.mjs "$@"
EOF
chmod 0755 /usr/local/bin/nodular-session

NODULAR_WM=/usr/local/bin/nodular-session

# Leave exactly one selectable session.  Nodular is X11-only, so retaining a
# Wayland session would allow a display manager to bypass the Nodular WM.
install -d -m 0755 /usr/share/xsessions /usr/share/wayland-sessions
cat >/usr/share/xsessions/nodular.desktop <<'EOF'
[Desktop Entry]
Name=Nodular
Comment=Meep's X11 desktop
Exec=/usr/local/bin/nodular-session
TryExec=/usr/local/bin/nodular-session
Type=Application
DesktopNames=Nodular
EOF
while IFS= read -r session_file; do
	case ${session_file} in
		/usr/share/xsessions/nodular.desktop) ;;
		*) rm -f -- "${session_file}" ;;
	esac
done < <(find /usr/share/xsessions -maxdepth 1 -type f -name '*.desktop' -print)
find /usr/share/wayland-sessions -maxdepth 1 -type f -name '*.desktop' -delete

# Force every display-manager path used by Ubuntu toward the same X11 session.
# LightDM is the normal Ubuntu Cinnamon path; the GDM settings and the X
# alternatives cover images that retain a different display manager.
install -d -m 0755 /etc/lightdm/lightdm.conf.d
cat >/etc/lightdm/lightdm.conf.d/60-nodular.conf <<'EOF'
[Seat:*]
user-session=nodular
autologin-session=nodular
EOF

if [[ -d /etc/gdm3 ]]; then
	cat >/etc/gdm3/custom.conf <<'EOF'
[daemon]
WaylandEnable=false
DefaultSession=nodular.desktop
EOF
fi

if command -v update-alternatives >/dev/null 2>&1; then
	update-alternatives --install /usr/bin/x-session-manager x-session-manager \
		"${NODULAR_WM}" 1000
	update-alternatives --set x-session-manager /usr/local/bin/nodular-session
fi

# Apply the session to the skeleton, every existing regular account, and the
# AccountsService records consulted by LightDM/GDM.  This also covers the
# live casper account after it is created from /etc/skel.
set_ini_value() {
	local file="$1" section="$2" key="$3" value="$4"
	local temporary
	temporary="$(mktemp "${file}.XXXXXX")"
	awk -v section="${section}" -v key="${key}" -v value="${value}" '
		BEGIN { in_section = 0; found_section = 0; found_key = 0 }
		/^\[/ {
			if (in_section && !found_key) print key "=" value
			in_section = ($0 == "[" section "]")
			if (in_section) found_section = 1
		}
		in_section && $0 ~ ("^" key "=") {
			if (!found_key) print key "=" value
			found_key = 1
			next
		}
		{ print }
		END {
			if (!found_section) print "\n[" section "]\n" key "=" value
			else if (in_section && !found_key) print key "=" value
		}
	' "${file}" 2>/dev/null >"${temporary}" || printf '[%s]\n%s=%s\n' "${section}" "${key}" "${value}" >"${temporary}"
	install -m 0644 "${temporary}" "${file}"
	rm -f -- "${temporary}"
}

set_ini_value /etc/skel/.dmrc Desktop Session nodular
install -d -m 0755 /var/lib/AccountsService/users
set_ini_value /var/lib/AccountsService/users/casper User XSession nodular

while IFS=: read -r username _ uid _ _ home _; do
	if ((uid >= 1000 && uid < 65534)) && [[ -d ${home} && ${username} != root ]]; then
		set_ini_value "${home}/.dmrc" Desktop Session nodular
		chown "${username}:$(id -gn "${username}")" "${home}/.dmrc"
		set_ini_value "/var/lib/AccountsService/users/${username}" User XSession nodular
		chown "${username}:$(id -gn "${username}")" "/var/lib/AccountsService/users/${username}"
	fi
done </etc/passwd

echo "Nodular is the only installed X11/Wayland session and window-manager default."
