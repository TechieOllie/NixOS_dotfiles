{
  config,
  lib,
  pkgs,
  ...
}:
lib.mkIf config.features.niri {
  # Package + Wayland session entry only, via upstream's programs.niri
  # module. Greetd wiring lives in modules/desktop/greetd.nix, what every
  # compositor's session needs in session.nix, and user config in
  # home/niri.nix — this module is the system-level half only, per the
  # guide's Niri split.
  programs.niri.enable = true;

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
  #
  # Needs >= 0.8.3. 0.8.2 dismissed override-redirect popups ~35 ms after
  # mapping them (upstream 3273a0f, fixed by add2795), which showed up as
  # Steam's top-bar menus and friends list flashing open and vanishing — and
  # read as a Steam regression. This module pinned 0.8.3 forward until the
  # 2026-10-09 input bump brought nixpkgs up to it; see docs/decisions.md.
  #
  # The compositor-agnostic session pieces (NIXOS_OZONE_WL, wl-clipboard,
  # the keyring daemon) live in session.nix. Umbriel needs none of this: its
  # package wraps plain Xwayland onto its own PATH.
  environment.systemPackages = [ pkgs.xwayland-satellite ];
}
