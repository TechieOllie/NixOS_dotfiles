# CD ripper, picked for rip *accuracy* over GUI polish (operator's explicit
# priority — GNOME has no actively-maintained, accuracy-focused ripper of
# its own; Sound Juicer is GNOME-native but essentially unmaintained
# upstream, and neither it nor Asunder do AccurateRip verification).
# whipper is CLI (a fork of the older whipper/morituri lineage, built on
# cdparanoia + AccurateRip database checks), confirmed to exist and evaluate
# cleanly against this flake's pinned nixpkgs
# (`pkgs.whipper.meta.description` = "CD ripper aiming for accuracy over
# speed"). abcde was the fallback candidate if whipper turned out broken at
# this pin; it wasn't needed.
#
# Needs the optical drive (this host has one — OPTIARC DVD RW AD-5690H,
# confirmed live via lsblk on the installer) and, like scanning, needs group
# membership whipper's own package doesn't grant on its own — see
# hosts/inotmac/default.nix, which adds "cdrom" to every account here.
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
  environment.systemPackages = [ pkgs.whipper ];
}
