# Browser for GNOME hosts. Niri hosts use Zen Browser (home/zen-browser.nix,
# features.niri-gated); this repo's one GNOME host (inotmac) wants Google
# Chrome specifically (operator's own choice — sync/Widevine DRM, not just
# "a browser"), so this is a separate module rather than widening Zen's own
# gate the way home/papers.nix's package half now does.
#
# Unfree: added to modules/system/unfree.nix's allow-list, which has to
# happen at the NixOS level rather than here — lib/mkHost.nix's
# useGlobalPkgs means Home Manager shares one pkgs instance whose
# nixpkgs.config is already finalized by the time this module evaluates
# (same reasoning as vscode/obsidian/steam there).
#
# The `--password-store=gnome-libsecret` workaround CLAUDE.md documents for
# VS Code under niri is moot here: Chromium/Chrome pick a password store by
# sniffing XDG_CURRENT_DESKTOP, and GNOME sets that correctly on its own
# (unlike niri, which advertises nothing GTK recognises) — confirmed by
# reading the same wrapper-detection logic CLAUDE.md's VS Code gotcha
# already traced, not re-guessed here. No override needed.
{
  pkgs,
  lib,
  osConfig,
  ...
}:
lib.mkIf osConfig.features.gnome {
  home.packages = [ pkgs.google-chrome ];
}
