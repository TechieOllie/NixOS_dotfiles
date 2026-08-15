# Heroic Games Launcher — Epic, GOG and Amazon libraries, the half of the
# game library Steam doesn't cover. Purely user-level (no service, no
# system integration), so unlike modules/programs/steam.nix it lives
# entirely here, matching the other Phase 6 applications.
{
  osConfig,
  lib,
  pkgs,
  ...
}:
lib.mkIf osConfig.features.gaming {
  home.packages = [
    pkgs.heroic

    # Not a launcher of its own, and not optional in practice: umu is the
    # runtime Heroic hands its Proton games to. Steam runs Proton inside
    # its own container (pressure-vessel + the Steam Linux Runtime); Heroic
    # on its own runs Proton bare against host libraries, which is the
    # usual cause of "runs under Steam, breaks under Heroic". umu gives
    # Heroic that same containerised runtime, so a game behaves the same
    # either side.
    pkgs.umu-launcher
  ];
}
