# nix-index with a prebuilt database (the nix-index-database flake input),
# for three things:
#   - command-not-found: typing a missing command names the package that
#     provides it, through nix-index's own zsh hook (on by default once
#     programs.zsh is enabled).
#   - `nix-locate <path>`: which package ships a given file.
#   - comma: `, <command>` runs a program from nixpkgs without installing it.
#
# This replaces oh-my-zsh's command-not-found plugin, which was listed in
# home/zsh.nix but never worked: it calls NixOS's own command-not-found
# helper, and programs.command-not-found is off on every host, because its
# database ships only with channels and this repo is flake-only.
#
# Gated on osConfig.features.workstation, like the rest of the operator's
# terminal environment — but by assigning the flag rather than wrapping the
# module in lib.mkIf, because the upstream module turns programs.nix-index
# on with mkDefault true merely by being imported. A mkIf that only ever
# says `true` would leave that default standing on inotmac.
{
  osConfig,
  nix-index-database,
  ...
}:
{
  imports = [ nix-index-database.homeModules.nix-index ];

  programs.nix-index.enable = osConfig.features.workstation;
  programs.nix-index-database.comma.enable = osConfig.features.workstation;
}
