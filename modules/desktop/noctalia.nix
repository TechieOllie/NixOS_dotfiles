# Gated on config.features.niri like greetd.nix — Noctalia Shell is a
# niri-companion bar/shell, not useful without a compositor, and niri is
# the only one this repo offers so far.
{ config, lib, noctalia, ... }:
{
  imports = [ noctalia.nixosModules.default ];

  config = lib.mkIf config.features.niri {
    programs.noctalia.enable = true;

    # Enables NetworkManager (already on unconditionally), Bluetooth,
    # UPower, and a power-profile service — every host that runs Noctalia
    # wants all of these, so there's no independent config.features.bluetooth
    # flag to keep in sync (removed from modules/options.nix). Also avoids
    # hand-tracking what Noctalia actually needs as that list evolves
    # upstream.
    programs.noctalia.recommendedServices.enable = true;

    # Lets Nix substitute prebuilt Noctalia binaries instead of building
    # this native Wayland/OpenGL project from source on every host.
    nix.settings = {
      substituters = [ "https://noctalia.cachix.org" ];
      trusted-public-keys = [
        "noctalia.cachix.org-1:pCOR47nnMEo5thcxNDtzWpOxNFQsBRglJzxWPp3dkU4="
      ];
    };
  };
}
