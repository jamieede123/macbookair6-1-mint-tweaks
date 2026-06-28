# Broadcom `wl` driver fix for kernel 6.16 / 6.17

The MacBookAir6,1 ships a Broadcom **BCM4360** (`14e4:43a0`) that needs the
proprietary `wl` driver from `broadcom-sta`. That driver has had no meaningful
upstream release in years and **fails to build on kernel 6.16+**, so a routine
`apt upgrade` that pulls in 6.17 ends with the kernel packages half-configured
and no Wi-Fi after a reboot into the new kernel.

`broadcom-sta-6.16-6.17.patch` fixes four breakages, each behind a
`LINUX_VERSION_CODE` guard so the driver still builds on older kernels (6.14):

1. **Makefile** — `$(src)` → `$(M)` for include paths, and the deprecated
   `EXTRA_CFLAGS` / `EXTRA_LDFLAGS` → `ccflags-y` / `ldflags-y` (6.17 ignores the
   old spellings for external modules).
2. **Timer API** (`wl_linux.c`) — `from_timer()` → `timer_container_of()` and
   `del_timer()` → `timer_delete()` (renamed in 6.16).
3. **cfg80211 ops** (`wl_cfg80211_hybrid.c`) — `set_wiphy_params`, `set_tx_power`
   and `get_tx_power` gained an `int radio_idx` parameter in 6.16.

## Usage

```bash
sudo apt install broadcom-sta-dkms     # if not already present
sudo ./fix.sh                          # patch, build, install, clear dpkg
```

`fix.sh` is idempotent and saves the originals as `*.orig`.

## The caveat

The patch edits live in `/usr/src/broadcom-sta-*`. They survive **kernel**
upgrades (DKMS rebuilds from that source), but **not** a `broadcom-sta-dkms`
package upgrade, which overwrites the source. Just re-run `sudo ./fix.sh` after
that happens.

Full write-up: <https://jamieede.com/posts/broadcom-sta-wl-driver-kernel-6-17/>
