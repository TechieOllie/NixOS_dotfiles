# MusicBrainz Picard — audio file tagger. No real GNOME-native alternative
# exists for MusicBrainz tagging specifically, so this is a plain package
# install with nothing else to configure.
#
# System-wide rather than a Home Manager module: this repo wires Home
# Manager for exactly one user (lib/mkHost.nix), and inotmac is shared by
# four people who all get the optical drive and the "cdrom" group.
{
  pkgs,
  lib,
  config,
  ...
}:
lib.mkIf config.features.gnome {
  environment.systemPackages = [ pkgs.picard ];
}
