#!/usr/bin/env bash
# TLP: full responsiveness on AC, power savings on battery.
#   WIFI_PWR_ON_BAT=on        -> radio dozes between packets on battery
#   PCIE_ASPM_ON_BAT=powersupersave -> deepest PCIe power state on battery

apply_tlp() {
  need_root
  log "TLP power profiles (Wi-Fi powersave + PCIe ASPM on battery)"

  if dpkg -s tlp >/dev/null 2>&1; then
    skip "tlp already installed"
  else
    run apt-get update -qq
    run apt-get install -y tlp tlp-rdw
  fi

  local c=/etc/tlp.conf
  backup_file "$c"
  _set() { run sed -i "s|^#\?$1=.*|$1=$2|" "$c"; ok "$1=$2"; }
  _set WIFI_PWR_ON_AC      off
  _set WIFI_PWR_ON_BAT     on
  _set PCIE_ASPM_ON_AC     default
  _set PCIE_ASPM_ON_BAT    powersupersave

  run systemctl enable --now tlp
}
