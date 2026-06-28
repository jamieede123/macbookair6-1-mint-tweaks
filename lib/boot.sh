#!/usr/bin/env bash
# Faster boot: NetworkManager-wait-online holds the boot until the network is
# fully up (~10 s here). A desktop session does not need to block on it.

apply_boot() {
  need_root
  log "Faster boot (mask NetworkManager-wait-online)"

  if [[ "$(systemctl is-enabled NetworkManager-wait-online.service 2>/dev/null)" == masked ]]; then
    skip "already masked"
  else
    run systemctl mask NetworkManager-wait-online.service
    ok "masked"
  fi
}
