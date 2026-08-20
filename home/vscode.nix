# Package only, deliberately no programs.vscode.* config. The operator has
# 7 hand-built named VS Code profiles (Docker, ESP-IDF, Flutter, Java,
# Python, Web Dev, C/C++) and already relies on VS Code's own built-in
# Settings Sync day-to-day — confirmed a real, active workflow (not just
# available) via a live settingsSync.ignoredExtensions key in their real
# settings.json. Decided with the operator to keep Settings Sync as the
# sync mechanism rather than porting settings/extensions/profiles into Nix:
# it already solves this exact problem, and replicating profile-level
# parity across all 7 would be a large lift for something already working.
# Nix's only job here is making sure the vscode binary exists at all.
#
# Self-gates on osConfig.features.niri, same convention as
# home/gtk.nix/qt.nix/cursor.nix — a GUI app, not a terminal tool, so it
# has a real per-host axis of variation (unlike zsh/git/ghostty, which
# every host wants regardless of desktop environment).
{
  pkgs,
  lib,
  osConfig,
  ...
}:
lib.mkIf osConfig.features.niri {
  home.packages = [ pkgs.vscode ];

  # Force Electron's secret storage onto libsecret. Chromium picks a
  # password store by sniffing XDG_CURRENT_DESKTOP, recognises GNOME/KDE and
  # nothing else — under "niri" it finds no keyring, warns that it is falling
  # back to "basic text encryption", and writes Settings Sync and extension
  # credentials to disk in the clear. The keyring itself is present and, as
  # of modules/desktop/greetd.nix, actually unlocked at login; only the
  # detection was missing, and libsecret is already in vscode's closure.
  #
  # code-flags.conf, not ~/.vscode/argv.json: nixpkgs' own `code` wrapper
  # sources this file (and the .desktop entries all exec that wrapper, so it
  # applies from the launcher as well as the shell), while argv.json is VS
  # Code's own mutable state — it rewrites it, which is exactly the
  # app-owned-state conflict this repo keeps running into.
  xdg.configFile."code-flags.conf".text = ''
    --password-store=gnome-libsecret
  '';
}
