# OrcaSlicer — 3D-printing slicer. Package only: printer, filament and
# process profiles are written by the slicer under ~/.config/OrcaSlicer,
# app-owned state like FreeCAD's user.cfg.
#
# Rides features.cad (home/freecad.nix, home/kicad.nix): same capability —
# this machine designs physical things — on the same hosts.
{
  pkgs,
  lib,
  osConfig,
  ...
}:
lib.mkIf osConfig.features.cad {
  home.packages = [ pkgs.orca-slicer ];
}
