{
  config,
  lib,
  pkgs,
  ...
}:
let
  # xwayland-satellite, pinned forward to 0.8.3.
  #
  # 0.8.2 — what this flake's nixpkgs pin ships, and what nixpkgs master
  # still ships as of 2026-09-26 — carries a regression in
  # override-redirect popup handling introduced by upstream 3273a0f: the
  # popup is mapped, the pointer is immediately reported as leaving it,
  # and it dismisses itself ~35ms later. Under niri the visible symptom is
  # Steam's top-bar menus (Steam/View/Friends) and the friends list
  # flashing open and vanishing before they can be clicked, which reads as
  # a Steam client regression and is not one — Steam's client version is
  # self-updating runtime state this repo doesn't pin anyway, so there is
  # nothing to revert on that side. Upstream issue #468 and
  # ValveSoftware/steam-for-linux#13566 both land here; every fix reported
  # in that thread is an xwayland-satellite move, down to 0.8.1 or up to
  # 0.8.3.
  #
  # Fixed upstream by add2795 ("Fix for new Steam popups"), released in
  # v0.8.3 on 2026-09-24. Takes effect on a fresh graphical session, not a
  # config reload — niri starts the satellite at compositor startup.
  #
  # A flake update does not resolve this: the nixpkgs bump is unmerged, in
  # NixOS/nixpkgs#566386. Delete this whole block and go back to a bare
  # pkgs.xwayland-satellite once that lands and the pin carries >= 0.8.3
  # (`nix eval --raw nixpkgs#xwayland-satellite.version` against the
  # locked input answers it).
  xwaylandSatelliteSrc = pkgs.fetchFromGitHub {
    owner = "Supreeeme";
    repo = "xwayland-satellite";
    tag = "v0.8.3";
    hash = "sha256-eFEjCCniMCKeWU0PcZNv+tDYe08SLFPjRplyPY8OFt4=";
  };
  xwayland-satellite = pkgs.xwayland-satellite.overrideAttrs {
    version = "0.8.3";
    src = xwaylandSatelliteSrc;
    # buildRustPackage turns the package's own cargoHash into a cargoDeps
    # derivation before overrideAttrs runs, so bumping the source means
    # replacing that vendor tree outright rather than just restating a hash.
    cargoDeps = pkgs.rustPlatform.fetchCargoVendor {
      src = xwaylandSatelliteSrc;
      hash = "sha256-gMGFvnbxM3hD5fmkSimaFd87GEf6BXFe/MGjoS6VNVU=";
    };
  };
in
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
  environment.systemPackages = [ xwayland-satellite ];
}
