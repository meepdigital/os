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
CUSTOM_SQUASHFS=""
DEVICE=""
ISO_PART=""
PERSIST_PART=""
MODE="create"
CHROOT_INSTALL_SUCCEEDED=0
BUILD_ONLY=0
ROOT_SOURCE=""

usage() {
  cat <<EOF
Usage: sudo bash ./${ENTRYPOINT_NAME} [--device /dev/sdX] [--resume]
       sudo bash ./${ENTRYPOINT_NAME} /dev/sdX [--resume]
       sudo bash ./${ENTRYPOINT_NAME} --build-only [--iso /path/source.iso]
       sudo bash ./${ENTRYPOINT_NAME} --root /meep --iso /path/source.iso [--build-only]

Default mode prompts for a target device, builds one customized Ubuntu Meep
live filesystem from the merged build root, then erases and recreates the
target USB from that result. Use --resume to skip ISO rebuilding and rerun
only the overlay chroot work against an existing persistent USB.
EOF
}

while (($#)); do
  case "$1" in
    --root)
      shift
      ROOT_SOURCE="$(realpath "${1:?--root needs a mounted OS root}")"
      [[ ${ROOT_SOURCE} != / && -f ${ROOT_SOURCE}/etc/os-release ]] || { echo "Invalid OS root" >&2; exit 1; }
      ;;
    --build-only)
      BUILD_ONLY=1
      ;;
    --iso)
      shift
      ISO="$(realpath "${1:?--iso needs an existing source ISO}")"
      [[ -f ${ISO} ]] || { echo "Missing ISO: ${ISO}" >&2; exit 1; }
      ;;
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

  [[ $(lsblk -dnro TYPE "${DEVICE}") == disk ]] || {
    echo "Target must be a whole disk, not a partition or loop device." >&2; exit 1;
  }
  if lsblk -nrpo MOUNTPOINTS "${DEVICE}" | grep -Eq '^(/|/boot(/efi)?|/home|/usr|/var|/tmp|/srv|/opt|/usr/local|\[SWAP\])$'; then
    echo "Refusing a disk used by the running host: ${DEVICE}" >&2; exit 1
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
    umount "${target}" || { echo "Busy build mount: ${target}; stopping cleanup." >&2; return 1; }
  done < <(findmnt -Rnr -o TARGET "${base}" | \
    awk -v base="${base}" '$0 == base || index($0, base "/") == 1 { print length, $0 }' | \
    sort -rn | cut -d' ' -f2-)

  while read -r loopdev; do
    [[ -n "${loopdev}" ]] || continue
    losetup -d "${loopdev}" >/dev/null 2>&1 || true
  done < <(losetup -a | awk -v base="${base}" 'index($0, base) { sub(/:.*/, "", $1); print $1 }')

  if mountpoint -q "${base}/iso"; then
    umount "${base}/iso" || return 1
  fi
}

cleanup() {
  set +e
  if [[ -f ${WORK}/meep-created-policy-rc.d ]]; then
    rm -f "${WORK}/root/usr/sbin/policy-rc.d"
  fi
  # WORK itself is not a mountpoint; enumerate all mounts under its prefix.
  # Never hide a busy mount with lazy unmount before deleting a build tree.
  cleanup_existing_tree "${WORK}"
}
trap cleanup EXIT

cleanup_existing_tree "${WORK_ROOT}/ubuntu-cinnamon-usb-build"
cleanup_existing_tree "${WORK_ROOT}/ubuntu-cinnamon-usb-resume"

