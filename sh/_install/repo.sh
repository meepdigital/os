#!/bin/bash
# Ubuntu Meep provisioning module.

install_key() {
	local url="$1"
	local keyring_path="$2"
	[[ ! -s ${keyring_path} ]] || return 0
	local tmp_key
	local tmp_keyring

	tmp_key="$(mktemp)"
	tmp_keyring="$(mktemp)"
	curl -fsSL "${url}" -o "${tmp_key}"

	if gpg --batch --yes --dearmor -o "${tmp_keyring}" "${tmp_key}" 2>/dev/null; then
		install -m 0644 "${tmp_keyring}" "${keyring_path}"
	else
		install -m 0644 "${tmp_key}" "${keyring_path}"
	fi

	rm -f "${tmp_key}" "${tmp_keyring}"
}

target_codename=$(. /etc/os-release; printf '%s' "${VERSION_CODENAME}")
if [[ ${target_codename} == noble ]]; then
install_key \
	"https://keyserver.ubuntu.com/pks/lookup?op=get&search=0xB8DC7E53946656EFBCE4C1DD71DAEAAB4AD4CAB6" \
	/etc/apt/keyrings/ondrej-php.gpg
cat <<'EOF' >/etc/apt/sources.list.d/ondrej-ubuntu-php-noble.sources
Types: deb
URIs: https://ppa.launchpadcontent.net/ondrej/php/ubuntu/
Suites: noble
Components: main
Signed-By: /etc/apt/keyrings/ondrej-php.gpg
EOF
else
    # Never mix Noble PHP packages into another Ubuntu release.
    rm -f /etc/apt/sources.list.d/ondrej-ubuntu-php-noble.sources
fi

install_key \
	https://acli.atlassian.com/gpg/public-key.asc \
	/etc/apt/keyrings/acli-archive-keyring.gpg
cat <<'EOF' >/etc/apt/sources.list.d/acli.list
deb [arch=amd64 signed-by=/etc/apt/keyrings/acli-archive-keyring.gpg] https://acli.atlassian.com/linux/deb stable main
EOF

install_key \
	https://dl.google.com/linux/linux_signing_key.pub \
	/usr/share/keyrings/google-chrome.gpg
cat <<'EOF' >/etc/apt/sources.list.d/google-chrome.list
deb [arch=amd64 signed-by=/usr/share/keyrings/google-chrome.gpg] https://dl.google.com/linux/chrome/deb/ stable main
EOF

apt-get update
