# MusicBrainz Picard — audio file tagger. No real GNOME-native alternative
# exists for MusicBrainz tagging specifically, so this is a plain package
# install with nothing else to configure.
{
  pkgs,
  lib,
  osConfig,
  ...
}:
lib.mkIf osConfig.features.gnome {
  home.packages = [ pkgs.picard ];
}
