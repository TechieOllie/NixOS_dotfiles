# Machine-agnostic entry point: every host's Home Manager user points here
# (see lib/mkHost.nix). Phase 3+ modules (home/niri.nix, home/ghostty.nix,
# ...) get imported from this file as they're written.
{ vars, ... }:
{
  home.username = vars.user.name;
  home.homeDirectory = "/home/${vars.user.name}";

  # Pinned at first Home Manager activation, same rule as system.stateVersion
  # in each host's default.nix: leave untouched after this.
  home.stateVersion = "26.05";

  programs.home-manager.enable = true;
}
