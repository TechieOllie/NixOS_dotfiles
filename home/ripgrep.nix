# ripgrep as a general-purpose tool. It used to be installed only as a
# Neovim/Telescope prerequisite in home/neovim.nix, whose comment said to
# move it once it had a reason of its own; Telescope still finds it here.
#
# --smart-case through programs.ripgrep's config file (RIPGREP_CONFIG_PATH):
# case-insensitive unless the pattern contains a capital. Telescope passes
# the same flag itself, so the file changes nothing inside Neovim.
#
# Self-gates on osConfig.features.workstation, like the rest of the
# operator's terminal environment.
{ lib, osConfig, ... }:
lib.mkIf osConfig.features.workstation {
  programs.ripgrep = {
    enable = true;
    arguments = [ "--smart-case" ];
  };
}
