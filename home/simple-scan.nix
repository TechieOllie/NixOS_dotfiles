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
  pkgs,
  lib,
  osConfig,
  ...
}:
lib.mkIf (osConfig.features.niri && osConfig.features.printing) {
  home.packages = [ pkgs.simple-scan ];
}
