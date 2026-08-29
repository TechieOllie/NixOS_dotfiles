# Graphical CD ripper for the shared GNOME host.
#
# Third ripper on this host, and the reasoning behind each swap is worth
# keeping, because the same trade got weighed twice and came out
# differently the second time:
#
#   - whipper: chosen first, when the stated priority was rip *accuracy*.
#     Dropped because it is CLI-only, and an AccurateRip-verifying ripper
#     that three of this machine's four accounts cannot launch rips
#     nothing.
#   - asunder: chosen next for having a window and a maintained fork,
#     explicitly *over* Sound Juicer on the grounds that Sound Juicer is
#     effectively unmaintained upstream (3.40.0, 2021). That weighting was
#     wrong: on the machine, asunder was reported as awkward to the point
#     of unusable, while the maintenance risk it was chosen to avoid is
#     entirely theoretical for a program whose job — drive cdparanoia,
#     hand PCM to an encoder — has not changed in twenty years.
#
# So: Sound Juicer, GNOME's own. It is GTK3 rather than libadwaita and will
# look slightly dated beside the rest of the desktop; accepted.
#
# FLAC is what this host rips to, and that is set below rather than left to
# each person to find. Note that asunder *could* also produce FLAC —
# nixpkgs defaults its `flacSupport` on and puts the flac binary in its
# wrapper PATH (verified on the live machine), so the format was there,
# just buried behind a preferences dialog. The fix for that is a better
# default, not a different capability.
#
# Accuracy did not have to be given up either: `paranoia` below is
# cdparanoia's own error-correction mode, which is the same engine whipper
# and asunder both drive. It is not AccurateRip's cross-checking against a
# submitted-results database — nothing with a GUI in nixpkgs offers that —
# but it is the full-strength local read-and-verify, and it is on by
# default.
#
# System-wide for the same reason as chrome/picard here: Home Manager
# covers one of this host's four accounts.
{
  pkgs,
  lib,
  config,
  ...
}:
lib.mkIf config.features.gnome {
  environment.systemPackages = [ pkgs.sound-juicer ];

  # Defaults for every account on this machine, including ones that do not
  # exist yet — the reach Home Manager cannot give here. Both are plain
  # defaults, not locks: anyone can change them in the app and their own
  # dconf value then shadows this.
  #
  # The schema has to be named in extraGSettingsOverridePackages as well as
  # written to. glib-compile-schemas resolves every key in an override
  # against a real schema and *fails the build* on one it cannot find, so a
  # typo'd key here is caught rather than silently ignored — unlike the
  # section-header trap in gnome.nix's favoriteAppsOverride, where a wrong
  # header names no schema at all and is simply skipped.
  services.desktopManager.gnome = {
    extraGSettingsOverridePackages = [ pkgs.sound-juicer ];
    extraGSettingsOverrides = ''
      [org.gnome.sound-juicer]
      audio-profile='audio/x-flac'
      paranoia=['fragment','overlap','scratch']
    '';
  };
}
