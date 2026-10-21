# darktable — raw photo development and a photo library. Package only, for
# the same reason as home/freecad.nix: darktable keeps its preferences in
# ~/.config/darktable/darktablerc, a key=value file it rewrites wholesale on
# exit, next to library.db/data.db (the photo library and its styles/tags),
# so it is app-owned mutable state rather than a set of declarative
# preferences.
#
# Gated on osConfig.features.photography rather than riding features.cad:
# one flag per *capability*, and editing photos isn't designing hardware.
#
# Verified live on theseus 2026-10-22: darktable launches.
{
  pkgs,
  lib,
  osConfig,
  ...
}:
lib.mkIf osConfig.features.photography {
  home.packages = [ pkgs.darktable ];
}
