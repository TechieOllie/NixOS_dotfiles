# System half of Nautilus — gated on config.features.niri like the rest of
# this directory, since it's only useful with a graphical session. The user
# half (dconf preferences) lives in home/nautilus.nix, same split as niri.
#
# Nothing in this repo enabled any of the three pieces of infrastructure
# below before Nautilus needed them — niri alone never pulled in a
# dconf-backed GTK app:
#   - programs.dconf.enable: the dconf D-Bus service itself. Without it, a
#     GTK app's settings (including Nautilus's own dconf.settings in
#     home/nautilus.nix) don't persist at all outside a full GNOME session.
#   - services.gvfs.enable: trash, network mounts (smb/sftp), and MTP
#     device browsing — Nautilus is badly broken without this on NixOS
#     (confirmed: none of these work with a plain nautilus package alone).
#   - services.tumbler.enable: thumbnail generation for images/videos in
#     the file view.
#
# PTP cameras (most digicams — the desktop's Nikon P900 is one) are a fourth,
# separate piece: gvfs's gphoto2 monitor only shows a device udev has tagged
# ID_GPHOTO2=1, and that tag comes from libgphoto2's own udev rules, which
# NixOS installs only via programs.gphoto2.enable. Without it the camera
# enumerates, has correct uaccess ACLs, and still never appears. No `camera`
# group membership is needed: systemd's uaccess rule already covers
# ID_GPHOTO2 devices for the seat's session.
{
  config,
  lib,
  pkgs,
  ...
}:
lib.mkIf config.features.niri {
  environment.systemPackages = [ pkgs.nautilus ];

  programs.dconf.enable = true;
  services.gvfs.enable = true;
  services.tumbler.enable = true;
  programs.gphoto2.enable = true;
}
