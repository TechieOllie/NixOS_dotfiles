# FreeCAD — parametric 3D CAD. Package only: FreeCAD keeps its preferences
# in ~/.config/FreeCAD/user.cfg, an XML document it rewrites wholesale on
# exit (window layout, recent files and per-workbench state all live in the
# same file), so it is app-owned mutable state rather than a set of
# declarative preferences — the same call already made for Obsidian's vault
# config and Zen's profile.
#
# Gated on osConfig.features.cad rather than features.niri: a heavy
# Qt/OpenCascade GUI app that exactly one machine has a use for, which is
# what a feature flag is for. Sharing features.niri would put it on the VM,
# the disposable verification host, for nothing.
{
  pkgs,
  lib,
  osConfig,
  ...
}:
lib.mkIf osConfig.features.cad {
  home.packages = [ pkgs.freecad ];
}
