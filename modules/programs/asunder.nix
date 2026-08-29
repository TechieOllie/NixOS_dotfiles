# Graphical CD ripper for the shared GNOME host.
#
# The host's only CD ripper. whipper came first, chosen when the stated
# priority was rip *accuracy*, and was removed once it became clear the
# trade was wrong for this machine: it is CLI-only, so the three
# non-technical accounts sharing this iMac could not find it at all. An
# AccurateRip-verifying ripper nobody can launch rips nothing.
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
# System-wide for the same reason as chrome/picard here: Home
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
