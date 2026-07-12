{ config, lib, ... }:
lib.mkIf config.features.niri {
  # Package + Wayland session entry only, via upstream's programs.niri
  # module. No greetd wiring yet (that's modules/desktop/greetd.nix, not
  # created yet) and no user config (that's home/niri.nix) — this module
  # is the system-level half only, per the guide's Niri split.
  programs.niri.enable = true;
}