prepare_grub_config() {
  echo "Preparing Ubuntu Meep live and install modes..."
  xorriso -osirrox on -indev "${ISO}" -extract /boot/grub/grub.cfg "${WORK}/grub.cfg.orig" >/dev/null 2>&1
  xorriso -osirrox on -indev "${ISO}" -extract /.disk/info "${WORK}/disk-info.orig" >/dev/null 2>&1
  sed \
    -e 's#linux  /casper/vmlinuz  --- quiet splash#linux  /casper/vmlinuz persistent --- quiet splash#' \
    -e 's#linux  /casper/vmlinuz nomodeset  --- quiet splash#linux  /casper/vmlinuz nomodeset persistent --- quiet splash#' \
    -e 's/Ubuntu Cinnamon/Ubuntu Meep/g' \
    "${WORK}/grub.cfg.orig" >"${WORK}/grub.cfg"

  # Both live modes use the same customized squashfs. The install mode boots
  # the same persistent live system and asks the future Ubuntu Meep installer
  # to install the current merged live root, including persistent edits.
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
      print "menuentry \"Ubuntu Meep - Install Current System\" {"
      print "    set gfxpayload=keep"
      print "    linux  /casper/vmlinuz persistent meep.install=1 --- quiet splash"
      print "    initrd /casper/initrd"
      print "}"
      inserted = 1
      in_entry = 0
      next
    }
    { print }
  ' "${WORK}/grub.cfg" >"${WORK}/grub.cfg.modes"
  mv "${WORK}/grub.cfg.modes" "${WORK}/grub.cfg"
  # Ubuntu Cinnamon's initrd defaults to a three-file layer chain named
  # minimal.standard.live.squashfs -> minimal.standard.squashfs ->
  # minimal.squashfs. This build intentionally emits one merged image, so
  # override casper's layer name on every live menu entry.
  sed -i \
    's#linux  /casper/vmlinuz #linux  /casper/vmlinuz layerfs-path=minimal.squashfs #' \
    "${WORK}/grub.cfg"
  sed 's/Ubuntu-Cinnamon/Ubuntu-Meep/g; s/Ubuntu Cinnamon/Ubuntu Meep/g' \
    "${WORK}/disk-info.orig" >"${WORK}/disk-info"
  if ! rg -q 'Ubuntu Meep - Install Current System' "${WORK}/grub.cfg"; then
    echo "Could not add the Ubuntu Meep install mode to grub.cfg" >&2
    exit 1
  fi
}

