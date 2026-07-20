# System-wide cursor/icon-theme packages — gated on config.features.niri
# like greetd.nix/noctalia.nix. noctalia-greeter runs outside any user's Home
# Manager profile (before login), so the packages Home Manager installs for
# the user session (home/cursor.nix, home/gtk.nix) aren't visible to it —
# installed system-wide too so greetd.nix's settings.cursor can reference
# Bibata-Modern-Classic by name, and so a system-wide Papirus icon set exists
# for the greeter itself.
{ config, lib, pkgs, ... }:
{
  config = lib.mkIf config.features.niri {
    environment.systemPackages = [
      pkgs.bibata-cursors
      pkgs.papirus-icon-theme
    ];
  };
}
