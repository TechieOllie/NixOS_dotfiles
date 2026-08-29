# CD ripper for the shared GNOME host.
#
# Fourth ripper here, and the last one only because the first three were
# each chosen against a criterion that turned out not to be the binding
# one. Worth keeping the sequence, since it is the reasoning that keeps
# getting redone:
#
#   - whipper: chosen when the priority was rip *accuracy*. Dropped for
#     being CLI-only — three of this machine's four accounts could not
#     launch it, and a ripper nobody can start rips nothing.
#   - asunder: chosen for having a window. Reported unusable on the
#     machine. It could in fact produce FLAC (nixpkgs defaults its
#     flacSupport on), so the format was never the problem.
#   - sound-juicer: chosen for being GNOME's own, explicitly accepting
#     that it is unmaintained (3.40.0, 2021). It works, and was rejected
#     on feel.
#   - fre:ac: maintained, ~2023, and the only GUI ripper in nixpkgs that
#     ships **AccurateRip** — the exact thing the original accuracy
#     priority wanted, and which was wrongly written off as unavailable
#     when whipper was dropped.
#
# fre:ac draws with its own toolkit, so it will not look like a GNOME app
# and will not follow the desktop's theming. Accepted, on the same trade
# asunder was accepted under: this one actually works.
#
# It is unusable as packaged — see overlays/freac.nix, which is the only
# reason overlays/ exists — so this module carries the overlay with it.
# The overlay is applied *outside* the feature gate on purpose: overriding
# one attribute costs nothing on a host that never evaluates pkgs.freac,
# whereas making nixpkgs.overlays depend on config.features.gnome invites
# the classic infinite recursion (pkgs is needed to evaluate the modules
# that would decide whether to build pkgs).
#
# System-wide for the same reason as chrome/picard here: Home Manager
# covers one of this host's four accounts.
#
# No declarative defaults, unlike the sound-juicer module this replaces —
# fre:ac stores its settings in its own ~/.config/freac tree rather than
# GSettings, so the output format is each person's own first-run choice.
# It is FLAC that was asked for; that has to be picked once in the UI.
{
  config,
  lib,
  pkgs,
  ...
}:
{
  nixpkgs.overlays = [ (import ../../overlays/freac.nix) ];

  # faac carries a non-free license and is pulled in by fre:ac's AAC
  # support. The overlay deliberately does not wire up any AAC codec, so
  # nothing here can actually encode AAC — but faac is a build input of
  # the derivation itself, so the allow-list entry is still required to
  # evaluate it at all. See modules/system/unfree.nix for the list.
  environment.systemPackages = lib.mkIf config.features.gnome [ pkgs.freac ];
}
