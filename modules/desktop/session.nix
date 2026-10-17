# The compositor-agnostic half of a graphical session: what every
# features.desktop host needs no matter whether niri or Umbriel draws it.
# Moved here out of niri.nix when Umbriel became a second compositor —
# none of it was ever about niri.
{
  config,
  lib,
  pkgs,
  ...
}:
lib.mkIf config.features.desktop {
  # Standard NixOS fix for Electron apps under Wayland: nixpkgs' own
  # electron/vscode/vesktop wrapper scripts only add their
  # --ozone-platform-hint=auto flag when $NIXOS_OZONE_WL is set (confirmed
  # by reading their actual wrapper scripts) — without it, Electron falls
  # back to X11. Found live while investigating the Phase 6 Vesktop rename:
  # niri/cfg/misc.kdl's own `environment` block already sets
  # ELECTRON_OZONE_PLATFORM_HINT/XDG_SESSION_TYPE/etc., but confirmed via
  # `systemctl --user show-environment` on the VM that none of that block
  # actually reaches the systemd --user manager's own environment — meaning
  # anything launched as a systemd user service (Noctalia's own launcher, via
  # shell.launch_apps_as_systemd_services) never saw it either. This is the
  # NixOS-standard system-level variable instead, which live-tested
  # correctly resolves Electron to Wayland once set (confirmed on the VM:
  # Vesktop launched with a real "vesktop" Wayland app_id, no ozone/X11
  # error). Umbriel's `[environment]` table has the same limit — its own
  # docs say a removed key is never cleared from systemd — so the same
  # reasoning applies there.
  environment.sessionVariables.NIXOS_OZONE_WL = "1";

  # The login keyring daemon. programs.niri happens to enable it
  # (mkDefault, for its Secret portal) and Umbriel's module does not, but
  # nothing about it is niri's: greetd.nix's PAM unlock, the gcr SSH agent
  # behind home/ssh and every libsecret client (VS Code, Zen) need it under
  # either compositor. Stated here so it no longer depends on which
  # compositor module happens to pull it in.
  services.gnome.gnome-keyring.enable = true;

  # wl-clipboard is the session's clipboard CLI. Anything that reads or
  # writes the clipboard by shelling out to wl-copy/wl-paste from PATH
  # (Claude Code's image paste is what found the gap) needs it installed,
  # not just carried inside one script's closure like home/screenshot.nix.
  environment.systemPackages = [ pkgs.wl-clipboard ];
}
