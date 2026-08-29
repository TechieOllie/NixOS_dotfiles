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
# The stock app set is otherwise kept as-is, per the operator's own choice:
# GNOME's defaults already cover the document viewer, camera, scanner, image
# viewer, audio player, video player and calculator, which is why this host
# declares none of them itself. Only Epiphany is excluded (see below), since
# Chrome replaces it outright rather than sitting beside it.
{
  config,
  lib,
  pkgs,
  ...
}:
lib.mkIf config.features.gnome {
  services.displayManager.gdm.enable = true;
  services.desktopManager.gnome.enable = true;

  # Epiphany (GNOME Web) is dropped: modules/programs/chrome.nix installs
  # Chrome and claims the browser MIME defaults on this host, so shipping a
  # second browser only offers a choice nobody asked for — and one that
  # would otherwise sit in the app grid looking like the default. Nothing
  # else in GNOME's default set is excluded; the rest is the stock install
  # the operator asked to keep.
  environment.gnome.excludePackages = [ pkgs.epiphany ];
}
