# User-level Ghostty config. No system half. Merges the operator's live
# ~/.config/ghostty/config and ~/.config/ghostty/config.ghostty (the
# latter was never actually loaded under that filename, but its settings
# read like intended additions) into the one real config Home Manager
# manages.
#
# Deliberately does NOT set programs.ghostty.themes.noctalia (or manage
# ~/.config/ghostty/themes/noctalia in any way) — that file is Noctalia
# v5's own runtime-generated output (its "ghostty" template, confirmed by
# reading assets/templates/builtin.toml + ghostty/apply.sh in the
# noctalia flake input directly), regenerated whenever the wallpaper /
# palette changes. Managing it here would immediately go stale and
# conflict with Noctalia's own writes — the same class of conflict
# already fixed once for niri/noctalia.kdl. See home/noctalia.nix, where
# "ghostty" is added to theme.templates.builtin_ids to keep this in sync
# automatically instead.
{ pkgs, ... }:
let
  opacity = import ./transparency.nix;
in
{
  programs.ghostty = {
    enable = true;
    package = pkgs.ghostty;

    settings = {
      "font-family" = "JetBrainsMono Nerd Font";
      theme = "noctalia";
      "background-opacity" = opacity;
      "shell-integration-features" = "ssh-env,ssh-terminfo";
    };
  };
}
