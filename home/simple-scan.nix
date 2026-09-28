# Document scanner. modules/services/printing.nix already enables SANE (with
# the airscan/eSCL backend in its default set), and `scanimage -L` on the
# desktop finds the HP OfficeJet 4650's platen and ADF over the network — but
# nothing gave that a GUI, so scanning meant the command line.
#
# Document Scanner (simple-scan) is GNOME's own, GTK4/libadwaita like
# Nautilus, Loupe and Papers, so it inherits this repo's existing theming
# with nothing new needed here. It is also the scanner inotmac already gets
# from GNOME's stock app set (modules/desktop/gnome.nix), so both desktop
# stacks end up with the same tool. It claims no MIME types — it opens
# nothing, it only produces files — so there is no default to set.
#
# Gated on both flags: features.printing because without SANE there is
# nothing to scan from, features.niri because without a graphical session
# there is nowhere to show it (the laptop has printing but no desktop yet).
#
# No `scanner` group membership needed for this: eSCL is a network scanner
# reached over HTTP, not a udev-gated device node. A USB scanner would need
# it — see the note in modules/services/printing.nix.
#
# Verified live on the desktop 2026-09-27: scans from the OfficeJet 4650.
{
  config,
  pkgs,
  lib,
  osConfig,
  ...
}:
let
  scanDir = "${config.xdg.userDirs.documents}/Scanned Documents";
in
lib.mkIf (osConfig.features.niri && osConfig.features.printing) {
  home.packages = [ pkgs.simple-scan ];

  # The preferences set by hand in the app on the desktop, read back with
  # `dconf dump /org/gnome/simple-scan/`. Only the keys that differ from the
  # schema: save-format is already application/pdf by default, so it isn't
  # restated. Paper size is in tenths of a millimetre (A4 = 210 x 297 mm);
  # the default of 0 means "detect", and the OfficeJet's flatbed doesn't.
  dconf.settings."org/gnome/simple-scan" = {
    paper-width = 2100;
    paper-height = 2970;
    # A GIO URI, not a path, so the space is percent-encoded.
    save-directory = "file://${lib.replaceStrings [ " " ] [ "%20" ] scanDir}/";
  };

  # The folder the setting above names. Without it a fresh host's save
  # dialog would open on a directory that doesn't exist. `d` never touches
  # an existing directory or its contents. The quotes are tmpfiles' own:
  # the path has a space in it.
  systemd.user.tmpfiles.rules = [ ''d "${scanDir}" - - - -'' ];
}
