# eza, the `ls` replacement. Home Manager's zsh integration aliases
# ls/ll/la/lt/lla to it; home/zsh.nix keeps plain-`ls` versions of l/ll/la
# for hosts where this module is off, and yields to these wherever it is on.
# No Noctalia template exists for eza, and none is needed: it colours with
# the terminal's own ANSI palette, which Ghostty's template already themes.
# Self-gates on osConfig.features.workstation, like the rest of the
# operator's terminal environment.
{ lib, osConfig, ... }:
lib.mkIf osConfig.features.workstation {
  programs.eza = {
    enable = true;
    icons = "auto";
    git = true;
    extraOptions = [ "--group-directories-first" ];
  };

  # The operator's own short alias, kept from the original .zshrc.
  programs.zsh.shellAliases.l = "eza";
}