build_custom_iso() {
  local manifest_full manifest manifest_size kernel_version

  kernel_version="$(find "${WORK}/rootfs/boot" -maxdepth 1 -type f -name 'vmlinuz-*' -printf '%f\n' | sed 's/^vmlinuz-//' | sort -V | tail -n 1)"
  [[ -n ${kernel_version} && -s ${WORK}/rootfs/boot/initrd.img-${kernel_version} ]] || {
    echo "No matching generated kernel/initramfs pair; refusing to build." >&2; exit 1;
  }
  bash "${SCRIPT_DIR}/scripts/verify-initramfs.sh" \
    "${WORK}/rootfs/boot/initrd.img-${kernel_version}" "${SCRIPT_DIR}/assets/boot" \
    "${kernel_version}" live "${WORK}/casper-uuid-generic"
  for directory in dev proc sys run tmp; do
    [[ -d ${WORK}/rootfs/${directory} ]] || { echo "Missing boot mountpoint: /${directory}" >&2; exit 1; }
  done
  chroot "${WORK}/rootfs" /usr/bin/test -x /sbin/init

  CUSTOM_ISO="${SCRIPT_DIR}/$(basename "${ISO%.iso}")-persistent.iso"
  CUSTOM_SQUASHFS="${WORK}/minimal.squashfs"
  manifest_full="${WORK}/minimal.manifest.full"
  manifest="${WORK}/minimal.manifest"
  manifest_size="${WORK}/minimal.size"

  echo "Building the single Ubuntu Meep live filesystem from the merged root..."
  rm -f "${CUSTOM_SQUASHFS}"
  mksquashfs "${WORK}/rootfs" "${CUSTOM_SQUASHFS}" -comp xz -b 1M -noappend

  # dpkg-query, not this shell, expands these package fields.
  # shellcheck disable=SC2016
  chroot "${WORK}/rootfs" dpkg-query -W -f='${Package} ${Version}\n' | sort >"${manifest_full}"
  awk '{ print $1 }' "${manifest_full}" >"${manifest}"
  du -sx --block-size=1 "${WORK}/rootfs" | awk '{ print $1 }' >"${manifest_size}"

  # Retain checksums for unchanged ISO files and replace every changed entry.
  xorriso -osirrox on -indev "${ISO}" -extract /md5sum.txt "${WORK}/md5sum.orig" >/dev/null 2>&1
  awk '$2 !~ /^\.\/casper\/minimal[.]/ && $2 !~ /^\.\/casper\/(vmlinuz|initrd)$/ &&
       $2 != "./boot/grub/grub.cfg" && $2 != "./.disk/info" &&
       $2 != "./.disk/casper-uuid-generic" && $2 != "./md5sum.txt"' \
      "${WORK}/md5sum.orig" >"${WORK}/md5sum.txt"
  local source destination digest
  while read -r source destination; do
    digest=$(md5sum "${WORK}/${source}" | cut -d' ' -f1)
    printf '%s  ./%s\n' "${digest}" "${destination}" >>"${WORK}/md5sum.txt"
  done <<EOF
rootfs/boot/vmlinuz-${kernel_version} casper/vmlinuz
rootfs/boot/initrd.img-${kernel_version} casper/initrd
minimal.squashfs casper/minimal.squashfs
minimal.manifest.full casper/minimal.manifest.full
minimal.manifest casper/minimal.manifest
minimal.size casper/minimal.size
grub.cfg boot/grub/grub.cfg
disk-info .disk/info
casper-uuid-generic .disk/casper-uuid-generic
EOF

  echo "Writing the Ubuntu Meep filesystem, manifests, and boot menu into the ISO..."
  rm -f "${CUSTOM_ISO}"
  xorriso -indev "${ISO}" -outdev "${CUSTOM_ISO}" -boot_image any replay \
      -rm \
        /casper/minimal.standard.live.squashfs \
        /casper/minimal.standard.live.manifest \
        /casper/minimal.standard.live.manifest.full \
        /casper/minimal.standard.live.size \
        /casper/minimal.standard.squashfs \
        /casper/minimal.standard.manifest \
        /casper/minimal.standard.manifest.full \
        /casper/minimal.standard.size \
      -- \
      -volid 'Ubuntu-Meep' \
      -map "${WORK}/rootfs/boot/vmlinuz-${kernel_version}" /casper/vmlinuz \
      -map "${WORK}/rootfs/boot/initrd.img-${kernel_version}" /casper/initrd \
      -map "${CUSTOM_SQUASHFS}" /casper/minimal.squashfs \
      -map "${WORK}/grub.cfg" /boot/grub/grub.cfg \
      -map "${WORK}/disk-info" /.disk/info \
      -map "${WORK}/casper-uuid-generic" /.disk/casper-uuid-generic \
      -map "${WORK}/md5sum.txt" /md5sum.txt \
      -map "${manifest_full}" /casper/minimal.manifest.full \
      -map "${manifest}" /casper/minimal.manifest \
      -map "${manifest_size}" /casper/minimal.size

  # Read the boot pair back from the finished ISO, not just the staging tree.
  xorriso -osirrox on -indev "${CUSTOM_ISO}" \
    -extract /casper/vmlinuz "${WORK}/iso-vmlinuz" \
    -extract /casper/initrd "${WORK}/iso-initrd" >/dev/null 2>&1
  cmp "${WORK}/rootfs/boot/vmlinuz-${kernel_version}" "${WORK}/iso-vmlinuz"
  cmp "${WORK}/rootfs/boot/initrd.img-${kernel_version}" "${WORK}/iso-initrd"
  bash "${SCRIPT_DIR}/scripts/verify-initramfs.sh" \
    "${WORK}/iso-initrd" "${SCRIPT_DIR}/assets/boot" \
    "${kernel_version}" live "${WORK}/iso-casper-uuid-generic"
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
  local iso_bytes disk_bytes
  iso_bytes=$(stat -c %s "${CUSTOM_ISO}")
  disk_bytes=$(blockdev --getsize64 "${DEVICE}")
  ((disk_bytes > iso_bytes + 1073741824)) || { echo "Need at least 1 GiB beyond the ISO for persistence." >&2; exit 1; }
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
  [[ $(blkid -s LABEL -o value "${PERSIST_PART}") == writable ]]
  echo "Verifying the ISO data partition written to ${DEVICE}..."
  # sgdisk necessarily changes GPT headers outside this partition.
  local start size
  start=$(lsblk -bnro START "${ISO_PART}")
  size=$(blockdev --getsize64 "${ISO_PART}")
  cmp -n "${size}" -i "$((start * 512)):0" "${CUSTOM_ISO}" "${ISO_PART}"
}

