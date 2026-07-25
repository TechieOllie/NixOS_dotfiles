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
}
