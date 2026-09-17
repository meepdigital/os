copy_os_source() {
  echo "Copying this repo into the persistent live user's home..."
  install -d -m 0755 "${WORK}/root/home/casper"
  rsync -a --delete \
    --exclude '/tmp/' \
    --exclude '/*.iso' \
    --exclude '/*.iso.part' \
    "${OS_SRC}/" "${WORK}/root/home/casper/os/"
}

persist_phase_09_copy_source() {
  copy_os_source
}
