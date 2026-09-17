install_firstboot_service() {
  if ((OS_MINIMAL)); then
    echo "Minimal mode: not staging the optional first-boot snap bundle."
    return 0
  fi
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
rm -f /etc/apt/sources.list.d/ondrej-* /etc/apt/sources.list.d/*ondrej* \
  /etc/apt/keyrings/ondrej-* /etc/apt/keyrings/*ondrej*
if bash -euo pipefail -c '. /home/casper/os/sh/_meep/setup.sh; . /home/casper/os/sh/_meep/snap.sh; . /home/casper/os/sh/_meep/purge.sh'; then
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
Description=Run Meep OS initializer on first persistent live boot
Wants=network-online.target snapd.service
After=network-online.target snapd.service

[Service]
Type=oneshot
ExecStart=/usr/local/sbin/os-init-firstboot.sh
RemainAfterExit=no

[Install]
WantedBy=multi-user.target
EOF
  chroot "${WORK}/root" /bin/bash -c 'systemctl enable os-init-firstboot.service || true'
}

persist_phase_11_firstboot() {
  install_firstboot_service
}
