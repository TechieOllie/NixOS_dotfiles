# Graphical CD ripper for the shared GNOME host.
#
# This exists because whipper — modules/programs/whipper.nix, chosen when
# the priority was rip *accuracy* — has no GUI at all, which made it
# invisible to the people meant to use it. The two coexist deliberately:
# whipper keeps the AccurateRip-verified path for anyone willing to use a
# terminal, Asunder is the one that shows up in the app grid.
#
# Asunder rather than Sound Juicer: Sound Juicer is the GNOME-native option
# but is effectively unmaintained upstream, and an unmaintained ripper on a
# machine four people share is a worse trade than a maintained non-native
# one. Asunder is GTK and will not match libadwaita styling — accepted, on
# the grounds that a ripper that works and looks slightly foreign beats one
# that matches and bitrots.
#
# LAME is listed alongside it, not decoratively: nixpkgs wraps Asunder with
# cdparanoia, flac and vorbis-tools but *not* lame, so MP3 output — the
# format most people will actually pick — fails with an encoder error and
# no hint as to why. Asunder's wrapper prepends its own PATH while keeping
# $PATH, so a system-installed lame is found.
#
# System-wide for the same reason as chrome/picard/whipper here: Home
# Manager covers one of this host's four accounts.
{
  pkgs,
  lib,
  config,
  ...
}:
lib.mkIf config.features.gnome {
  environment.systemPackages = with pkgs; [
    asunder
    lame
  ];
}
