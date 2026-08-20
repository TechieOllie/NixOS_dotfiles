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
  # Force Electron's secret storage onto libsecret. Chromium picks a password
  # store by sniffing XDG_CURRENT_DESKTOP, recognises GNOME and KDE and
  # nothing else — under "niri" it finds no keyring, warns that it is falling
  # back to "basic text encryption", and writes Settings Sync and extension
  # credentials to disk in the clear. The keyring itself is fine: verified on
  # the desktop that the login collection is unlocked after a greetd login
  # and that Noctalia already keeps real secrets in it. Only the detection
  # was wrong, and libsecret is already in vscode's closure.
  #
  # A package override rather than a config file, because there is nowhere to
  # put a config file. ~/.config/code-flags.conf was tried first, on the
  # strength of nixpkgs' `code` wrapper sourcing it — but that hook only
  # exists in newer nixpkgs. The wrapper at this pin (VS Code 1.133.0) is a
  # plain makeWrapper script ending in `exec .code-wrapped ... "$@"` and
  # reads no flags file at all, so the file sat on disk read by nothing while
  # VS Code went on warning. Re-check whether that hook has landed before
  # reaching for it again after a `nix flake update`; commandLineArgs is
  # upstream's own supported argument (a string, handed to makeWrapper as
  # --append-flags) and works either way.
  #
  # ~/.vscode/argv.json is the other route VS Code itself supports, and is
  # deliberately not used: it is VS Code's own mutable state, rewritten by
  # the app — the same conflict this repo keeps rediscovering.
  home.packages = [
    (pkgs.vscode.override { commandLineArgs = "--password-store=gnome-libsecret"; })
  ];
}
