#!/bin/bash

# Plymouth is handled redundantly because Cubic can preserve duplicate theme
# trees and an initramfs copied before this script runs.
replace_text_in_paths() {
	local old_text="$1" new_text="$2" path file
	shift 2
	for path in "$@"; do
		[[ -e "${path}" ]] || continue
		while IFS= read -r -d '' file; do
			sed -i "s/${old_text}/${new_text}/g" "${file}"
		done < <(rg -l -0 --fixed-strings --text "${old_text}" "${path}" 2>/dev/null || true)
	done
}

echo "Updating GRUB branding..."
replace_text_in_paths "Ubuntu Cinnamon" "Ubuntu Meep" \
	/etc/default/grub /etc/grub.d /boot/grub /boot/efi/EFI
echo "Updating installed Ubuntu Cinnamon branding..."
replace_text_in_paths "Ubuntu Cinnamon" "Ubuntu Meep" \
	/etc /usr/lib /usr/share /var/lib

BOOT_ASSETS_DIR="${SCRIPT_DIR}/assets/boot"
[[ -d "${BOOT_ASSETS_DIR}" ]] || { echo "Missing ${BOOT_ASSETS_DIR}" >&2; exit 1; }
shopt -s nullglob
PLYMOUTH_ASSETS=("${BOOT_ASSETS_DIR}"/*.png "${BOOT_ASSETS_DIR}"/*.svg)
((${#PLYMOUTH_ASSETS[@]})) || { echo "No Plymouth graphics found" >&2; exit 1; }
PLYMOUTH_ASSET_NAMES=()
for asset in "${PLYMOUTH_ASSETS[@]}"; do
	PLYMOUTH_ASSET_NAMES+=("$(basename "${asset}")")
done

install_assets_into() {
	local theme_dir="$1" asset
	install -d -m 0755 "${theme_dir}"
	for asset in "${PLYMOUTH_ASSETS[@]}"; do
		install -m 0644 -T "${asset}" "${theme_dir}/$(basename "${asset}")"
	done
}

# Cover every standard root, the alternatives link, Plymouth's resolver, every
# descriptor, and every directory already containing one of our asset names.
# The last part catches package layouts with loose graphics but no descriptor
# in the same tree.
PLYMOUTH_ROOTS=(/usr/share/plymouth/themes /usr/lib/plymouth/themes /lib/plymouth/themes)
THEME_DIRS=()
DEFAULT_PLYMOUTH_FILE="$(readlink -f /etc/alternatives/default.plymouth 2>/dev/null || true)"
[[ -f "${DEFAULT_PLYMOUTH_FILE}" ]] && THEME_DIRS+=("$(dirname "${DEFAULT_PLYMOUTH_FILE}")")
if command -v plymouth-set-default-theme >/dev/null 2>&1; then
	CURRENT_THEME="$(plymouth-set-default-theme 2>/dev/null || true)"
	for root in "${PLYMOUTH_ROOTS[@]}"; do
		[[ -n "${CURRENT_THEME}" && -d "${root}/${CURRENT_THEME}" ]] && THEME_DIRS+=("${root}/${CURRENT_THEME}")
	done
fi
for root in "${PLYMOUTH_ROOTS[@]}"; do
	[[ -d "${root}" ]] || continue
	while IFS= read -r -d '' descriptor; do
		THEME_DIRS+=("$(dirname "${descriptor}")")
	done < <(find "${root}" -mindepth 2 -maxdepth 3 -type f -name '*.plymouth' -print0 2>/dev/null)
done
for root in /usr/share/plymouth /usr/lib/plymouth /lib/plymouth; do
	[[ -d "${root}" ]] || continue
	for asset_name in "${PLYMOUTH_ASSET_NAMES[@]}"; do
		while IFS= read -r -d '' old_asset; do
			THEME_DIRS+=("$(dirname "${old_asset}")")
		done < <(find "${root}" -type f -name "${asset_name}" -print0 2>/dev/null)
	done
done

UNIQUE_THEME_DIRS=()
for theme_dir in "${THEME_DIRS[@]}"; do
	[[ -d "${theme_dir}" ]] || continue
	duplicate=0
	for existing in "${UNIQUE_THEME_DIRS[@]}"; do
		[[ "${existing}" == "${theme_dir}" ]] && duplicate=1 && break
	done
	((duplicate)) || UNIQUE_THEME_DIRS+=("${theme_dir}")
done
if ((${#UNIQUE_THEME_DIRS[@]} == 0)); then
	echo "No Plymouth theme directories found; cannot install Ubuntu Meep graphics." >&2
	exit 1
fi
echo "Overwriting Plymouth graphics in ${#UNIQUE_THEME_DIRS[@]} theme director(ies)..."
for theme_dir in "${UNIQUE_THEME_DIRS[@]}"; do
	install_assets_into "${theme_dir}"
done

# Replace loose same-named copies left by old Ubuntu Cinnamon packages.
for root in /usr/share/plymouth /usr/lib/plymouth /lib/plymouth; do
	[[ -d "${root}" ]] || continue
	for asset_name in "${PLYMOUTH_ASSET_NAMES[@]}"; do
		while IFS= read -r -d '' stale_copy; do
			install -m 0644 -T "${BOOT_ASSETS_DIR}/${asset_name}" "${stale_copy}"
		done < <(find "${root}" -type f -name "${asset_name}" -print0 2>/dev/null)
	done
done

# Create and select a package-independent theme so alternatives cannot return
# to ubuntucinnamon-spinner later in the build.
MEEP_THEME_DIR=/usr/share/plymouth/themes/ubuntu-meep
SOURCE_THEME_DIR="${UNIQUE_THEME_DIRS[0]}"
install -d -m 0755 "${MEEP_THEME_DIR}"
if [[ "${SOURCE_THEME_DIR}" != "${MEEP_THEME_DIR}" ]]; then
	cp -a "${SOURCE_THEME_DIR}/." "${MEEP_THEME_DIR}/"
fi
install_assets_into "${MEEP_THEME_DIR}"
MEEP_DESCRIPTOR="${MEEP_THEME_DIR}/ubuntu-meep.plymouth"
SOURCE_DESCRIPTOR="$(find "${MEEP_THEME_DIR}" -maxdepth 1 -type f -name '*.plymouth' ! -name 'ubuntu-meep.plymouth' -print -quit)"
if [[ -n "${SOURCE_DESCRIPTOR}" ]]; then
	cp -f "${SOURCE_DESCRIPTOR}" "${MEEP_DESCRIPTOR}"
	sed -i 's/^Name=.*/Name=Ubuntu Meep/; s#^ImageDir=.*#ImageDir=/usr/share/plymouth/themes/ubuntu-meep#' "${MEEP_DESCRIPTOR}"
fi
[[ -f "${MEEP_DESCRIPTOR}" ]] || { echo "Could not create ${MEEP_DESCRIPTOR}" >&2; exit 1; }

if command -v plymouth-set-default-theme >/dev/null 2>&1; then
	echo "Selecting Ubuntu Meep Plymouth theme..."
	plymouth-set-default-theme ubuntu-meep
	plymouth-set-default-theme -R ubuntu-meep
else
	ln -sfn "${MEEP_DESCRIPTOR}" /etc/alternatives/default.plymouth
fi

command -v update-grub >/dev/null 2>&1 && { echo "Regenerating GRUB configuration..."; update-grub; }
command -v update-initramfs >/dev/null 2>&1 || { echo "update-initramfs is required" >&2; exit 1; }
echo "Rebuilding all initramfs images with Ubuntu Meep graphics..."
update-initramfs -u -k all

# Verify the installed source and every generated initramfs. This turns
# Cubic's silent partial-success case into a hard failure.
EXPECTED_HASH="$(sha256sum "${BOOT_ASSETS_DIR}/throbber.svg" | awk '{print $1}')"
ACTUAL_HASH="$(sha256sum "${MEEP_THEME_DIR}/throbber.svg" | awk '{print $1}')"
[[ "${EXPECTED_HASH}" == "${ACTUAL_HASH}" ]] || { echo "Plymouth source verification failed" >&2; exit 1; }
INITRAMFS_FOUND=0
for initramfs in /boot/initrd.img-*; do
	[[ -f "${initramfs}" ]] || continue
	INITRAMFS_FOUND=1
	if ! command -v lsinitramfs >/dev/null 2>&1 || ! lsinitramfs "${initramfs}" | grep -Eq '(^|/)ubuntu-meep\.plymouth$'; then
		echo "Ubuntu Meep theme is missing from ${initramfs}" >&2
		exit 1
	fi
done
((INITRAMFS_FOUND)) || echo "Warning: no /boot/initrd.img-* files were available to verify."
echo "Ubuntu Meep Plymouth graphics installed, selected, embedded, and verified."
