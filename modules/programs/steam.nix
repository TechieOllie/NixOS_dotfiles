# Steam, patched by Millennium, running games under CachyOS's Proton fork.
# The system half of the gaming stack: the launcher itself, its runtime,
# and the graphics support it needs. Heroic and umu-launcher — ordinary
# user-level apps with no system service — live in home/heroic.nix, the
# same split modules/desktop/niri.nix draws against home/niri.nix.
{
  config,
  lib,
  pkgs,
  chaotic,
  millennium,
  ...
}:
{
  imports = [
    # Both are imported here, in the one module that consumes them, rather
    # than in lib/mkHost.nix — a host that never sets features.gaming
    # shouldn't carry either flake's overlay. Same rule the desktop modules
    # follow for noctalia.
    #
    # chaotic.nixosModules.default is the "unstable" entry point (this repo
    # tracks nixos-unstable); it brings the nyx overlay, the flake registry
    # entry, and — the part that matters — the nyx binary cache, without
    # which linuxPackages_cachyos would be compiled from source here.
    chaotic.nixosModules.default
  ];

  config = lib.mkIf config.features.gaming {
    # Millennium ships an overlay rather than a NixOS module: it exports a
    # `millennium-steam` that is upstream's own steam derivation overridden
    # with Millennium's bootstrap shim preloaded, so it drops straight into
    # programs.steam.package below.
    nixpkgs.overlays = [ millennium.overlays.default ];

    programs.steam = {
      enable = true;

      # Steam with Millennium's loader injected. Note this derivation comes
      # from Millennium's *own* pinned nixpkgs, not this repo's — see the
      # `millennium` input's comment in flake.nix for why that pin can't be
      # made to follow ours.
      package = pkgs.millennium-steam;

      # proton-cachyos over stock Proton or Proton GE, by operator choice:
      # CachyOS's fork carries the scheduler and Wine patches that machine
      # is already tuned around. It appears in Steam's per-game
      # compatibility-tool dropdown once selected.
      #
      # Declaring it here rather than installing protonup-qt/protonplus is
      # deliberate: those are GUI downloaders that write Proton builds into
      # ~/.steam by hand, i.e. exactly the app-owned mutable state that
      # this repo's standing gotchas are about.
      extraCompatPackages = [ pkgs.proton-cachyos ];

      # Winetricks, taught to find Steam's Proton prefixes. This flag is
      # the only correct way to install it: it doesn't merely add the
      # package, it installs it *overridden* with the same extraCompatPaths
      # computed from extraCompatPackages above, baked in as
      # STEAM_EXTRA_COMPAT_TOOLS_PATHS via makeWrapper. Protontricks reads
      # that variable to find compat tools, and it runs outside Steam's FHS
      # environment — which is where the option's export normally stops —
      # so a plain pkgs.protontricks in home.packages finds no Proton at
      # all and fails with "Could not find configured Proton installation".
      protontricks.enable = true;

      # Steam's own in-home streaming and Remote Play Together need these
      # ports open; the option exists precisely so the port list doesn't
      # have to be transcribed into networking.firewall by hand.
      remotePlay.openFirewall = true;
      localNetworkGameTransfers.openFirewall = true;
    };

    # 32-bit graphics drivers. programs.steam turns this on itself, but
    # it's stated explicitly because it's a requirement of the whole
    # gaming stack rather than of Steam specifically — Heroic and anything
    # else running a 32-bit title through Proton needs it just as much, and
    # a future change to Steam's own module shouldn't silently take it away.
    hardware.graphics.enable32Bit = true;
  };
}
