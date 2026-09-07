#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
OS_SRC="${SCRIPT_DIR}"
DEB_SRC="${SCRIPT_DIR}/deb"
WORK_ROOT="${SCRIPT_DIR}/tmp"
WORK="${WORK_ROOT}/ubuntu-cinnamon-usb-build"
DOWNLOAD_PAGE_URL="https://ubuntucinnamon.org/download/"
ENTRYPOINT_NAME="$(basename "$0")"
ISO=""
CUSTOM_ISO=""
DEVICE=""
ISO_PART=""
PERSIST_PART=""
MODE="create"
CHROOT_INSTALL_SUCCEEDED=0

usage() {
  cat <<EOF
Usage: sudo bash ./${ENTRYPOINT_NAME} [--device /dev/sdX] [--resume]
       sudo bash ./${ENTRYPOINT_NAME} /dev/sdX [--resume]

Default mode prompts for a target device, erases and recreates it, then runs the OS installer in the
persistent overlay chroot. Use --resume to skip the ISO write/partitioning and
rerun only the overlay chroot work against an existing persistent USB.
EOF
}

while (($#)); do
  case "$1" in
    --resume)
      MODE="resume"
      WORK="${WORK_ROOT}/ubuntu-cinnamon-usb-resume"
      ;;
    --device)
      shift
      if [[ $# -eq 0 || -z "${1:-}" ]]; then
        echo "--device requires a block device path, for example /dev/sdd" >&2
        exit 1
      fi
      DEVICE="$1"
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    /dev/*)
      if [[ -n "${DEVICE}" ]]; then
        echo "Device was already set to ${DEVICE}; got another device argument: $1" >&2
        exit 1
      fi
      DEVICE="$1"
      ;;
    *)
      echo "Unknown argument: $1" >&2
      usage >&2
      exit 1
      ;;
  esac
  shift
done

if [[ "${EUID}" -ne 0 ]]; then
  echo "Run as root: sudo bash ./${ENTRYPOINT_NAME} [--device /dev/sdX] [--resume]" >&2
  exit 1
fi

cleanup_mounts=()
cleanup_loops=()

prompt_for_device() {
  local entered_device

  if [[ -n "${DEVICE}" ]]; then
    return 0
  fi

  echo "Available block devices:"
  lsblk -d -o NAME,PATH,SIZE,MODEL,TRAN,TYPE
  echo
  read -r -p "Device to erase and use for persistence, for example /dev/sdd: " entered_device
  DEVICE="${entered_device}"
}

partition_path() {
  local number="$1"

  case "${DEVICE}" in
    *[0-9])
      printf '%sp%s' "${DEVICE}" "${number}"
      ;;
    *)
      printf '%s%s' "${DEVICE}" "${number}"
      ;;
  esac
}

set_device_partitions() {
  ISO_PART="$(partition_path 1)"
  PERSIST_PART="$(partition_path 4)"
}

verify_required_paths() {
  local required_paths=("${OS_SRC}/os.sh")
  local path

  if [[ "${MODE}" == "resume" ]]; then
    required_paths+=("${ISO_PART}" "${PERSIST_PART}")
  fi

  for path in "${required_paths[@]}"; do
    if [[ ! -e "${path}" ]]; then
      echo "Missing required path: ${path}" >&2
      exit 1
    fi
  done
}

verify_device() {
  local device_size_bytes

  if [[ ! "${DEVICE}" =~ ^/dev/ ]]; then
    echo "Device must be an absolute /dev path, for example /dev/sdd" >&2
    exit 1
  fi

  if [[ ! -b "${DEVICE}" ]]; then
    echo "USB disk ${DEVICE} is not present. Check lsblk before continuing." >&2
    exit 1
  fi

  device_size_bytes="$(blockdev --getsize64 "${DEVICE}" 2>/dev/null || printf '0')"
  if [[ "${device_size_bytes}" -le 0 ]]; then
    echo "USB disk ${DEVICE} reports 0 bytes. Insert the USB media and check lsblk before continuing." >&2
    exit 1
  fi
}

resolve_latest_iso() {
  local download_page
  local release_url
  local release_page
  local iso_name
  local iso_url
  local sums_url

  echo "Resolving the latest Ubuntu Cinnamon ISO..."
  download_page="$(curl -fsSL "${DOWNLOAD_PAGE_URL}")"
  release_url="$(
    printf '%s' "${download_page}" |
      grep -Eom 1 'https://cdimage\.ubuntu\.com/ubuntucinnamon/releases/[^"]+/release/?' ||
      true
  )"

  if [[ -z "${release_url}" ]]; then
    echo "Could not find an Ubuntu Cinnamon release URL on ${DOWNLOAD_PAGE_URL}" >&2
    exit 1
  fi

  release_page="$(curl -fsSL "${release_url}")"
  iso_name="$(
    printf '%s' "${release_page}" |
      grep -Eom 1 'ubuntucinnamon-[0-9]+\.[0-9]+(\.[0-9]+)?-desktop-amd64\.iso' ||
      true
  )"

  if [[ -z "${iso_name}" ]]; then
    echo "Could not find a desktop AMD64 ISO on ${release_url}" >&2
    exit 1
  fi

  iso_url="${release_url%/}/${iso_name}"
  sums_url="${release_url%/}/SHA256SUMS"
  ISO="${SCRIPT_DIR}/${iso_name}"
  CUSTOM_ISO="${SCRIPT_DIR}/${iso_name%.iso}-persistent.iso"

  # Download into the repo directory so later runs are repeatable and do not
  # depend on a host-specific cache location. Existing ISOs are still checked;
  # a previous failed verification must never become a trusted artifact.
  if [[ -f "${ISO}" ]]; then
    echo "Using existing ISO: ${ISO}"
  else
    echo "Downloading ${iso_url}"
    curl -fL --progress-bar "${iso_url}" -o "${ISO}.part"
    mv "${ISO}.part" "${ISO}"
  fi

  echo "Verifying ${iso_name} against SHA256SUMS..."
  curl -fsSL "${sums_url}" -o "${WORK}/SHA256SUMS"
  expected_checksum="$(
    awk -v target="${iso_name}" '
      {
        sub(/\r$/, "")
        filename=$2
        sub(/^\*/, "", filename)
        if (filename == target && $1 ~ /^[[:xdigit:]]{64}$/) {
          print $1
          exit
        }
      }
    ' "${WORK}/SHA256SUMS"
  )"
  if [[ -z "${expected_checksum}" ]]; then
    echo "No valid SHA-256 record found for ${iso_name} in ${WORK}/SHA256SUMS" >&2
    exit 1
  fi
  printf '%s  %s\n' "${expected_checksum}" "${ISO}" | sha256sum -c -
}

