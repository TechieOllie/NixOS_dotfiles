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
# allow-listing over a blanket switch, and Phase 7's Steam entries kept it
# that way rather than giving up and flipping allowUnfree on.
#
# Lived in modules/desktop/ and was gated on config.features.niri until
# Phase 7, when that turned out to be a latent bug rather than a
# convenience: everything on the list happened to be a GUI app, but the
# gate meant a host with features.gaming and no compositor could not
# allow Steam at all, and would have failed eval with an obscure unfree
# error a long way from this file. It's now ungated and bundled by
# profiles/base.nix — an allow-list entry costs nothing on a host that
# never evaluates the package it names.
{ lib, ... }:
{
  nixpkgs.config.allowUnfreePredicate =
    pkg:
    builtins.elem (lib.getName pkg) [
      "vscode"
      "obsidian"
      # Anthropic's commercial terms rather than an OSS license — see
      # home/claude-code.nix, which installs it.
      "claude-code"
      # IntelliJ IDEA's unified distribution. Its Apache-2.0 sibling
      # (idea-oss) would need permittedInsecurePackages instead — see
      # home/jetbrains.nix.
      "idea"
      # Steam and the pieces the NixOS steam module pulls in around it.
      # Millennium's own `millennium-steam` is built inside that flake's
      # pinned nixpkgs (which sets allowUnfree itself), but the module
      # still touches this repo's own steam derivations, so both names are
      # needed here.
      "steam"
      "steam-unwrapped"
      # Microsoft's firmware blob for the Xbox Wireless Adapter, which
      # hardware.xone extracts and loads. Not obvious from the option name
      # — it surfaced only as an eval failure a long way from
      # modules/hardware/controllers.nix, which is the second reason (after
      # the features.niri gate above) this list stopped being desktop-only.
      "xone-dongle-firmware"
    ];
}
