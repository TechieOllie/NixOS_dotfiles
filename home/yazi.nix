# User-level Yazi (terminal file manager). No system half — pure user
# tool, own small file (one responsibility per module), matching the
# home/starship.nix / home/lazygit.nix precedent. Already on this repo's
# planned general terminal-tool stack (alongside eza/bat/fd/ripgrep/fzf/
# zoxide/btop) independent of Neovim — home/neovim.nix's yazi.nvim plugin
# is one consumer of this, not the reason it's installed. No settings
# configured yet beyond enabling it; Noctalia themes it live (see
# home/noctalia.nix's community_ids: "yazi" + "yazi-syntax"), writing to
# ~/.config/yazi/flavors/noctalia.yazi/ and activating it in
# ~/.config/yazi/theme.toml -- deliberately not Nix-managed here at all,
# so there's nothing for Noctalia's runtime writes to conflict with.
{ pkgs, ... }:
{
  home.packages = [ pkgs.yazi ];
}