cleanup_existing_tree() {
  local base="$1"
  local target
  local loopdev

  [[ -d "${base}" ]] || return 0

  while read -r target; do
    [[ -n "${target}" ]] || continue
    [[ "${target}" == "${base}/iso" ]] && continue
    umount "${target}" 2>/dev/null || umount -l "${target}" 2>/dev/null || true
  done < <(findmnt -Rnr -o TARGET "${base}" 2>/dev/null | awk '{ print length, $0 }' | sort -rn | cut -d' ' -f2-)

  while read -r loopdev; do
    [[ -n "${loopdev}" ]] || continue
    losetup -d "${loopdev}" >/dev/null 2>&1 || true
  done < <(losetup -a | awk -v base="${base}" 'index($0, base) { sub(/:.*/, "", $1); print $1 }')

  if mountpoint -q "${base}/iso"; then
    umount "${base}/iso" 2>/dev/null || umount -l "${base}/iso" 2>/dev/null || true
  fi
}

cleanup() {
  set +e
  if mountpoint -q "${WORK}/root"; then umount -R "${WORK}/root"; fi
  for ((i=${#cleanup_mounts[@]}-1; i>=0; i--)); do
    mnt="${cleanup_mounts[$i]}"
    if [[ "${mnt}" == "${WORK}/iso" ]]; then continue; fi
    if mountpoint -q "${mnt}"; then umount "${mnt}"; fi
  done
  for loopdev in "${cleanup_loops[@]:-}"; do
    losetup -d "${loopdev}" >/dev/null 2>&1 || true
  done
  if mountpoint -q "${WORK}/iso"; then umount "${WORK}/iso"; fi
}
trap cleanup EXIT

cleanup_existing_tree "${WORK_ROOT}/ubuntu-cinnamon-usb-build"
cleanup_existing_tree "${WORK_ROOT}/ubuntu-cinnamon-usb-resume"

remaster_iso() {
  echo "Preparing remastered ISO with Ubuntu Meep dual boot modes..."
  rm -f "${CUSTOM_ISO}"
  xorriso -osirrox on -indev "${ISO}" -extract /boot/grub/grub.cfg "${WORK}/grub.cfg.orig" >/dev/null 2>&1
  sed \
    -e 's#linux  /casper/vmlinuz  --- quiet splash#linux  /casper/vmlinuz persistent --- quiet splash#' \
    -e 's#linux  /casper/vmlinuz nomodeset  --- quiet splash#linux  /casper/vmlinuz nomodeset persistent --- quiet splash#' \
    -e 's/Ubuntu Cinnamon/Ubuntu Meep/g' \
    "${WORK}/grub.cfg.orig" >"${WORK}/grub.cfg"

  # Keep the normal persistent live mode first so it remains the safe default.
  # The second mode copies casper's read-only system image into RAM. Both modes
  # still boot the graphical installer; toram changes where the live OS reads
  # from, not where a user may install the final system.
  awk '
    /menuentry "Try or Install Ubuntu Meep"/ && !inserted {
      print "menuentry \"Ubuntu Meep - Persistent Live\" {"
      in_entry = 1
      next
    }
    in_entry && /^}/ {
      print
      print "menuentry \"Ubuntu Meep - Fast RAM Live\" {"
      print "    set gfxpayload=keep"
      print "    linux  /casper/vmlinuz persistent toram --- quiet splash"
      print "    initrd /casper/initrd"
      print "}"
      inserted = 1
      in_entry = 0
      next
    }
    { print }
  ' "${WORK}/grub.cfg" >"${WORK}/grub.cfg.modes"
  mv "${WORK}/grub.cfg.modes" "${WORK}/grub.cfg"
  xorriso -indev "${ISO}" -outdev "${CUSTOM_ISO}" -boot_image any replay -map "${WORK}/grub.cfg" /boot/grub/grub.cfg
}

unmount_device_partitions() {
  local partition_path

  echo "Unmounting existing ${DEVICE} partitions..."
  while read -r partition_path; do
    [[ -n "${partition_path}" ]] || continue
    if findmnt -rn -S "${partition_path}" >/dev/null; then
      umount "${partition_path}"
    fi
  done < <(lsblk -nrpo PATH "${DEVICE}" | tail -n +2 | tac)
}

write_usb() {
  echo "Writing ISO to ${DEVICE}..."
  dd if="${CUSTOM_ISO}" of="${DEVICE}" bs=4M status=progress conv=fsync
  sync
  partprobe "${DEVICE}" || true
  udevadm settle

  echo "Creating full-size persistence partition labeled writable..."
  sgdisk -e "${DEVICE}"
  sgdisk -n 4:0:0 -t 4:8300 -c 4:writable "${DEVICE}"
  partprobe "${DEVICE}" || true
  udevadm settle
  mkfs.ext4 -F -L writable "${PERSIST_PART}"
}

mount_overlay() {
  local lowerdirs=""
  local idx=0
  local image
  local name
  local loopdev
  local layer

  mkdir -p "${WORK}/iso" "${WORK}/persist" "${WORK}/root" "${WORK}/layers"
  mount -o ro "${ISO_PART}" "${WORK}/iso"
  cleanup_mounts+=("${WORK}/iso")
  mount "${PERSIST_PART}" "${WORK}/persist"
  cleanup_mounts+=("${WORK}/persist")
  mkdir -p "${WORK}/persist/upper" "${WORK}/persist/work"

  echo "Mounting live filesystem overlay..."
  shopt -s nullglob
  for image in "${WORK}/iso"/casper/*.squashfs; do
    name="$(basename "${image}")"
    case "${name}" in
      ltsp.squashfs|server.squashfs) continue ;;
    esac
    idx=$((idx + 1))
    loopdev="$(losetup --find --show --read-only "${image}")"
    cleanup_loops+=("${loopdev}")
    layer="${WORK}/layers/${idx}-${name}"
    mkdir -p "${layer}"
    mount -t squashfs -o ro "${loopdev}" "${layer}"
    cleanup_mounts+=("${layer}")
    if [[ -z "${lowerdirs}" ]]; then
      lowerdirs="${layer}"
    else
      lowerdirs="${layer}:${lowerdirs}"
    fi
  done
  shopt -u nullglob

  if [[ -z "${lowerdirs}" ]]; then
    echo "No squashfs layers found on ${ISO_PART}; aborting." >&2
    exit 1
  fi

  mount -t overlay overlay \
    -o "upperdir=${WORK}/persist/upper,lowerdir=${lowerdirs},workdir=${WORK}/persist/work" \
    "${WORK}/root"
}

copy_os_source() {
  echo "Copying this repo into the persistent live user's home..."
  install -d -m 0755 "${WORK}/root/home/casper"
  # The build worktree and ISO artifacts live beside the scripts, but they must
  # not be copied into the persistent overlay or rsync can recurse into mounts.
  rsync -a --delete \
    --exclude '/tmp/' \
    --exclude '/*.iso' \
    --exclude '/*.iso.part' \
    "${OS_SRC}/" "${WORK}/root/home/casper/os/"
}

patch_os_installer_for_target() {
  local target_codename

  target_codename="$(
    . "${WORK}/root/etc/os-release"
    printf '%s' "${VERSION_CODENAME:-}"
  )"

  if [[ "${target_codename}" == "noble" ]]; then
    return 0
  fi

  echo "Target is Ubuntu ${target_codename}; patching copied os installer to avoid Noble-only PHP packages."
  rm -f \
    "${WORK}/root/etc/apt/sources.list.d/ondrej-"* \
    "${WORK}/root/etc/apt/sources.list.d/"*ondrej* \
    "${WORK}/root/etc/apt/keyrings/ondrej-"* \
    "${WORK}/root/etc/apt/keyrings/"*ondrej*

  cat >"${WORK}/root/home/casper/os/sh/repo.sh" <<'OS_REPO_NON_NOBLE'
#!/bin/bash

install_key() {
	local url="$1"
	local keyring_path="$2"
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

install_key \
	https://acli.atlassian.com/gpg/public-key.asc \
	/etc/apt/keyrings/acli-archive-keyring.gpg
cat <<'EOF' >/etc/apt/sources.list.d/acli.list
deb [arch=amd64 signed-by=/etc/apt/keyrings/acli-archive-keyring.gpg] https://acli.atlassian.com/linux/deb stable main
EOF

install_key \
	https://download.sublimetext.com/sublimehq-pub.gpg \
	/usr/share/keyrings/sublimehq-archive-keyring.gpg
cat <<'EOF' >/etc/apt/sources.list.d/sublime-text.list
deb [signed-by=/usr/share/keyrings/sublimehq-archive-keyring.gpg] https://download.sublimetext.com/ apt/stable/
EOF

install_key \
	https://dl.google.com/linux/linux_signing_key.pub \
	/usr/share/keyrings/google-chrome.gpg
cat <<'EOF' >/etc/apt/sources.list.d/google-chrome.list
deb [arch=amd64 signed-by=/usr/share/keyrings/google-chrome.gpg] https://dl.google.com/linux/chrome/deb/ stable main
EOF

install_key \
	https://cli.github.com/packages/githubcli-archive-keyring.gpg \
	/etc/apt/keyrings/githubcli-archive-keyring.gpg
cat <<EOF >/etc/apt/sources.list.d/github-cli.list
deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main
EOF

apt-get update
OS_REPO_NON_NOBLE

  cat >"${WORK}/root/home/casper/os/sh/php.sh" <<'OS_PHP_NON_NOBLE'
#!/bin/bash

rm -f \
	/etc/apt/sources.list.d/ondrej-* \
	/etc/apt/sources.list.d/*ondrej* \
	/etc/apt/keyrings/ondrej-* \
	/etc/apt/keyrings/*ondrej*

apt-get update

package_exists() {
	local candidate
	candidate="$(apt-cache policy "$1" | awk '/Candidate:/ { print $2; exit }')"
	[[ -n "${candidate}" && "${candidate}" != "(none)" ]]
}

install_available() {
	local packages=()
	local package_name

	for package_name in "$@"; do
		if package_exists "${package_name}"; then
			packages+=("${package_name}")
		else
			echo "Skipping unavailable package on this Ubuntu release: ${package_name}" >&2
		fi
	done

	if ((${#packages[@]})); then
		apt-get install -y "${packages[@]}"
	fi
}

install_available \
	php \
	php-fpm \
	php-cli \
	php-common \
	php-apcu \
	php-ast \
	php-bcmath \
	php-bz2 \
	php-curl \
	php-decimal \
	php-dev \
	php-gd \
	php-grpc \
	php-http \
	php-igbinary \
	php-imap \
	php-intl \
	php-mbstring \
	php-memcached \
	php-mysql \
	php-oauth \
	php-pgsql \
	php-protobuf \
	php-ps \
	php-pspell \
	php-psr \
	php-readline \
	php-redis \
	php-smbclient \
	php-soap \
	php-solr \
	php-sqlite3 \
	php-ssh2 \
	php-tidy \
	php-uploadprogress \
	php-uuid \
	php-xdebug \
	php-xlswriter \
	php-xml \
	php-xmlrpc \
	php-yaml \
	php-zip

php_version="$(php -r 'echo PHP_MAJOR_VERSION "." PHP_MINOR_VERSION;' 2>/dev/null || true)"
if [[ -n "${php_version}" ]]; then
	a2enconf "php${php_version}-fpm" || true
fi
a2enmod proxy_fcgi setenvif || true

EXPECTED_CHECKSUM="$(php -r "copy('https://composer.github.io/installer.sig', 'php://stdout');")"
php -r "copy('https://getcomposer.org/installer', 'composer-setup.php');"
ACTUAL_CHECKSUM="$(php -r "echo hash_file('sha384', 'composer-setup.php');")"

if [[ "${EXPECTED_CHECKSUM}" != "${ACTUAL_CHECKSUM}" ]]; then
	rm -f composer-setup.php
	echo "Composer installer checksum mismatch" >&2
	exit 1
fi

php composer-setup.php --install-dir=/usr/local/bin --filename=composer
rm -f composer-setup.php

COMPOSER_GLOBAL_HOME=/usr/local/share/composer
COMPOSER_GLOBAL_BIN="${COMPOSER_GLOBAL_HOME}/vendor/bin"

install -d -m 0755 "${COMPOSER_GLOBAL_HOME}"
install -d -m 0755 /etc/profile.d

cat <<'EOF' >/etc/profile.d/composer-global-bin.sh
#!/bin/sh
COMPOSER_GLOBAL_BIN="/usr/local/share/composer/vendor/bin"

case ":${PATH}:" in
	*:"${COMPOSER_GLOBAL_BIN}":*)
		;;
	*)
		export PATH="${COMPOSER_GLOBAL_BIN}:${PATH}"
		;;
esac
EOF
chmod 0644 /etc/profile.d/composer-global-bin.sh

export COMPOSER_HOME="${COMPOSER_GLOBAL_HOME}"
export COMPOSER_ALLOW_SUPERUSER=1
export PATH="${COMPOSER_GLOBAL_BIN}:${PATH}"

curl -1sLf 'https://dl.cloudsmith.io/public/symfony/stable/setup.deb.sh' | bash
apt-get update
install_available symfony-cli

# Drush Launcher finds and executes the project-local drush/drush installed in
# each repo's vendor directory, so the global `drush` command matches the Drupal
# project's own Drush version instead of forcing one global Composer copy.
curl -fL \
	https://github.com/drush-ops/drush-launcher/releases/latest/download/drush.phar \
	-o /usr/local/bin/drush
chmod 0755 /usr/local/bin/drush
OS_PHP_NON_NOBLE

  chmod 0755 "${WORK}/root/home/casper/os/sh/repo.sh" "${WORK}/root/home/casper/os/sh/php.sh"
}

prepare_chroot_mounts() {
  echo "Preparing chroot mounts..."
  mount --bind /dev "${WORK}/root/dev"
  mount --bind /dev/pts "${WORK}/root/dev/pts"
  # A plain /dev bind does not reliably carry the host's /dev/shm submount
  # into the chroot. Expose it explicitly for tools that need a non-overlay
  # extraction workspace, such as the Node.js installer in sh/npm.sh.
  mkdir -p "${WORK}/root/dev/shm"
  mount --bind /dev/shm "${WORK}/root/dev/shm"
  mount -t proc proc "${WORK}/root/proc"
  mount -t sysfs sysfs "${WORK}/root/sys"
  rm -f "${WORK}/root/etc/resolv.conf"
  cp -L /etc/resolv.conf "${WORK}/root/etc/resolv.conf"
  mount --bind /run "${WORK}/root/run"

  if [[ -f "${WORK}/root/etc/apt/sources.list.d/cdrom.sources" ]]; then
    mv "${WORK}/root/etc/apt/sources.list.d/cdrom.sources" \
      "${WORK}/root/etc/apt/sources.list.d/cdrom.sources.disabled"
  fi
}

install_firstboot_service() {
  echo "Installing first-boot completion service for snap/service-sensitive work..."
  install -d -m 0755 "${WORK}/root/usr/local/sbin" "${WORK}/root/etc/systemd/system"
  cat >"${WORK}/root/usr/local/sbin/os-init-firstboot.sh" <<'EOF'
#!/usr/bin/env bash
set -u
LOG=/var/log/os-init-firstboot.log
exec >>"${LOG}" 2>&1
echo "=== os-init-firstboot started $(date -Is) ==="
if [[ -f /etc/apt/sources.list.d/cdrom.sources ]]; then
  mv /etc/apt/sources.list.d/cdrom.sources /etc/apt/sources.list.d/cdrom.sources.disabled
fi
rm -f \
  /etc/apt/sources.list.d/ondrej-* \
  /etc/apt/sources.list.d/*ondrej* \
  /etc/apt/keyrings/ondrej-* \
  /etc/apt/keyrings/*ondrej*
if bash /home/casper/os/os.sh; then
  # Local deb overlays belong after the full scripted install so they can win
  # over repo defaults and avoid being removed by earlier cleanup steps.
  if compgen -G '/home/casper/os/deb/*.deb' >/dev/null; then
    apt-get install -y /home/casper/os/deb/*.deb
  fi
  systemctl disable os-init-firstboot.service || true
  rm -f /etc/systemd/system/multi-user.target.wants/os-init-firstboot.service
  echo "=== os-init-firstboot completed $(date -Is) ==="
else
  status=$?
  echo "=== os-init-firstboot failed with ${status} $(date -Is) ==="
  exit "${status}"
fi
EOF
  chmod 0755 "${WORK}/root/usr/local/sbin/os-init-firstboot.sh"
  cat >"${WORK}/root/etc/systemd/system/os-init-firstboot.service" <<'EOF'
[Unit]
Description=Run SrcHorse OS initializer on first persistent live boot
Wants=network-online.target snapd.service
After=network-online.target snapd.service

[Service]
Type=oneshot
ExecStart=/usr/local/sbin/os-init-firstboot.sh
RemainAfterExit=no

[Install]
WantedBy=multi-user.target
EOF
  chroot "${WORK}/root" /bin/bash -lc 'systemctl enable os-init-firstboot.service || true'
}

run_os_installer() {
  local chroot_status

  echo "Running /home/casper/os/os.sh inside the persistent overlay chroot..."
  echo "If snapd cannot operate in chroot, the first-boot service will finish it when the USB boots."
  set +e
  chroot "${WORK}/root" /bin/bash -lc 'bash /home/casper/os/os.sh'
  chroot_status=$?
  set -e

  if [[ "${chroot_status}" -ne 0 ]]; then
    echo "Chroot installer exited with status ${chroot_status}; first-boot service remains enabled."
  else
    CHROOT_INSTALL_SUCCEEDED=1
    echo "Chroot installer completed successfully."
  fi
}

install_local_debs_last() {
  local deb_count

  if [[ ! -d "${DEB_SRC}" ]]; then
    return 0
  fi

  deb_count="$(find "${WORK}/root/home/casper/os/deb" -maxdepth 1 -type f -name '*.deb' 2>/dev/null | wc -l)"
  if [[ "${deb_count}" -eq 0 ]]; then
    return 0
  fi

  # Keep local package overlays last so repo packages, purge rules, and language
  # tooling settle before app-level .deb installers make their changes.
  echo "Installing ${deb_count} local .deb package(s) from ./deb as the final chroot step..."
  chroot "${WORK}/root" /bin/bash -lc 'apt-get install -y /home/casper/os/deb/*.deb'
}

rm -rf "${WORK}"
mkdir -p "${WORK}"

prompt_for_device
set_device_partitions
verify_device
verify_required_paths

if [[ "${MODE}" == "create" ]]; then
  echo "About to ERASE and rewrite ${DEVICE}."
  lsblk -o NAME,PATH,SIZE,FSTYPE,LABEL,MODEL,MOUNTPOINTS "${DEVICE}"
  echo
  read -r -p "Type ${DEVICE} exactly to continue: " confirm
  if [[ "${confirm}" != "${DEVICE}" ]]; then
    echo "Confirmation did not match; aborting." >&2
    exit 1
  fi

  resolve_latest_iso
  remaster_iso
  unmount_device_partitions
  write_usb
else
  echo "Resuming chroot install on existing persistent USB."
  lsblk -o NAME,PATH,SIZE,FSTYPE,LABEL,MODEL,MOUNTPOINTS "${DEVICE}"
fi

mount_overlay
copy_os_source
patch_os_installer_for_target
prepare_chroot_mounts
install_firstboot_service
run_os_installer
if [[ "${CHROOT_INSTALL_SUCCEEDED}" -eq 1 ]]; then
  install_local_debs_last
else
  echo "Skipping final local .deb install until first boot, after os.sh completes successfully."
fi

sync
if [[ "${MODE}" == "create" ]]; then
  echo "USB creation complete. Boot ${DEVICE}; persistence is on ${PERSIST_PART} and fills the remaining USB space."
else
  echo "Resume complete. Boot ${DEVICE}; persistence is on ${PERSIST_PART}."
fi
