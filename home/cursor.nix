# Cursor theme — single source of truth for GTK/Qt/Wayland toolkit apps via
# Home Manager's own home.pointerCursor. Self-gates on osConfig.features.niri,
# same convention as home/niri.nix/home/noctalia.nix. The system-level half
# (installing the package so noctalia-greeter can reference it too, since the
# greeter runs outside any user's Home Manager profile) lives in
# modules/desktop/theming.nix + greetd.nix's own settings.cursor.
#
# x11.enable stays deliberately omitted even now that XWayland exists here
# (modules/desktop/niri.nix installs xwayland-satellite, so Steam and other
# X11-only apps run). All that option adds is an `xsetroot` line in
# xsession.profileExtra and two Xresources properties — an xsession this repo
# never starts. Xwayland clients pick the theme up from XCURSOR_THEME and
# XCURSOR_SIZE instead, which home.pointerCursor exports unconditionally
# (read out of home-manager's own modules/config/home-cursor.nix), so they
# are already covered by the block below.
#
# home/niri/cfg/misc.kdl already sets its own `cursor { xcursor-theme
# "Bibata-Modern-Classic"; xcursor-size 22; }` block — niri renders its own
# compositor cursor independently of GTK/Qt env vars, and that file is a
# static live-symlinked KDL file (docs/live-dotfiles.md) that can't reference
# this Nix value. modules/desktop/greetd.nix's settings.cursor carries the
# same pair again, for the greeter. The name/size below is therefore
# intentionally duplicated across three places — here, home/niri/cfg/misc.kdl,
# and modules/desktop/greetd.nix; keep them in sync by hand if either ever
# changes.
{
  pkgs,
  lib,
  osConfig,
  ...
}:
lib.mkIf osConfig.features.niri {
  home.pointerCursor = {
    enable = true; # explicit — implicit-enable-on-set is deprecated upstream
    package = pkgs.bibata-cursors;
    name = "Bibata-Modern-Classic";
    size = 22;
    # Needed for gtk.cursorTheme (home/gtk.nix's gtk.enable = true) to
    # actually apply this — home-manager's own module docs note gtk.enable
    # must be true too, or this setting is inert.
    gtk.enable = true;
  };
}
