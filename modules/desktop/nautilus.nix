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
}
