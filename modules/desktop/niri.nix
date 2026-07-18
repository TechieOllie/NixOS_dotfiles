{ config, lib, ... }:
lib.mkIf config.features.niri {
  # Package + Wayland session entry only, via upstream's programs.niri
  # module. Greetd wiring lives in modules/desktop/greetd.nix, and user
  # config in home/niri.nix (not created yet) — this module is the
  # system-level half only, per the guide's Niri split.
  programs.niri.enable = true;
}
