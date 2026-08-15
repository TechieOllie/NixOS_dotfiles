# Xbox controller support. Both of these are out-of-tree kernel modules,
# which is why they're a NixOS-level concern and not something a user-level
# package could provide: they build against the running kernel, so they're
# also the one part of the gaming stack that can break on a kernel bump.
{ config, lib, ... }:
lib.mkIf config.features.gaming {
  # Wired controllers and the Xbox Wireless Adapter dongle. The upstream
  # module handles the firmware extraction that xone otherwise needs done
  # by hand.
  hardware.xone.enable = true;

  # Bluetooth-connected controllers (Xbox One S and later). Distinct
  # hardware path from xone despite the overlapping name — the two coexist
  # and cover the wireless and dongle cases respectively, so both are on.
  hardware.xpadneo.enable = true;
}
