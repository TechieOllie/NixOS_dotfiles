# Gated on config.features.desktop like greetd.nix — Noctalia Shell is the
# bar/shell half of the Noctalia desktop, the same under niri or Umbriel, and
# not useful without one of them.
{
  config,
  lib,
  noctalia,
  ...
}:
{
  imports = [ noctalia.nixosModules.default ];

  config = lib.mkIf config.features.desktop {
    programs.noctalia.enable = true;

    # Enables NetworkManager (already on unconditionally), Bluetooth,
    # UPower, and a power-profile service — every host that runs Noctalia
    # wants all of these, so there's no independent config.features.bluetooth
    # flag to keep in sync (removed from modules/options.nix). Also avoids
    # hand-tracking what Noctalia actually needs as that list evolves
    # upstream.
    programs.noctalia.recommendedServices.enable = true;

    # rtkit is deliberately off, though recommendedServices leaves PipeWire
    # logging `RTKit error: ServiceUnknown`. Turning it on (2026-11-05) gave
    # WirePlumber realtime data loops with a 0 µs RLIMIT_RTTIME, and the
    # kernel SIGKILLed it six times in 40 s while a Bluetooth headset
    # connected. See docs/decisions.md, 2026-11-05, before re-enabling.

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
