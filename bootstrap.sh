#!/usr/bin/env bash
# macbookair6-1-mint-tweaks — battery and performance tweaks for an
# 11-inch MacBook Air (MacBookAir6,1) on Linux Mint / Ubuntu 24.04.
#
# Wi-Fi is handled separately by broadcom/fix.sh (kernel 6.16+ only).
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$HERE/lib/common.sh"
source "$HERE/lib/grub.sh"
source "$HERE/lib/tlp.sh"
source "$HERE/lib/zram.sh"
source "$HERE/lib/boot.sh"

usage() {
  cat <<EOF
${C_B}macbookair6-1-mint-tweaks${C_RESET}

Usage: sudo ./bootstrap.sh [options]

Steps (default: --all):
  --grub      deep sleep + intel_backlight (kernel cmdline)
  --tlp       TLP power profiles (Wi-Fi/PCIe savings on battery)
  --zram      compressed swap in RAM
  --boot      mask NetworkManager-wait-online (faster boot)
  --all       run every step above

Options:
  --status    print current state and exit (read-only, no sudo needed)
  --dry-run   print what would change, do nothing
  --force     run even if the model isn't detected as MacBookAir6,1
  -h, --help  this help

Wi-Fi (Broadcom) on kernel 6.16+ is separate:  sudo broadcom/fix.sh
EOF
}

status() {
  log "Current state (read-only)"
  local f=/etc/default/grub nm wl
  # awk consumes all of lsmod, so the producer isn't SIGPIPE'd under pipefail.
  wl=$(lsmod | awk '$1=="wl"{print "loaded"; exit}'); wl=${wl:-"NOT loaded"}
  nm=$(systemctl is-enabled NetworkManager-wait-online.service 2>/dev/null) || true; nm=${nm:-"?"}
  printf '  %-24s %s\n' "kernel"          "$(uname -r)"
  printf '  %-24s %s\n' "model"           "$(cat /sys/class/dmi/id/product_name 2>/dev/null || echo '?')"
  printf '  %-24s %s\n' "wl driver"       "$wl"
  printf '  %-24s %s\n' "sleep state"     "$(cat /sys/power/mem_sleep 2>/dev/null || echo '?')"
  printf '  %-24s %s\n' "grub acpi_osi"   "$(grep -q 'acpi_osi=!Darwin' "$f" 2>/dev/null && echo yes || echo NO)"
  printf '  %-24s %s\n' "grub deep sleep" "$(grep -q 'mem_sleep_default=deep' "$f" 2>/dev/null && echo yes || echo NO)"
  printf '  %-24s %s\n' "intel_backlight" "$([[ -d /sys/class/backlight/intel_backlight ]] && echo present || echo 'absent (needs acpi_osi)')"
  printf '  %-24s %s\n' "tlp"             "$(dpkg -s tlp >/dev/null 2>&1 && echo installed || echo 'NOT installed')"
  printf '  %-24s %s\n' "zram-config"     "$(dpkg -s zram-config >/dev/null 2>&1 && echo installed || echo 'NOT installed')"
  printf '  %-24s %s\n' "NM-wait-online"  "$nm"
}

ACTION=run
declare -a STEPS=()
while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run) DRY_RUN=1 ;;
    --force)   FORCE=1 ;;
    --all)     STEPS=(grub tlp zram boot) ;;
    --grub)    STEPS+=(grub) ;;
    --tlp)     STEPS+=(tlp) ;;
    --zram)    STEPS+=(zram) ;;
    --boot)    STEPS+=(boot) ;;
    --status)  ACTION=status ;;
    -h|--help) usage; exit 0 ;;
    *)         err "unknown option: $1"; usage; exit 1 ;;
  esac
  shift
done

if [[ "$ACTION" == status ]]; then status; exit 0; fi

# No steps chosen -> default to all.
[[ ${#STEPS[@]} -eq 0 ]] && STEPS=(grub tlp zram boot)

need_root
check_model
command -v apt-get >/dev/null || { err "apt-get not found; this targets Mint/Ubuntu."; exit 1; }

for s in "${STEPS[@]}"; do
  case "$s" in
    grub) apply_grub ;;
    tlp)  apply_tlp ;;
    zram) apply_zram ;;
    boot) apply_boot ;;
  esac
done

log "Done. Reboot, then re-check with: ./bootstrap.sh --status"
echo "    Brightness is the biggest battery lever — drop it once intel_backlight is back."
