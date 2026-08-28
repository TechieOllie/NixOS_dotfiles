# GNOME desktop — the alternate desktop stack to modules/desktop/{niri,greetd,
# noctalia,theming,nautilus}.nix, which are all gated on config.features.niri
# and therefore inert here. Gated on its own config.features.gnome so the two
# stacks can never both apply to one host by accident.
#
# At this repo's pinned nixpkgs revision GNOME/GDM have been fully decoupled
# from services.xserver — the option paths are services.desktopManager.gnome
# and services.displayManager.gdm, and neither pulls in services.xserver.enable
# (confirmed by reading nixos/modules/services/{desktop-managers/gnome.nix,
# display-managers/gdm.nix} at this pin, not assumed from older docs/tutorials
# that still show the xserver-nested paths).
#
# Deliberately no environment.gnome.excludePackages: the stock app set is
# kept as-is per the operator's own choice, rather than trimming apps this
# repo happens to replace elsewhere (Papers/Celluloid/Decibels/Chrome are
# additions, not replacements of anything excluded here). gnome-calculator in
# particular needs no separate package entry — it's already part of GNOME's
# own default set (nixos/modules/services/desktop-managers/gnome.nix), so
# adding it explicitly would just be a redundant duplicate.
{ config, lib, ... }:
lib.mkIf config.features.gnome {
  services.displayManager.gdm.enable = true;
  services.desktopManager.gnome.enable = true;
}
