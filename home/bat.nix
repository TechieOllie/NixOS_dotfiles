# bat, a `cat` with syntax highlighting.
#
# Deliberately declares no programs.bat.config. On a niri host Noctalia's
# "bat" community template (home/noctalia.nix) owns ~/.config/bat/config:
# its apply.sh `touch`es that file and rewrites it to `--theme=noctalia`
# before running `bat cache --build`. A Home-Manager-managed config would be
# a read-only store symlink, the touch would fail, and under the script's
# `set -e` the cache rebuild would never run — leaving a theme file bat
# cannot see. With no config declared here the file is ordinary runtime
# state, and Home Manager's own batCache activation step rebuilds the cache
# on every switch, which also picks up the Noctalia theme once it exists.
# Without Noctalia (the laptop), bat simply uses its default theme.
#
# "Declares no config" has to be enforced, not just left out: Home Manager's
# own ghostty module adds a `map-syntax` entry for Ghostty's config file to
# programs.bat.config whenever bat is enabled, which alone is enough to
# bring the store symlink back. So on a niri host the option is forced
# empty, at the cost of bat no longer highlighting ~/.config/ghostty/config.
#
# Self-gates on osConfig.features.workstation, like the rest of the
# operator's terminal environment.
{ lib, osConfig, ... }:
lib.mkIf osConfig.features.workstation {
  programs.bat = {
    enable = true;
    config = lib.mkIf osConfig.features.niri (lib.mkForce { });
  };
}
