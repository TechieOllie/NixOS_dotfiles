# KiCad — schematic capture and PCB layout. Package only, for the same
# reason as home/freecad.nix: KiCad keeps its preferences in
# ~/.config/kicad/<version>/, a tree of JSON files it rewrites wholesale on
# exit (window layout, recent projects, library tables and per-tool state
# all land in the same place), so it is app-owned mutable state rather than
# a set of declarative preferences. The default symbol/footprint/3D-model
# libraries come with the package and are registered by KiCad itself on
# first run.
#
# Rides osConfig.features.cad alongside FreeCAD rather than getting a flag
# of its own: one flag per *capability*, and "this machine is the one the
# operator designs hardware on" is that capability. Mechanical CAD and
# electronic CAD are the two halves of it, and neither host without the
# flag has a use for either.
#
# Verified live on the desktop 2026-08-22: KiCad launches.
{
  pkgs,
  lib,
  osConfig,
  ...
}:
lib.mkIf osConfig.features.cad {
  home.packages = [ pkgs.kicad ];
}
