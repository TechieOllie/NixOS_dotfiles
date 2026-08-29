# Google Chrome, system-wide on GNOME hosts.
#
# Deliberately NOT a Home Manager module, unlike every other app here. This
# repo wires Home Manager for exactly one user (lib/mkHost.nix, vars.user),
# so a home.packages entry reaches ol and nobody else — and inotmac is
# shared by four people who all need a browser. environment.systemPackages
# is the only profile every account is on.
#
# GNOME does ship Epiphany (GNOME Web) by default, which is why every other
# app this host once declared has been dropped; Chrome stays because it is
# not a duplicate of anything GNOME provides and was specifically asked for
# (sync/Widevine DRM, not just "a browser"). Setting it as the *default*
# browser is per-user state in GNOME Settings, not something declared here.
#
# Unfree: allow-listed in modules/system/unfree.nix at the NixOS level,
# which is where it has to happen — lib/mkHost.nix's useGlobalPkgs means
# Home Manager shares one already-finalized nixpkgs.config.
#
# The `--password-store=gnome-libsecret` workaround CLAUDE.md documents for
# VS Code under niri is moot here: Chromium/Chrome pick a password store by
# sniffing XDG_CURRENT_DESKTOP, and GNOME sets that correctly on its own.
{
  pkgs,
  lib,
  config,
  ...
}:
lib.mkIf config.features.gnome {
  environment.systemPackages = [ pkgs.google-chrome ];

  # Default browser, system-wide (/etc/xdg/mimeapps.list), so it applies to
  # all four accounts without each person setting it in GNOME Settings —
  # and so it is reproducible from this repo rather than being per-user
  # state. A user who prefers something else still wins: their own
  # ~/.config/mimeapps.list is consulted first.
  #
  # "google-chrome.desktop", NOT "com.google.Chrome.desktop": this package
  # ships both, and the reverse-DNS one is NoDisplay=true — a hidden
  # duplicate. Pointing a default at it would register a handler nothing
  # surfaces, the silent-no-op failure CLAUDE.md documents for MIME
  # defaults. Read out of the package, not guessed.
  #
  # Only the four types Chrome actually declares and that make it "the
  # browser" are claimed. application/pdf is deliberately NOT among them
  # even though Chrome advertises it: GNOME ships Papers, and a PDF is a
  # document here rather than a web page — same reasoning home/papers.nix
  # already applies on the niri hosts.
  xdg.mime.defaultApplications = {
    "text/html" = "google-chrome.desktop";
    "application/xhtml+xml" = "google-chrome.desktop";
    "x-scheme-handler/http" = "google-chrome.desktop";
    "x-scheme-handler/https" = "google-chrome.desktop";
  };
}
