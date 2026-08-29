# Google Chrome, system-wide on GNOME hosts.
#
# Deliberately NOT a Home Manager module, unlike every other app here. This
# repo wires Home Manager for exactly one user (lib/mkHost.nix, vars.user),
# so a home.packages entry reaches ol and nobody else — and inotmac is
# shared by four people who all need a browser. environment.systemPackages
# is the only profile every account is on.
#
# GNOME does ship Epiphany (GNOME Web) by default, which is why every other
# app this host once declared has been dropped; Chrome stays because it is
# not a duplicate of anything GNOME provides and was specifically asked for
# (sync/Widevine DRM, not just "a browser"). Setting it as the *default*
# browser is per-user state in GNOME Settings, not something declared here.
#
# Unfree: allow-listed in modules/system/unfree.nix at the NixOS level,
# which is where it has to happen — lib/mkHost.nix's useGlobalPkgs means
# Home Manager shares one already-finalized nixpkgs.config.
#
# The `--password-store=gnome-libsecret` workaround CLAUDE.md documents for
# VS Code under niri is moot here: Chromium/Chrome pick a password store by
# sniffing XDG_CURRENT_DESKTOP, and GNOME sets that correctly on its own.
{
  pkgs,
  lib,
  config,
  ...
}:
lib.mkIf config.features.gnome {
  environment.systemPackages = [ pkgs.google-chrome ];
}
