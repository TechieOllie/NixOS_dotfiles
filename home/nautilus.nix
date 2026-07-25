# User half of Nautilus (dconf preferences) — the system half (package,
# dconf/gvfs/tumbler wiring) lives in modules/desktop/nautilus.nix. No
# Noctalia template exists for Nautilus (confirmed — not in the
# community-templates catalog), and it's a plain GTK4 app, so it already
# inherits this repo's existing adw-gtk3/Papirus/cursor theming
# (home/gtk.nix, home/cursor.nix) with nothing new needed here.
#
# Preferences ported verbatim from the operator's real
# `dconf dump /org/gnome/nautilus/`. Skips migrated-gtk-settings — an
# internal one-time migration marker Nautilus itself writes, not a real
# preference.
#
# Self-gates on osConfig.features.niri, same convention as home/gtk.nix.
{
  config,
  lib,
  osConfig,
  ...
}:
lib.mkIf osConfig.features.niri {
  # Sidebar pinned locations. Confirmed live (on the operator's real,
  # currently-used Nautilus 50.2.2) that this legacy gtk-3.0 path is still
  # exactly what present-day GTK4 Nautilus reads for this — one
  # "file://<path> <Label>" per line. Deliberately just the standard XDG
  # set (matching home/xdg-user-dirs.nix, "the usual folders" per the
  # operator's own request), not the operator's own real bookmarks file's
  # extra personal entries (custom Documents subfolders) — those are
  # workflow-specific to that machine, not a repo-wide default.
  xdg.configFile."gtk-3.0/bookmarks".text = ''
    file://${config.home.homeDirectory} Home
    file://${config.home.homeDirectory}/Documents Documents
    file://${config.home.homeDirectory}/Downloads Downloads
    file://${config.home.homeDirectory}/Music Music
    file://${config.home.homeDirectory}/Pictures Pictures
    file://${config.home.homeDirectory}/Videos Videos
  '';

  dconf.settings = {
    "org/gnome/nautilus/icon-view" = {
      captions = [
        "date_modified"
        "detailed_type"
        "none"
      ];
      default-zoom-level = "medium";
    };

    "org/gnome/nautilus/preferences" = {
      date-time-format = "detailed";
      default-folder-viewer = "icon-view";
      show-create-link = true;
      show-delete-permanently = true;
      show-hidden-files = true;
    };

    "org/gnome/nautilus/window-state" = {
      initial-size = lib.hm.gvariant.mkTuple [
        890
        550
      ];
      initial-size-file-chooser = lib.hm.gvariant.mkTuple [
        890
        550
      ];
      maximized = false;
    };
  };
}
