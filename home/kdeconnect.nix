# User half of KDE Connect: the part that actually runs in the session.
# modules/services/kdeconnect.nix installs the package system-wide and opens
# the firewall, but nothing there starts a daemon — outside Plasma there is
# no session service doing it.
#
# `kdeconnect-indicator` is upstream's entry point for exactly that case: a
# StatusNotifierItem tray icon that D-Bus-activates `kdeconnectd` on start,
# so one unit covers both the daemon and its UI (pairing, "send file",
# "find my phone" all live in that menu). Its own autostart .desktop file is
# deliberately unused — this repo's convention is one systemd user service
# per autostarted app, which also gives it restart-on-failure and a real
# place for its logs (`journalctl --user -u kdeconnect`).
#
# The noctalia.service ordering and the ExecStartPre sleep are the same
# tray-registration race already diagnosed for home/vesktop.nix: Noctalia is
# a plain Type=simple unit, so "started" means "process forked", not "tray
# host ready", and an SNI item registered before that is silently dropped.
# The sleep is what actually closes it; the ordering is best-effort.
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
  systemd.user.services.kdeconnect = {
    Unit = {
      Description = "KDE Connect daemon and tray indicator";
      After = [
        "graphical-session.target"
        "noctalia.service"
      ];
      PartOf = [ "graphical-session.target" ];
    };

    Service = {
      ExecStartPre = "${pkgs.coreutils}/bin/sleep 5";
      ExecStart = "${pkgs.kdePackages.kdeconnect-kde}/bin/kdeconnect-indicator";
      Restart = "on-failure";
    };

    Install.WantedBy = [ "graphical-session.target" ];
  };
}
