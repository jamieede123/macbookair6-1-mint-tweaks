#!/usr/bin/env bash
# Shared helpers for macbookair6-1-mint-tweaks. Sourced by bootstrap.sh.

# Colours only when stdout is a terminal.
if [[ -t 1 ]]; then
  C_RESET=$'\e[0m'; C_OK=$'\e[32m'; C_WARN=$'\e[33m'; C_ERR=$'\e[31m'; C_DIM=$'\e[2m'; C_B=$'\e[1m'
else
  C_RESET=; C_OK=; C_WARN=; C_ERR=; C_DIM=; C_B=
fi

DRY_RUN=${DRY_RUN:-0}
FORCE=${FORCE:-0}

log()  { printf '%s==>%s %s\n' "$C_B"   "$C_RESET" "$*"; }
ok()   { printf '  %s[ok]%s   %s\n' "$C_OK"   "$C_RESET" "$*"; }
warn() { printf '  %s[warn]%s %s\n' "$C_WARN" "$C_RESET" "$*"; }
err()  { printf '  %s[err]%s  %s\n' "$C_ERR"  "$C_RESET" "$*" >&2; }
skip() { printf '  %s[skip]%s %s\n' "$C_DIM"  "$C_RESET" "$*"; }

# run CMD...  — execute it, or just print it under --dry-run.
run() {
  if [[ "$DRY_RUN" == 1 ]]; then
    printf '  %s$ %s%s\n' "$C_DIM" "$*" "$C_RESET"
  else
    "$@"
  fi
}

need_root() {
  [[ "$DRY_RUN" == 1 ]] && return 0   # dry-run changes nothing, so root isn't needed
  if [[ ${EUID:-$(id -u)} -ne 0 ]]; then
    err "this step changes system files; run with sudo."
    exit 1
  fi
}

# Refuse to touch hardware-specific settings on the wrong machine unless --force.
check_model() {
  local model
  model=$(cat /sys/class/dmi/id/product_name 2>/dev/null || echo unknown)
  if [[ "$model" == "MacBookAir6,1" ]]; then
    ok "hardware: MacBookAir6,1"
    return 0
  fi
  warn "detected '$model', not MacBookAir6,1."
  if [[ "$FORCE" == 1 ]]; then
    warn "--force set, continuing anyway."
  else
    err "refusing to run on unrecognised hardware. Re-run with --force to override."
    exit 1
  fi
}

# backup_file PATH — copy to PATH.bak.YYYY-MM-DD once.
backup_file() {
  local f=$1 b
  b="$1.bak.$(date +%F)"
  [[ -e "$f" ]] || return 0
  if [[ -e "$b" ]]; then skip "backup exists: $b"; return 0; fi
  run cp -a "$f" "$b" && ok "backed up $f -> $b"
}
