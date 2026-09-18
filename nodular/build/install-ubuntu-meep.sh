#!/usr/bin/env bash
set -euo pipefail

if [[ ${EUID} -ne 0 ]]; then
  echo "Run this installer as root, for example: sudo $0" >&2
  exit 1
fi

BUILD_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
PREFIX=/usr/local/lib/nodular
ELECTRON_BIN="${NODULAR_ELECTRON:-}"

if [[ -z ${ELECTRON_BIN} ]]; then
  # Meep's minimal build installs Electron locally for the installer. Prefer
  # that runtime so Nodular does not depend on an optional global npm bundle.
  for candidate in \
    "${BUILD_DIR}/../../installer/node_modules/electron/dist/electron" \
    "/usr/local/lib/node_modules/electron/dist/electron"; do
    if [[ -x ${candidate} ]]; then
      ELECTRON_BIN=${candidate}
      break
    fi
  done
fi

[[ -x ${BUILD_DIR}/nodular-wm ]] || { echo "Missing Nodular build: ${BUILD_DIR}/nodular-wm" >&2; exit 1; }
[[ -f ${BUILD_DIR}/shell/main.mjs ]] || { echo "Missing Nodular shell build" >&2; exit 1; }
[[ -x ${ELECTRON_BIN} ]] || {
  echo "Missing Electron runtime: ${ELECTRON_BIN}" >&2
  echo "Set NODULAR_ELECTRON to an installed Chromium/Electron executable." >&2
  exit 1
}

target_user="${NODULAR_USER:-${SUDO_USER:-}}"
if [[ -z ${target_user} || ${target_user} == root ]]; then
  if getent passwd casper >/dev/null; then
    target_user=casper
  else
    # The live source image may use ubuntu, not casper. Select the first
    # regular account with a home directory when no user was specified.
    target_user="$(getent passwd | awk -F: '$3 >= 1000 && $3 < 65534 && $6 ~ /^\/home\// { print $1; exit }')"
  fi
fi

user_record="$(getent passwd "${target_user}" || true)"
target_home=""
target_owner=""
target_group=""
if [[ -n ${user_record} ]]; then
  target_home="$(printf '%s' "${user_record}" | cut -d: -f6)"
  target_owner="${target_user}"
  target_group="$(id -gn "${target_user}")"
elif [[ ${target_user} == casper && ${MEEP_LIVE_BUILD:-0} == 1 ]]; then
  # Ubuntu's live layers do not contain the casper account. casper is created
  # by casper at boot, so configure the skeleton and AccountsService entries
  # now and apply the per-user file after the live account exists.
  target_home=/etc/skel
  target_owner=root
  target_group=root
else
  echo "No regular login user found; set NODULAR_USER explicitly." >&2
  exit 1
fi

install -d -m 0755 "${PREFIX}" /usr/local/bin /usr/share/xsessions
cp -a "${BUILD_DIR}/." "${PREFIX}/"
install -d -m 0755 "${PREFIX}/electron-dist"
cp -a "$(dirname -- "${ELECTRON_BIN}")/." "${PREFIX}/electron-dist/"
chmod 0755 "${PREFIX}/electron-dist/electron"

cat >/usr/local/bin/nodular-session <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
exec /usr/bin/node /usr/local/lib/nodular/start.mjs "$@"
EOF
chmod 0755 /usr/local/bin/nodular-session
install -m 0644 "${BUILD_DIR}/nodular.desktop" /usr/share/xsessions/nodular.desktop

update_ini_value() {
  local file="$1" section="$2" key="$3" value="$4"
  local temporary backup
  temporary="$(mktemp "${file}.XXXXXX")"
  if [[ -f ${file} ]]; then
    backup="${file}.nodular-backup"
    [[ -e ${backup} ]] || cp -a "${file}" "${backup}"
  fi
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
  ' "${file}" >"${temporary}" 2>/dev/null || printf '[%s]\n%s=%s\n' "${section}" "${key}" "${value}" >"${temporary}"
  if [[ ! -s ${temporary} ]]; then
    printf '[%s]\n%s=%s\n' "${section}" "${key}" "${value}" >"${temporary}"
  fi
  install -o "${target_owner}" -g "${target_group}" -m 0644 "${temporary}" "${file}"
  rm -f -- "${temporary}"
}

update_ini_value "${target_home}/.dmrc" Desktop Session nodular
install -d -m 0755 /var/lib/AccountsService/users
update_ini_value "/var/lib/AccountsService/users/${target_user}" User XSession nodular

echo "Installed Nodular to ${PREFIX}."
echo "Registered Nodular as an X11 session."
echo "Set Nodular as the default session for ${target_user}."
echo "A previous .dmrc or AccountsService file was backed up with .nodular-backup when applicable."