mount_overlay() {
  local lowerdirs=""
  local idx=0
  local image
  local name
  local loopdev
  local layer
  local images=()

  mkdir -p "${WORK}/iso" "${WORK}/persist" "${WORK}/root" "${WORK}/layers"
  if [[ -n ${ROOT_SOURCE} ]]; then
    [[ ${MODE} == create ]] || { echo "--root cannot be used with --resume" >&2; exit 1; }
    echo "Copying ${ROOT_SOURCE} as the customized OS source..."
    rsync -aHAX --numeric-ids --exclude '/dev/***' --exclude '/proc/***' \
      --exclude '/sys/***' --exclude '/run/***' --exclude '/tmp/***' \
      --exclude '/boot/efi/***' --exclude '/cdrom/***' --exclude '/rofs/***' \
      --exclude '/mnt/***' --exclude '/media/***' --exclude '/meep/***' \
      "${ROOT_SOURCE}/" "${WORK}/root/"
    install -d -m 0755 "${WORK}/root/"{dev,proc,sys,run,cdrom,rofs,media,mnt}
    install -d -m 1777 "${WORK}/root/tmp"
    # The live copy must not try to mount the VM's installed root or ESP.
    printf '# Live root is mounted by casper.\n' >"${WORK}/root/etc/fstab"
    rm -f "${WORK}/root/etc/initramfs-tools/conf.d/zz-meep-installed.conf"
    rm -f "${WORK}/root/etc/default/grub.d/98-meep-vm.cfg"
    return
  fi
  if [[ "${MODE}" == "create" ]]; then
    mount -o loop,ro "${ISO}" "${WORK}/iso"
  else
    mount -o ro "${ISO_PART}" "${WORK}/iso"
  fi
  cleanup_mounts+=("${WORK}/iso")
  if [[ "${MODE}" == "resume" ]]; then
    mount "${PERSIST_PART}" "${WORK}/persist"
    cleanup_mounts+=("${WORK}/persist")
  fi
  mkdir -p "${WORK}/persist/upper" "${WORK}/persist/work"

  echo "Mounting live filesystem overlay..."
  shopt -s nullglob
  # Alphabetical glob order puts standard.live BEFORE standard, incorrectly
  # letting the standard layer override the live layer. Use base-to-leaf order.
  if [[ -f ${WORK}/iso/casper/minimal.squashfs ]]; then
    images+=("${WORK}/iso/casper/minimal.squashfs")
    for name in minimal.standard.squashfs minimal.standard.live.squashfs; do
      [[ ! -f ${WORK}/iso/casper/${name} ]] || images+=("${WORK}/iso/casper/${name}")
    done
  elif [[ -f ${WORK}/iso/casper/filesystem.squashfs ]]; then
    images+=("${WORK}/iso/casper/filesystem.squashfs")
  else
    echo "Unsupported source layer layout; refusing to guess squashfs order." >&2; exit 1
  fi
  for image in "${images[@]}"; do
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
    echo "No squashfs layers found in the source ISO; aborting." >&2
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
  # Do not expose host snapd/systemd sockets to package scripts in the chroot.
  mount -t tmpfs -o mode=0755 tmpfs "${WORK}/root/run"
  if [[ ! -e ${WORK}/root/usr/sbin/policy-rc.d ]]; then
    printf '#!/bin/sh\nexit 101\n' >"${WORK}/root/usr/sbin/policy-rc.d"
    chmod 0755 "${WORK}/root/usr/sbin/policy-rc.d"
    touch "${WORK}/meep-created-policy-rc.d"
  fi

  if [[ -f "${WORK}/root/etc/apt/sources.list.d/cdrom.sources" ]]; then
    mv "${WORK}/root/etc/apt/sources.list.d/cdrom.sources" \
      "${WORK}/root/etc/apt/sources.list.d/cdrom.sources.disabled"
  fi
}

