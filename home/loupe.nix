# Image viewer. Nothing in this repo could open a picture: Nautilus shows
# thumbnails but hands the file off to xdg-open, and with no registered
# image/* handler that resolved to whatever mimeinfo.cache happened to
# list — in practice Zen Browser, which renders the file but is not a
# viewer (no next/previous through a folder, no zoom controls, no rotate).
#
# Loupe is GNOME's current image viewer (it replaced Eye of GNOME
# upstream), GTK4/libadwaita like Nautilus, so it inherits this repo's
# existing Papirus/Bibata/adw-gtk3 theming (home/gtk.nix, home/cursor.nix)
# with nothing new needed here — same reasoning as home/nautilus.nix.
# Alternatives considered and not taken: imv (Wayland-native but
# keyboard-only and unthemed, wrong fit next to Nautilus), qimgv (Qt, a
# second toolkit for one app), eog (upstream-superseded by Loupe).
#
# Self-gates on osConfig.features.niri, same convention as
# home/nautilus.nix — a GUI viewer only means anything where there's a
# graphical session.
{
  pkgs,
  lib,
  osConfig,
  ...
}:
let
  # The formats Loupe should own. Taken from Loupe's own packaged
  # org.gnome.Loupe.desktop MimeType= line (read out of this flake's
  # locked nixpkgs, not guessed), trimmed to the types actually worth
  # claiming a default for — the raw list also carries a long tail of
  # legacy X bitmap/pixmap and portable-anymap formats that nothing here
  # produces.
  #
  # image/svg+xml is included deliberately: Loupe renders SVG, and leaving
  # it out would send exactly the icon-sized files this repo works with
  # (Papirus SVGs, Moonshine box art sources) to the browser instead.
  viewableTypes = [
    "image/png"
    "image/jpeg"
    "image/gif"
    "image/webp"
    "image/avif"
    "image/heic"
    "image/jxl"
    "image/tiff"
    "image/bmp"
    "image/svg+xml"
    "image/vnd.microsoft.icon"
    "image/x-exr"
    "image/qoi"
  ];
in
lib.mkIf osConfig.features.niri {
  home.packages = [ pkgs.loupe ];

  # Loupe already ships these associations in its own desktop entry, but
  # that only makes it a *candidate* handler; the default still comes from
  # ~/.config/mimeapps.list, which home/xdg-mime-apps.nix owns. Same shape
  # as home/neovim.nix's text types — and it likewise needs that module
  # enabled to reach disk at all.
  xdg.mimeApps.defaultApplications = lib.genAttrs viewableTypes (_: "org.gnome.Loupe.desktop");
}
