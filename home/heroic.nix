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

  # The same proton-cachyos build Steam gets from
  # programs.steam.extraCompatPackages. That option only exports
  # STEAM_EXTRA_COMPAT_TOOLS_PATHS into Steam's own FHS environment, so
  # Heroic — a separate app with its own search paths — never sees it, and
  # the compatibility dropdown offers only whatever was downloaded by hand.
  #
  # Heroic scans ~/.config/heroic/tools/proton/<name>/proton (plus Steam's
  # compatibilitytools.d, which this repo deliberately doesn't populate:
  # extraCompatPackages means no such directory exists). Linking the store
  # path in under a name of our choosing is the declarative equivalent of
  # Heroic's own downloader, which writes real directories there — the
  # app-owned mutable state the standing gotchas are about.
  #
  # The link target is $out/bin, not $out: that's where the Proton tool
  # tree (proton, toolmanifest.vdf, files/) actually lives in this
  # derivation.
  home.file.".config/heroic/tools/proton/proton-cachyos".source = "${pkgs.proton-cachyos}/bin";
}
