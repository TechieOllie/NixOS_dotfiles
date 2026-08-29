# PDF viewer. Nothing in this repo could open a PDF: with no registered
# application/pdf default, xdg-open fell through to whatever mimeinfo.cache
# happened to list — in practice Zen Browser, which renders the file via
# pdf.js but is a browser tab rather than a document viewer (no library, no
# annotations, no forms). Exactly the gap home/loupe.nix closed for images,
# and closed the same way.
#
# Papers is GNOME's current document viewer (it replaced Evince upstream),
# GTK4/libadwaita like Nautilus and Loupe, so it inherits this repo's
# existing Papirus/Bibata/adw-gtk3 theming (home/gtk.nix, home/cursor.nix)
# with nothing new needed here. Alternatives considered and not taken:
# zathura (keyboard-only and unthemed, wrong fit beside Nautilus), okular
# (Qt, a second toolkit for one app), leaving it to the browser (the case
# loupe.nix already argued against).
#
# Self-gates on osConfig.features.niri, same convention as home/loupe.nix.
#
# Verified live on the desktop 2026-08-22: a PDF opened via xdg-open lands
# in Papers rather than the browser.
{
  pkgs,
  lib,
  osConfig,
  ...
}:
let
  # From Papers' own packaged org.gnome.Papers.desktop MimeType= line (read
  # out of this flake's locked nixpkgs, not guessed), trimmed to the types
  # worth claiming a default for.
  #
  # image/tiff is deliberately left out even though Papers advertises it:
  # home/loupe.nix already claims it, and a TIFF is a picture here rather
  # than a document. Two modules setting the same default would also be a
  # straight option conflict.
  readableTypes = [
    "application/pdf"
    "application/x-bzpdf"
    "application/x-gzpdf"
    "application/x-xzpdf"
    "application/x-ext-pdf"
    "image/vnd.djvu"
    "image/vnd.djvu+multipage"
    "application/vnd.comicbook+zip"
    "application/vnd.comicbook-rar"
    "application/x-cbz"
    "application/x-cbr"
    "application/x-cb7"
    "application/x-cbt"
  ];
in
lib.mkIf osConfig.features.niri {
  home.packages = [ pkgs.papers ];

  # Papers ships these associations in its own desktop entry, but that only
  # makes it a *candidate* handler; the default comes from
  # ~/.config/mimeapps.list, which home/xdg-mime-apps.nix owns. application/pdf
  # is in the zen-browser flake's own list at mkDefault, so this overrides it
  # cleanly — same shape as home/neovim.nix's text types.
  xdg.mimeApps.defaultApplications = lib.genAttrs readableTypes (_: "org.gnome.Papers.desktop");
}
