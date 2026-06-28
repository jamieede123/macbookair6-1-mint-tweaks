#!/usr/bin/env bash
# Deep suspend-to-RAM + Intel backlight, via the kernel command line.
#   mem_sleep_default=deep  -> low standby drain with the lid closed
#   acpi_osi=!Darwin        -> exposes intel_backlight (fine brightness control)

apply_grub() {
  need_root
  log "Deep sleep + Intel backlight (grub kernel cmdline)"
  local g=/etc/default/grub
  local cur add=()
  cur=$(grep '^GRUB_CMDLINE_LINUX_DEFAULT=' "$g" | head -1)

  grep -q 'mem_sleep_default=deep' <<<"$cur" || add+=("mem_sleep_default=deep")
  grep -q 'acpi_osi=!Darwin'       <<<"$cur" || add+=("acpi_osi=!Darwin")

  if [[ ${#add[@]} -eq 0 ]]; then
    skip "cmdline already has both parameters"
    return 0
  fi

  backup_file "$g"
  run sed -i "s|^\(GRUB_CMDLINE_LINUX_DEFAULT=\"[^\"]*\)\"|\1 ${add[*]}\"|" "$g"
  ok "added: ${add[*]}"
  run update-grub
  warn "reboot needed for these to take effect"
}
