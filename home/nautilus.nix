# User half of Nautilus (dconf preferences, archive mime defaults) — the
# system half (package,
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
let
  # Archives. Nothing in this repo could open one: no archive manager is
  # installed, so .zip/.tar/.7z/.rar and friends had no default at all —
  # found by the 2026-08-23 audit of common extensions against
  # shared-mime-info (docs/decisions.md).
  #
  # No new package is needed, because Nautilus already extracts archives
  # itself (gnome-autoar, built in since 3.32) and already *declares* every
  # one of these types in its own packaged desktop entry. It was a
  # candidate handler the whole time with no default pointing at it — the
  # same "declared but not default" gap home/loupe.nix and home/papers.nix
  # closed for their formats. This list is that entry's own archive types,
  # read out of this flake's locked nixpkgs, so it can't claim something
  # Nautilus won't take.
  #
  # Opening one lands in Nautilus' extract flow rather than a browsable
  # archive view; a real archive manager (file-roller) would be a separate
  # decision, and wasn't wanted. Verified live on the desktop 2026-08-23:
  # `xdg-open a.zip` extracted it to a sibling directory and opened that
  # folder in Nautilus.
  archiveTypes = [
    "application/zip"
    "application/gzip"
    "application/bzip2"
    "application/zstd"
    "application/vnd.rar"
    "application/x-7z-compressed"
    "application/x-7z-compressed-tar"
    "application/x-bzip"
    "application/x-bzip-compressed-tar"
    "application/x-bzip2-compressed-tar"
    "application/x-compress"
    "application/x-compressed-tar"
    "application/x-gzip"
    "application/x-lzip"
    "application/x-lzip-compressed-tar"
    "application/x-lzma-compressed-tar"
    "application/x-tar"
    "application/x-tarz"
    "application/x-xz"
    "application/x-xz-compressed-tar"
    "application/x-zstd-compressed-tar"
  ];
in
lib.mkIf osConfig.features.niri {
  # Needs home/xdg-mime-apps.nix enabled to reach disk at all.
  xdg.mimeApps.defaultApplications = lib.genAttrs archiveTypes (_: "org.gnome.Nautilus.desktop");

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
