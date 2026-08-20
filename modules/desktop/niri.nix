{
  config,
  lib,
  pkgs,
  ...
}:
lib.mkIf config.features.niri {
  # Package + Wayland session entry only, via upstream's programs.niri
  # module. Greetd wiring lives in modules/desktop/greetd.nix, and user
  # config in home/niri.nix — this module is the
  # system-level half only, per the guide's Niri split.
  programs.niri.enable = true;

  # Standard NixOS fix for Electron apps under Wayland: nixpkgs' own
  # electron/vscode/vesktop wrapper scripts only add their
  # --ozone-platform-hint=auto flag when $NIXOS_OZONE_WL is set (confirmed
  # by reading their actual wrapper scripts) — without it, Electron falls
  # back to X11, which crashes outright here since XWayland is disabled
  # repo-wide. Found live while investigating the Phase 6 Vesktop rename:
  # niri/cfg/misc.kdl's own `environment` block already sets
  # ELECTRON_OZONE_PLATFORM_HINT/XDG_SESSION_TYPE/etc., but confirmed via
  # `systemctl --user show-environment` on the VM that none of that block
  # actually reaches the systemd --user manager's own environment (only
  # WAYLAND_DISPLAY/XDG_CURRENT_DESKTOP/XDG_SESSION_TYPE/XDG_SESSION_ID do,
  # presumably imported by logind/PAM at session start, a different
  # mechanism than niri's KDL environment block) — meaning anything
  # launched as a systemd user service (Noctalia's own launcher, via
  # shell.launch_apps_as_systemd_services) never saw it either. This is the
  # NixOS-standard system-level variable instead, which live-tested
  # correctly resolves Electron to Wayland once set (confirmed on the VM:
  # Vesktop launched with a real "vesktop" Wayland app_id, no ozone/X11
  # error).
  environment.sessionVariables.NIXOS_OZONE_WL = "1";

  # Xwayland, for the X11-only apps that are still unavoidable — Steam's
  # client is the one that forced this (it has no Wayland backend at all and
  # simply refuses to start without a DISPLAY). niri has built-in
  # xwayland-satellite integration and it is *on by default*: the compositor
  # looks up a bare `xwayland-satellite` on its PATH at startup, and the only
  # reason it never worked here is that nothing put that binary there — the
  # "xwayland-satellite not found" line in niri's log has been visible since
  # Phase 3 and was written off as expected. Installing it is the whole fix;
  # no KDL change is needed, and adding an `xwayland-satellite {}` block
  # would only restate a default (`off false`, `path "xwayland-satellite"`,
  # read out of niri 26.04's own config defaults).
  #
  # System-wide rather than home.packages: niri is started by greetd, whose
  # PATH is /run/current-system/sw/bin — a user profile entry would be too
  # late to be found at compositor startup.
  #
  # niri sets DISPLAY from the satellite *before* it runs
  # `systemctl --user import-environment`, and DISPLAY is in the list it
  # imports, so unlike the KDL `environment {}` block above this does reach
  # the systemd --user manager — i.e. apps Noctalia launches as user services
  # see it too. It only takes effect on a fresh session, though: niri can
  # restart the satellite on config reload but explicitly does not re-push
  # DISPLAY into the systemd environment.
  environment.systemPackages = [ pkgs.xwayland-satellite ];
}
