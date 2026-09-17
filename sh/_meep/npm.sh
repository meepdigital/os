#!/bin/bash

set -euo pipefail

if [[ ${MEEP_MINIMAL:-0} == 1 ]]; then
	# boot.sh copies this locally installed Electron runtime into the live
	# system.  Keep only the installer dependency/build step in minimal mode;
	# the global developer CLI bundle is optional.
	echo "Building the Meep installer runtime in minimal mode."
	cd "${SCRIPT_DIR}/installer"
	npm install
	npm run build
	npm run desktop
	return 0 2>/dev/null || exit 0
fi

# GNU tar can report "Directory renamed before its status could be extracted"
# when it extracts directly into the persistent live system's OverlayFS. Keep
# n's download/extraction cache on the chroot-visible tmpfs, then let n copy
# the completed tree into the durable /usr/local prefix.
N_CACHE_PREFIX=/dev/shm/os-n-cache
export N_CACHE_PREFIX

# A failed extraction leaves n.lock behind. Remove only those incomplete n
# version directories before retrying; unlocked versions are retained.
if [[ -d /usr/local/n/versions ]]; then
	while IFS= read -r lock_file; do
		version_dir="${lock_file%/n.lock}"
		echo "Removing incomplete Node.js download: ${version_dir}"
		rm -rf -- "${version_dir}"
	done < <(find /usr/local/n/versions -mindepth 3 -maxdepth 3 -type f -name n.lock -print)
fi

rm -rf -- "${N_CACHE_PREFIX}"
mkdir -p "${N_CACHE_PREFIX}"

npm install -g n && N_PREFIX=/usr/local n latest
rm -rf -- "${N_CACHE_PREFIX}"
npm install -g npm@latest
npm install -g \
	@github/copilot \
	@githubnext/github-copilot-cli \
	@google/gemini-cli \
	@openai/codex \
	electron \
	heroku \
	nodemon \
	yo

cd "${SCRIPT_DIR}/installer"
npm install
npm run build
npm run desktop
