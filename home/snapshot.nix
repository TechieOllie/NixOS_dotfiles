# Camera app. GNOME's current app is Snapshot (nixpkgs attribute "snapshot",
# not "gnome.snapshot" — confirmed against this flake's pinned nixpkgs,
# where the top-level gnome.* aliases don't cover it). Cheese, the older
# GNOME camera app, is deprecated upstream in Snapshot's favour and was not
# chosen.
#
# The hardware target is the iMac's built-in FaceTime HD Camera
# (05ac:850b) — confirmed live on the installer ISO to be a plain UVC
# device handled by the in-kernel uvcvideo driver, not the special
# facetimehd driver (that one's for the different 05ac:8514 chip in 2013+
# MacBooks). No extra kernel module or firmware is needed for the camera
# itself.
{
  pkgs,
  lib,
  osConfig,
  ...
}:
lib.mkIf osConfig.features.gnome {
  home.packages = [ pkgs.snapshot ];
}
