# Star Citizen, through its RSI Launcher, from the nix-citizen flake — the
# Linux Users Group's own setup (wine-astral, DXVK/VKD3D, the launcher's
# install script) done declaratively, with nothing hand-installed through
# Lutris or the LUG helper.
#
# Desktop only, on its own flag rather than riding features.gaming: it is
# one game, its install is ~100G, and theseus's integrated GPU isn't a
# machine to fly it on.
{
  config,
  lib,
  nix-citizen,
  ...
}:
{
  # Imported here, in the one module that consumes it, like chaotic and
  # millennium in steam.nix: only a host that imports this file carries the
  # flake. The module itself does nothing until programs.rsi-launcher.enable.
  imports = [ nix-citizen.nixosModules.StarCitizen ];

  config = lib.mkIf config.features.starCitizen {
    programs.rsi-launcher = {
      enable = true;

      # Take rsi-launcher and wine-astral from nix-citizen's own package
      # set rather than overlaying them onto ours. Overlaid, they would be
      # built against this repo's nixpkgs, miss the cache below and
      # compile Wine from source. The trade-off is the claude-code one in
      # reverse: those packages are evaluated with nix-citizen's own
      # `allowUnfree`, outside modules/system/unfree.nix.
      includeOverlay = false;

      # Defaults kept on purpose, so they are stated rather than implied:
      # - the runner is wine-astral, not umu + GE-Proton (umu.enable),
      #   because it is what the LUG tests Star Citizen against;
      # - the prefix lives at ~/Games/rsi-launcher, on the @games
      #   subvolume, so hourly /home snapshots never pin the game files;
      # - setLimits raises vm.max_map_count to 16777216 (the one LUG
      #   prerequisite this machine didn't already meet; the open-file
      #   limit is already 524288) and installs lug-helper's udev rules
      #   for joysticks;
      # - enableNTsync just adds "ntsync" to kernelModules, which
      #   modules/hardware/ntsync.nix already does.
    };

    # Without this the launcher's Wine build comes from source. Same key
    # and URL upstream's README publishes.
    nix.settings = {
      substituters = [ "https://nix-citizen.cachix.org" ];
      trusted-public-keys = [
        "nix-citizen.cachix.org-1:lPMkWc2X8XD4/7YPEEwXKKBg+SVbYTVrAaLA2wQTKCo="
      ];
    };
  };
}
