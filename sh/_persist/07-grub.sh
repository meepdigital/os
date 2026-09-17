prepare_grub_config() {
  echo "Preparing the single Ubuntu Meep persistent boot path..."
  xorriso -osirrox on -indev "${ISO}" -extract /boot/grub/grub.cfg "${WORK}/grub.cfg.orig" >/dev/null 2>&1
  xorriso -osirrox on -indev "${ISO}" -extract /boot/grub/loopback.cfg "${WORK}/loopback.cfg.orig" >/dev/null 2>&1
  xorriso -osirrox on -indev "${ISO}" -extract /.disk/info "${WORK}/disk-info.orig" >/dev/null 2>&1
  cat >"${WORK}/grub.cfg" <<'EOF'
set default=0
set timeout=0
set timeout_style=hidden
set GRUB_TIMEOUT=0
set GRUB_TIMEOUT_STYLE=hidden

menuentry "Ubuntu Meep" {
  set gfxpayload=keep
  linux /casper/vmlinuz persistent layerfs-path=minimal.squashfs quiet splash
  initrd /casper/initrd
}
EOF
  sed 's/Ubuntu-Cinnamon/Ubuntu-Meep/g; s/Ubuntu Cinnamon/Ubuntu Meep/g' \
    "${WORK}/disk-info.orig" >"${WORK}/disk-info"
  [[ $(rg -c '^menuentry ' "${WORK}/grub.cfg") == 1 ]] || {
    echo "Single Ubuntu Meep grub entry was not generated" >&2
    exit 1
  }
  cat >"${WORK}/loopback.cfg" <<'EOF'
set default=0
set timeout=0
set timeout_style=hidden

menuentry "Ubuntu Meep" {
  set gfxpayload=keep
  linux /casper/vmlinuz iso-scan/filename=${iso_path} persistent layerfs-path=minimal.squashfs quiet splash
  initrd /casper/initrd
}
EOF
  [[ $(rg -c '^menuentry ' "${WORK}/loopback.cfg") == 1 ]] || {
    echo "Single Ubuntu Meep loopback entry was not generated" >&2
    exit 1
  }
}

persist_phase_07_grub() {
  [[ ${MODE} == create ]] || return 0
  prepare_grub_config
}
