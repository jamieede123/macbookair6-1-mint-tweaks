#!/usr/bin/env bash
# zram: compressed swap in RAM. The biggest responsiveness win on 4 GB,
# because swapped pages stay in memory instead of hitting the SSD.

apply_zram() {
  need_root
  log "zram compressed swap"

  if dpkg -s zram-config >/dev/null 2>&1; then
    skip "zram-config already installed"
  else
    run apt-get install -y zram-config
  fi

  run systemctl enable zram-config.service
  warn "zram device appears after the next reboot (check: zramctl)"
}
