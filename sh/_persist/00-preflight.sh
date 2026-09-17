usage() {
  cat <<EOF
Usage: ./sh/persist [--device /dev/sdX] [--resume] [--minimal]
       ./sh/persist /dev/sdX [--resume] [--minimal]
       ./sh/persist --build-only [--iso /path/source.iso] [--minimal]
       ./sh/persist --root /meep --iso /path/source.iso [--build-only]

Default mode prompts for a target device, builds one customized Ubuntu Meep
live filesystem from the merged build root, then erases and recreates the
target USB from that result. Use --resume to skip ISO rebuilding and rerun
only the overlay chroot work against an existing persistent USB.
EOF
}

persist_phase_00_preflight() {
  [[ ${EUID} -eq 0 ]] || { echo "Run ./sh/persist as root." >&2; exit 1; }
  [[ ${MODE} == create && -z ${DEVICE} ]] || ((BUILD_ONLY == 0)) || {
    echo "--build-only cannot use --resume or a device." >&2
    exit 1
  }
}