install_firstboot_service() {
  echo "Staging completion service; the installation VM will finish and disable it before export..."
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
if bash -euo pipefail -c '. /home/casper/os/sh/setup.sh; . /home/casper/os/sh/snap.sh; . /home/casper/os/sh/purge.sh'; then
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
  echo "Snap installation will run in the target VM before export."
  set +e
  chroot "${WORK}/root" /usr/bin/env MEEP_CHROOT=1 MEEP_LIVE_BUILD=1 /bin/bash -lc 'bash /home/casper/os/os.sh'
  chroot_status=$?
  set -e

  if [[ "${chroot_status}" -ne 0 ]]; then
    echo "Chroot installer failed with status ${chroot_status}; refusing to produce or write an incomplete OS." >&2
    exit "${chroot_status}"
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

materialize_custom_root() {
  echo "Materializing the merged live root as the Ubuntu Meep source of truth..."
  rm -rf "${WORK}/rootfs"
  mkdir -p "${WORK}/rootfs"

  # Copy the merged overlay, not /dev/sde4/upper by itself. The merged view
  # contains the complete OS and already applies overlay whiteouts correctly.
  # Runtime mounts and live-media paths must never become part of an installed
  # system or the next live boot image.
  rsync -aHAX --numeric-ids --delete \
    --exclude '/dev/***' \
    --exclude '/proc/***' \
    --exclude '/sys/***' \
    --exclude '/run/***' \
    --exclude '/tmp/***' \
    --exclude '/cdrom/***' \
    --exclude '/rofs/***' \
    --exclude '/media/***' \
    --exclude '/mnt/***' \
    "${WORK}/root/" "${WORK}/rootfs/"

  # Exclude runtime CONTENTS, but retain the mount destinations used by init.
  install -d -m 0755 "${WORK}/rootfs/"{dev,proc,sys,run,cdrom,rofs,media,mnt}
  install -d -m 1777 "${WORK}/rootfs/tmp"
  if [[ -e ${WORK}/meep-created-policy-rc.d ]]; then
    rm -f "${WORK}/rootfs/usr/sbin/policy-rc.d"
  fi

  # prepare_chroot_mounts temporarily replaces resolv.conf with the builder's
  # resolver. Restore the normal systemd-resolved link in the baked root.
  rm -f "${WORK}/rootfs/etc/resolv.conf"
  ln -s ../run/systemd/resolve/stub-resolv.conf "${WORK}/rootfs/etc/resolv.conf"
}

rm -rf "${WORK}"
mkdir -p "${WORK}"

if ((BUILD_ONLY)); then
  [[ ${MODE} == create && -z ${DEVICE} ]] || { echo "--build-only cannot use --resume or a device." >&2; exit 1; }
else
  prompt_for_device
  set_device_partitions
  verify_device
fi
verify_required_paths

if [[ "${MODE}" == "create" ]]; then
 if ((!BUILD_ONLY)); then
  echo "About to ERASE and rewrite ${DEVICE}."
  lsblk -o NAME,PATH,SIZE,FSTYPE,LABEL,MODEL,MOUNTPOINTS "${DEVICE}"
  echo
  read -r -p "Type ${DEVICE} exactly to continue: " confirm
  if [[ "${confirm}" != "${DEVICE}" ]]; then
    echo "Confirmation did not match; aborting." >&2
    exit 1
  fi
 fi

  [[ -n ${ISO} ]] || resolve_latest_iso
  prepare_grub_config
else
  echo "Resuming chroot install on existing persistent USB."
  lsblk -o NAME,PATH,SIZE,FSTYPE,LABEL,MODEL,MOUNTPOINTS "${DEVICE}"
fi

mount_overlay
copy_os_source
prepare_chroot_mounts
install_firstboot_service
if [[ -n ${ROOT_SOURCE} ]]; then
  # /meep is already provisioned; only rebuild its live boot artifacts.
  CHROOT_INSTALL_SUCCEEDED=1
else
  run_os_installer
fi
if [[ "${CHROOT_INSTALL_SUCCEEDED}" -eq 1 ]]; then
  install_local_debs_last
  # Local packages can replace the alternatives/kernel. Reapply branding last.
  chroot "${WORK}/root" /usr/bin/env MEEP_CHROOT=1 MEEP_LIVE_BUILD=1 \
    /bin/bash /home/casper/os/os.sh --boot-only
else
  echo "Skipping final local .deb install until first boot, after os.sh completes successfully."
fi

materialize_custom_root

if [[ "${MODE}" == "create" ]]; then
  build_custom_iso
  sync
  if ((BUILD_ONLY)); then
    echo "ISO built and boot files verified: ${CUSTOM_ISO}. Boot and persistence tests are still required."
    exit 0
  fi
  # The target is deliberately written only after the customized merged root
  # has become the ISO source. The new persistence partition starts empty;
  # future edits belong in that partition and are consumed by install mode.
  verify_device
  unmount_device_partitions
  write_usb
  echo "USB written and read back. Persistence partition: ${PERSIST_PART}. Boot and reboot-persistence tests are still required."
else
  # Resume writes the completed merged root back through OverlayFS so deletions
  # become whiteouts and existing persistent user data remains represented.
  rsync -aHAX --numeric-ids --delete \
    --exclude '/dev/***' --exclude '/proc/***' --exclude '/sys/***' \
    --exclude '/run/***' --exclude '/tmp/***' --exclude '/cdrom/***' \
    --exclude '/rofs/***' --exclude '/media/***' --exclude '/mnt/***' \
    "${WORK}/rootfs/" "${WORK}/root/"
  sync
  echo "Resume complete. Boot ${DEVICE}; persistence is on ${PERSIST_PART}."
fi
