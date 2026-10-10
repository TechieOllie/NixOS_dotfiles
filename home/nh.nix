# nh, a front end for nixos-rebuild: `nh os switch` builds with a progress
# tree and shows a package diff of the new generation against the running
# one — and, given `--ask`, waits for confirmation before activating.
# `just switch` runs it that way. NH_FLAKE points at this host's own clone,
# so the flake argument can be left off when calling it by hand.
#
# Its own cleaner (programs.nh.clean) stays off: nix.gc in
# modules/system/nix.nix already owns garbage collection, and nh warns when
# both run.
#
# Self-gates on osConfig.features.workstation, like the rest of the
# operator's terminal environment — which also keeps it off inotmac, the
# one host with no ~/.dotfiles clone for NH_FLAKE to name.
{
  config,
  lib,
  osConfig,
  ...
}:
lib.mkIf osConfig.features.workstation {
  programs.nh = {
    enable = true;
    flake = "${config.home.homeDirectory}/.dotfiles";
  };
}
