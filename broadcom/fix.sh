#!/usr/bin/env bash
# Make the Broadcom 'wl' driver (broadcom-sta) build on kernel 6.16 / 6.17.
# Idempotent: safe to re-run. Re-run after any broadcom-sta-dkms upgrade,
# which overwrites /usr/src and reverts the fix.
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PATCH="$HERE/broadcom-sta-6.16-6.17.patch"

[[ ${EUID:-$(id -u)} -eq 0 ]] || { echo "run as root (sudo)"; exit 1; }

SRC=$(ls -d /usr/src/broadcom-sta-* 2>/dev/null | head -1 || true)
[[ -n "$SRC" ]] || {
  echo "broadcom-sta source not found."
  echo "Install it first:  sudo apt install broadcom-sta-dkms"
  exit 1
}
VER=$(basename "$SRC" | sed 's/^broadcom-sta-//')
KVER=$(uname -r)
echo "==> broadcom-sta $VER  ->  kernel $KVER"

KMAJ=$(echo "$KVER" | cut -d. -f1); KMIN=$(echo "$KVER" | cut -d. -f2)
if (( KMAJ < 6 || (KMAJ == 6 && KMIN < 16) )); then
  echo "Kernel $KVER is older than 6.16; the stock driver already builds. Nothing to do."
  exit 0
fi

# Apply the patch. --forward makes an already-patched tree a no-op rather than an error.
if patch -p1 --forward --dry-run -d "$SRC" <"$PATCH" >/dev/null 2>&1; then
  patch -p1 --forward --backup --suffix=.orig -d "$SRC" <"$PATCH"
  echo "patch applied (originals saved as *.orig)"
else
  echo "patch already applied (or partially) — proceeding to build"
fi

echo "==> dkms build + install"
dkms build  "broadcom-sta/$VER" -k "$KVER" --force
if ! dkms install "broadcom-sta/$VER" -k "$KVER" --force; then
  echo
  echo "!! BUILD FAILED. Last 40 lines of make.log:"
  tail -40 "/var/lib/dkms/broadcom-sta/$VER/build/make.log" 2>/dev/null || true
  echo
  echo "If the kernel is newer than this patch targets, a cfg80211/timer signature"
  echo "may have changed again. Open an issue with the errors above."
  exit 1
fi

# Clear any half-configured kernel packages left by the earlier failed hook.
dpkg --configure -a || true

echo
echo "Done:"
dkms status | grep broadcom-sta || true
echo "Reboot into the new kernel; Wi-Fi (wlp3s0) should come up with 'wl' loaded."
