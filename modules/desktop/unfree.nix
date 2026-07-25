# Allow-list for unfree packages this repo actually uses — has to live at
# the NixOS level: eval rejects an unfree package unless explicitly
# allowed, and this can't be set from the home-manager side (e.g.
# home/vscode.nix, which installs the actual package) since
# home-manager's useGlobalPkgs = true (lib/mkHost.nix) means it shares the
# one pkgs instance built from this host's own nixpkgs.config, already
# finalized by the time home-manager evaluates.
#
# Originally just "vscode" (Phase 6); "obsidian" added the same phase once
# it turned out to carry a custom, nixpkgs-flagged-unfree license too
# (confirmed via `nix eval nixpkgs#obsidian.meta.license`: "obsidian", not
# a standard OSS license id). Scoped to a named list rather than
# nixpkgs.config.allowUnfree = true outright — deliberate per-package
# allow-listing over a blanket switch. Revisit if Phase 7 (Steam/Proton
# GE, also unfree) makes a growing list more trouble than it's worth.
#
# Gated on config.features.niri like the rest of this directory — every
# app on this list is a GUI app, gated the same way in its own home/*.nix.
{ config, lib, ... }:
lib.mkIf config.features.niri {
  nixpkgs.config.allowUnfreePredicate =
    pkg:
    builtins.elem (lib.getName pkg) [
      "vscode"
      "obsidian"
    ];
}
