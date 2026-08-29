# User-level Yazi (terminal file manager). No system half — pure user
# tool, own small file (one responsibility per module), matching the
# home/starship.nix / home/lazygit.nix precedent. Already on this repo's
# planned general terminal-tool stack (alongside eza/bat/fd/ripgrep/fzf/
# zoxide/btop) independent of Neovim — home/neovim.nix's yazi.nvim plugin
# is one consumer of this, not the reason it's installed. Package only, no
# programs.yazi settings at all; Noctalia themes it live (see
# home/noctalia.nix's community_ids: "yazi" — one cached catalog entry
# covers both the flavor and tmTheme templates it defines), writing to
# ~/.config/yazi/flavors/noctalia.yazi/ and activating it in
# ~/.config/yazi/theme.toml -- deliberately not Nix-managed here at all,
# so there's nothing for Noctalia's runtime writes to conflict with.
# Self-gates on osConfig.features.workstation: this is part of the
# operator's personal terminal environment, wanted only on machines they
# actually work on. inotmac is not one — ol holds an admin account there
# and nothing else — so the whole toolkit stays off it. Zsh and Starship
# are deliberately *not* on this flag: a login shell that behaves the way
# its owner expects is worth having even on a machine visited only to fix
# something.
{
  pkgs,
  lib,
  osConfig,
  ...
}:
lib.mkIf osConfig.features.workstation {
  home.packages = [ pkgs.yazi ];
}
