#!/bin/bash
# Ubuntu Meep provisioning module.

# Also allow this module to be invoked directly.
if ! declare -F meep_once >/dev/null; then
	. "$(dirname -- "${BASH_SOURCE[0]}")/cache.sh"
fi

set -euo pipefail

# Keep the extraction workaround isolated to the Node install. Successful
# installs are checkpointed before moving on to the next global package.
install_meep_node() {
	local lock_file version_dir
	export N_CACHE_PREFIX=/dev/shm/os-n-cache
	if [[ -d /usr/local/n/versions ]]; then
		while IFS= read -r lock_file; do
			version_dir="${lock_file%/n.lock}"
			rm -rf -- "${version_dir}"
		done < <(find /usr/local/n/versions -mindepth 3 -maxdepth 3 -type f -name n.lock -print)
	fi
	rm -rf -- "${N_CACHE_PREFIX}"
	mkdir -p "${N_CACHE_PREFIX}"
	npm install -g n
	N_PREFIX=/usr/local n latest
	rm -rf -- "${N_CACHE_PREFIX}"
	# Prefer the newly installed runtime during this same shell session.
	export PATH="/usr/local/bin:${PATH}"
	hash -r
}

meep_once node-runtime install_meep_node
export PATH="/usr/local/bin:${PATH}"
hash -r
meep_once npm-runtime npm install -g npm@latest

# Electron is the first global npm application and its native binary is a hard
# prerequisite for every graphical Meep component. Resolve npm's actual global
# module root instead of assuming a package-manager-specific path.
if ! npm list -g --depth=0 electron >/dev/null 2>&1; then
	npm install -g electron
fi
ELECTRON_ROOT="$(npm root -g)/electron"
ELECTRON_BIN="${ELECTRON_ROOT}/dist/electron"
if [[ ! -x ${ELECTRON_BIN} ]]; then
	"$(npm root -g)/electron/install.js"
fi
[[ -x ${ELECTRON_BIN} ]] || { echo "Electron installation did not produce a native binary." >&2; exit 1; }
export NODULAR_ELECTRON="${ELECTRON_BIN}"
printf '%s\n' "${NODULAR_ELECTRON}" >/var/lib/ubuntu-meep/electron-path

for npm_package in \
	@github/copilot \
	@githubnext/github-copilot-cli \
	@google/gemini-cli \
	@openai/codex \
	heroku \
	nodemon \
	yo; do
	# Query each package independently: another missing/broken global package
	# must not cause every successful installation to run again.
	if npm list -g --depth=0 "${npm_package}" >/dev/null 2>&1; then
		echo "Already installed: ${npm_package}; skipping."
	else
		npm install -g "${npm_package}"
	fi
done
