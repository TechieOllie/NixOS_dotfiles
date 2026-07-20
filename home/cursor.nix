# Cursor theme — single source of truth for GTK/Qt/Wayland toolkit apps via
# Home Manager's own home.pointerCursor. Self-gates on osConfig.features.niri,
# same convention as home/niri.nix/home/noctalia.nix. The system-level half
# (installing the package so noctalia-greeter can reference it too, since the
# greeter runs outside any user's Home Manager profile) lives in
# modules/desktop/theming.nix + greetd.nix's own settings.cursor.
#
# x11.enable is deliberately omitted — programs.niri sets enableXWayland =
# false repo-wide (see CLAUDE.md's Phase 3 notes), so there's no X11 cursor
# consumer to configure here.
#
# home/niri/cfg/misc.kdl already sets its own `cursor { xcursor-theme
# "Bibata-Modern-Classic"; xcursor-size 22; }` block — niri renders its own
# compositor cursor independently of GTK/Qt env vars, and that file is a
# static live-symlinked KDL file (docs/live-dotfiles.md) that can't reference
# this Nix value. The name/size below is therefore intentionally duplicated
# in two places; keep them in sync by hand if either ever changes.
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
