# macbookair6-1-mint-tweaks

Battery and performance tweaks for an 11-inch MacBook Air (mid-2013,
`MacBookAir6,1`) running Linux Mint rather than macOS.

A capable little laptop a decade on, with two catches on a fresh Linux install:
its Broadcom Wi-Fi stops building on kernel 6.17, and the battery and
responsiveness need work. This is the set of changes that fixed each, with the
measurements — every one scripted, idempotent, reversible, and measured in the
right state.

The machine is a `MacBookAir6,1` (Haswell Core i5-4250U, 4 GB soldered RAM) on
Linux Mint 22.x / Ubuntu 24.04, kernel 6.14–6.17. The scripts refuse to run on
other hardware unless you pass `--force`.

---

## What this fixes

Two things make this machine awkward on a fresh Linux install:

1. **Wi-Fi dies on kernel 6.17.** The Air's Broadcom BCM4360 needs the
   proprietary `wl` driver, which hasn't built on a current kernel in years. An
   `apt upgrade` to 6.17 ends with half-configured kernel packages and no
   wireless after reboot. → fixed by [`broadcom/fix.sh`](broadcom/).
2. **Battery life and responsiveness are poor out of the box** — light sleep
   that drains overnight, no power management, swap thrashing the SSD on 4 GB,
   and a slow boot. → fixed by [`bootstrap.sh`](bootstrap.sh).

### Measured results

All readings on battery, idle, from the write-ups linked at the bottom.

| Lever | Before | After |
| --- | --- | --- |
| **Brightness** 100% → 40% | ~10.4 W (~4.0 h) | **~8.6 W (~4.7 h)** |
| **Standby** (lid closed) | `s2idle`, 10–20%/night | **`deep`, a trickle** |
| **Swap on 4 GB** | SSD swapfile, stutters | **zram, ~2.9:1 in RAM** |
| **Boot** | 22.7 s | **~10 s faster** (NM-wait-online masked) |
| **Wi-Fi on kernel 6.17** | does not build | **builds, signed, loads** |

Brightness is the single biggest dial — it saved more than Wi-Fi, PCIe and audio
tuning combined — and it only becomes available once `acpi_osi=!Darwin` brings
back the `intel_backlight` interface, which `--grub` handles.

---

## Quick start

```bash
git clone https://github.com/jamieede123/macbookair6-1-mint-tweaks.git
cd macbookair6-1-mint-tweaks

# See what's already done vs missing (read-only, no sudo):
./bootstrap.sh --status

# Preview every change without touching anything:
sudo ./bootstrap.sh --all --dry-run

# Apply the battery + performance tweaks:
sudo ./bootstrap.sh --all

# If you're on kernel 6.16+ and Wi-Fi is broken, fix the Broadcom driver:
sudo ./broadcom/fix.sh

# Reboot, then verify:
./bootstrap.sh --status
```

You can also run steps individually: `--grub`, `--tlp`, `--zram`, `--boot`.

---

## What each step does

### `--grub` — deep sleep + fine brightness control
Adds two kernel parameters in `/etc/default/grub`:

- `mem_sleep_default=deep` — suspend-to-RAM (S3) instead of light `s2idle`, so a
  closed lid sips power overnight instead of shedding 10–20%.
- `acpi_osi=!Darwin` — stops the firmware pretending it's macOS, which exposes
  the `intel_backlight` interface (0–2777) instead of coarse `acpi_video0`
  (0–100). This is what makes the brightness lever usable.

After reboot:
```console
$ cat /sys/power/mem_sleep
s2idle [deep]
$ ls /sys/class/backlight/
intel_backlight
$ echo 1110 | sudo tee /sys/class/backlight/intel_backlight/brightness   # ~40%
```

### `--tlp` — power profiles that switch with the cable
Installs [TLP](https://linrunner.de/tlp/) and sets two battery-only savings,
leaving AC at full performance:

```console
$ sudo tlp bat && iw dev wlp3s0 get power_save
Power save: on
$ cat /sys/module/pcie_aspm/parameters/policy
default performance powersave [powersupersave]
```

### `--zram` — compressed swap in RAM
Installs `zram-config`. On 4 GB this is the most noticeable responsiveness
change: swapped pages are compressed and kept in RAM instead of hitting the SSD.

```console
$ zramctl
NAME       ALGORITHM DISKSIZE  DATA  COMPR  TOTAL STREAMS MOUNTPOINT
/dev/zram0 lzo-rle       1.9G  1.8G 620.6M 638.3M       4 [SWAP]
$ swapon --show
NAME       TYPE      SIZE   USED PRIO
/dev/zram0 partition 1.9G   1.9G    5     # filled first
/swapfile  file      3.9G 365.2M   -2     # only the overflow spills to SSD
```

### `--boot` — stop waiting on the network
Masks `NetworkManager-wait-online.service`, which otherwise holds the boot ~10 s
for no benefit on a desktop session.

```console
$ systemd-analyze blame | head -1
10.815s NetworkManager-wait-online.service     # before: masked after
```

### `broadcom/fix.sh` — Wi-Fi on kernel 6.16/6.17
Patches `broadcom-sta` to build against the renamed timer API and the new
`cfg80211` radio-index parameters, then rebuilds and installs the module and
clears the broken package state. See [broadcom/README.md](broadcom/) for the
gory details. Result:

```console
$ dkms status | grep broadcom
broadcom-sta/6.30.223.271, 6.14.0-37-generic, x86_64: installed
broadcom-sta/6.30.223.271, 6.17.0-35-generic, x86_64: installed
$ lsmod | grep -E '^wl|cfg80211'
wl                   6492160  0
cfg80211             1462272  1 wl
```

---

## Reversing changes

Everything is undoable:

- **grub** — restore `/etc/default/grub.bak.<date>`, then `sudo update-grub`.
- **TLP** — `sudo apt remove tlp tlp-rdw` (your `/etc/tlp.conf.bak.<date>` is kept).
- **zram** — `sudo apt remove zram-config`.
- **boot** — `sudo systemctl unmask NetworkManager-wait-online.service`.
- **Broadcom** — originals are saved as `*.orig` under `/usr/src/broadcom-sta-*`.

## Notes & caveats

- **Secure Boot:** the Broadcom module is MOK-signed during the build, so it
  loads with Secure Boot enabled (you'll have enrolled a MOK key already if
  DKMS modules worked before).
- **Deep sleep:** a few Macs don't resume cleanly from `deep`. If yours hangs on
  resume, remove `mem_sleep_default=deep` from grub and `update-grub`.
- **`broadcom-sta-dkms` upgrades** overwrite the patched source — just re-run
  `sudo ./broadcom/fix.sh`.
- This targets the `MacBookAir6,1` specifically. Other Airs have different
  wireless chips and backlight quirks; `--force` lets you try at your own risk.

## Credits

Distilled from two write-ups, which carry the full reasoning and measurements:

- [Patching the Broadcom wl driver for kernel 6.17](https://jamieede.com/posts/broadcom-sta-wl-driver-kernel-6-17/)
- [Making an old MacBook Air last on Linux: battery and performance](https://jamieede.com/posts/macbook-air-battery-performance-linux/)

The approach throughout is the same: change one thing, measure in the right
state, keep what the meter rewards.

MIT licensed. PRs welcome — especially confirmations on newer kernels or other
`MacBookAir6,x` models.
