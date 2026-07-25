# Package only. The operator's real Obsidian config (~/.config/obsidian/
# obsidian.json) only ever holds a vault path
# (/home/ol/Documents/Notes on the-entertaining-nios-laptop) — genuinely
# machine-specific runtime state pointing at a vault that doesn't exist on
# this host, not a declarative preference to port. Same treatment as Zen
# Browser's profile and VS Code's Settings Sync: out of scope for Nix.
# pkgs.obsidian is unfree (custom license) — allowed via
# modules/desktop/unfree.nix.
#
# Theming: Noctalia's official "obsidian" community template discovers
# every local vault (any ".obsidian" directory under $HOME, confirmed by
# reading its own apply.sh) and writes/enables a CSS snippet inside each
# one's own snippets/ folder — added to home/noctalia.nix's community_ids.
# No conflict: nothing here manages any vault content.
#
# Self-gates on osConfig.features.niri, same convention as home/vscode.nix.
{
  pkgs,
  lib,
  osConfig,
  ...
}:
lib.mkIf osConfig.features.niri {
  home.packages = [ pkgs.obsidian ];
}
