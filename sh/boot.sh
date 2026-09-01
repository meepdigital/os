#!/bin/bash

# Keep the installed desktop branding separate from the GRUB branding. GRUB
# gets its own name so its boot menu can be identified independently.
replace_text_in_paths() {
	local old_text="$1"
	local new_text="$2"
	shift 2
	local path
	local file

	for path in "$@"; do
		[[ -e "${path}" ]] || continue

		while IFS= read -r -d '' file; do
			sed -i "s/${old_text}/${new_text}/g" "${file}"
		done < <(rg -l -0 --fixed-strings --text "${old_text}" "${path}" 2>/dev/null || true)
	done
}

echo "Updating GRUB branding..."
replace_text_in_paths \
	"Ubuntu Cinnamon" \
	"Ubuntu Tayp" \
	/etc/default/grub \
	/etc/grub.d \
	/boot/grub \
	/boot/efi/EFI

echo "Updating installed Ubuntu Cinnamon branding..."
replace_text_in_paths \
	"Ubuntu Cinnamon" \
	"Ubuntu Meep" \
	/etc \
	/usr/lib \
	/usr/share \
	/var/lib

BOOT_ASSETS_DIR="${SCRIPT_DIR}/assets/boot"
PLYMOUTH_THEMES_DIR=/usr/share/plymouth/themes
DEFAULT_PLYMOUTH_FILE="$(readlink -f /etc/alternatives/default.plymouth 2>/dev/null || true)"
PLYMOUTH_THEME_DIR="$(dirname "${DEFAULT_PLYMOUTH_FILE}")"

if [[ ! -d "${PLYMOUTH_THEME_DIR}" || "${PLYMOUTH_THEME_DIR}" == "." ]]; then
	PLYMOUTH_THEME_DIR="${PLYMOUTH_THEMES_DIR}/ubuntucinnamon-spinner"
fi

if [[ ! -d "${BOOT_ASSETS_DIR}" ]]; then
	echo "Missing Plymouth assets directory: ${BOOT_ASSETS_DIR}" >&2
	exit 1
fi

shopt -s nullglob
PLYMOUTH_ASSETS=("${BOOT_ASSETS_DIR}"/*.png "${BOOT_ASSETS_DIR}"/*.svg)
if ((${#PLYMOUTH_ASSETS[@]} == 0)); then
	echo "No Plymouth graphics found in ${BOOT_ASSETS_DIR}" >&2
	exit 1
fi

install -d -m 0755 "${PLYMOUTH_THEME_DIR}"
echo "Installing Plymouth graphics into ${PLYMOUTH_THEME_DIR}..."
for asset in "${PLYMOUTH_ASSETS[@]}"; do
	install -m 0644 "${asset}" "${PLYMOUTH_THEME_DIR}/$(basename "${asset}")"
done

if command -v update-grub >/dev/null 2>&1; then
	echo "Regenerating GRUB configuration..."
	update-grub
fi

if command -v update-initramfs >/dev/null 2>&1; then
	echo "Rebuilding initramfs with the Plymouth graphics..."
	update-initramfs -u -k all
fi
