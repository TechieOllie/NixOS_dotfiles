# User-level Yazi (terminal file manager). No system half — pure user
# tool, own small file (one responsibility per module), matching the
# home/starship.nix / home/lazygit.nix precedent. home/neovim.nix's
# yazi.nvim plugin is one consumer of this, not the reason it's installed.
#
# Theming is left entirely to Noctalia (home/noctalia.nix's community_ids:
# "yazi" — one cached catalog entry covers both the flavor and tmTheme
# templates it defines), which writes ~/.config/yazi/flavors/noctalia.yazi/
# and activates it in ~/.config/yazi/theme.toml. So this module must never
# set programs.yazi.theme (or settings — Home Manager writes each file only
# when its option is non-empty): theme.toml stays Noctalia's, and only
# keymap.toml is Nix-managed, which no template touches.
#
# The zsh integration adds a `y` wrapper (the 26.05 stateVersion default
# name) that leaves the shell in whatever directory Yazi was quit in —
# plain `yazi` can't change its parent shell's directory.
#
# Self-gates on osConfig.features.workstation: this is part of the
# operator's personal terminal environment, wanted only on machines they
# actually work on. inotmac is not one — ol holds an admin account there
# and nothing else — so the whole toolkit stays off it. Zsh and Starship
# are deliberately *not* on this flag: a login shell that behaves the way
# its owner expects is worth having even on a machine visited only to fix
# something.
{
  config,
  lib,
  osConfig,
  ...
}:
let
  dirs = config.programs.zsh.dirHashes;

  # `g` chords for the same directories home/zsh.nix names. Yazi's own
  # defaults already cover `g h` (home), `g c` (~/.config) and
  # `g d` (~/Downloads), so only the rest are added, on keys it leaves free.
  bookmark = key: name: {
    on = [
      "g"
      key
    ];
    run = "cd ${dirs.${name}}";
    desc = "Go to ~${name}";
  };
in
lib.mkIf osConfig.features.workstation {
  programs.yazi = {
    enable = true;
    keymap.mgr.prepend_keymap = [
      (bookmark "." "dots")
      (bookmark "p" "proj")
      (bookmark "D" "docs")
      (bookmark "s" "stor")
    ];
  };
}
