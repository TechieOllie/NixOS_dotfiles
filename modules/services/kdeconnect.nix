# KDE Connect — phone integration: shared clipboard, file transfer,
# notification mirroring, remote input, media control. System-level rather
# than a pure Home Manager package because the daemon has to be reachable
# from the phone: pairing and every plugin after it run over TCP/UDP
# 1714-1764, which upstream's `programs.kdeconnect` module opens in the
# firewall. A `home.packages` entry alone would install the binaries and
# then never discover a device, since modules/system/networking.nix leaves
# the firewall on.
#
# The user half — actually running the daemon and its tray icon inside the
# graphical session — lives in home/kdeconnect.nix, the same system/home
# split niri and Nautilus use.
#
# kdePackages (Qt6/KF6) rather than the Qt5 `plasma5Packages` build: nothing
# else in this repo pulls in Plasma, so this is the only Qt toolkit version
# question here, and Qt6 is what home/qt.nix already themes via qt6ct.
{
  config,
  lib,
  pkgs,
  ...
}:
lib.mkIf config.features.kdeconnect {
  programs.kdeconnect = {
    enable = true;
    package = pkgs.kdePackages.kdeconnect-kde;
  };
}
