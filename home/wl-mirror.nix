# Screen mirroring for niri. Noctalia v5 has no built-in equivalent of v4's
# mirror-mirror plugin, so the Mod+P bind in home/niri/cfg/keybinds.kdl
# drives the `elijaharch/wl-screen-mirror` community plugin instead
# (declared in home/noctalia.nix's plugins.enabled). That plugin is only a
# control panel — it shells out to wl-mirror, which is not something
# Noctalia fetches, so the binary has to come from here or the panel's
# buttons do nothing.
#
# The package also ships `wl-present`, an interactive wrapper that wants
# bemenu/slurp/wl-copy on PATH; deliberately not catered for, since the
# plugin's panel replaces exactly that role.
#
# Self-gates on osConfig.features.niri, same convention as the other
# session-only modules here — mirroring one Wayland output onto another
# means nothing without a compositor.
#
# Verified live on the desktop 2026-08-30: Mod+P opens the plugin's
# controls panel and mirroring works from it.
{
  pkgs,
  lib,
  osConfig,
  ...
}:
lib.mkIf osConfig.features.niri {
  home.packages = [ pkgs.wl-mirror ];
}
