# Bare package only, deliberately no configuration yet — this repo's zsh
# config (home/zsh.nix) sets EDITOR/VISUAL=nvim and a `nv` alias, which
# need the binary to actually exist. The full Neovim setup (plugins, LSP,
# etc.) is its own separate, later planning session, not part of this
# terminal-environment pass — same treatment as Git identity and Ghostty.
{ pkgs, ... }:
{
  home.packages = [ pkgs.neovim ];
}
