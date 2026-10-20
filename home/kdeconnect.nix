# User half of KDE Connect. modules/services/kdeconnect.nix installs the
# package system-wide and opens the firewall; this adds what the session
# needs on top.
#
# Nothing here starts the daemon, deliberately. The package ships its own
# /etc/xdg/autostart/org.kde.kdeconnect.daemon.desktop, which
# systemd-xdg-autostart-generator turns into a user unit
# (`app-org.kde.kdeconnect.daemon@autostart.service`, logs under that name),
# and both compositors reach xdg-desktop-autostart.target — niri.service
# `Wants=` it, umbriel-session.target pulls it in. That entry has been
# running kdeconnectd all along, alongside the old
# `kdeconnect-indicator` unit here, which was removed on 2026-10-20: the
# Noctalia `icefish/phone-connect` plugin is the UI now, so the tray icon
# was a duplicate. A hand-written kdeconnectd unit would be a second copy of
# the same daemon fighting the autostart one for its D-Bus name.
#
# Gated on osConfig.features.kdeconnect, not features.niri — the flag that
# turns the capability on is the same one on both sides, and a host that
# sets it has a graphical session today.
{
  pkgs,
  lib,
  osConfig,
  ...
}:
lib.mkIf osConfig.features.kdeconnect {
  # Runtime dependencies of Noctalia's `icefish/phone-connect` plugin, which
  # shells out from Noctalia's own PATH (the per-user profile is on it).
  # Its backend probe is `gdbus call … NameHasOwner`, and without `gdbus`
  # (glib's bin output) it reports no KDE Connect at all even with the
  # daemon up and a phone connected — no error anywhere, just an empty
  # widget. sshfs is what kdeconnectd's own sftp plugin mounts the phone
  # with, for the plugin's "browse files".
  home.packages = [
    pkgs.glib
    pkgs.sshfs
  ];
}
