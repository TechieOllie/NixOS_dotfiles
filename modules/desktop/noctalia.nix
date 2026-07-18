# Gated on config.features.niri like greetd.nix — Noctalia Shell is a
# niri-companion bar/shell, not useful without a compositor, and niri is
# the only one this repo offers so far.
{ config, lib, noctalia, ... }:
{
  imports = [ noctalia.nixosModules.default ];

  config = lib.mkIf config.features.niri {
    programs.noctalia.enable = true;

    # Wired individually rather than via programs.noctalia.recommendedServices
    # (which would also force Bluetooth on for every niri host) — this keeps
    # hardware.bluetooth.enable gated on config.features.bluetooth like the
    # architecture intends, currently false everywhere.
    services.upower.enable = true;
    services.power-profiles-daemon.enable = true;

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
