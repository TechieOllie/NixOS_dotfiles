# Claude Code — Anthropic's terminal coding agent. A CLI, so unlike the
# other application modules here it needs no graphical session at all; it
# shares features.development with home/jetbrains.nix because the axis it
# varies along is the same one ("this machine is where work gets done"),
# not because the two are related tools.
#
# Package only, and deliberately so: ~/.claude.json and ~/.claude/ hold the
# OAuth credentials for the operator's account alongside per-project history
# and MCP server registrations — runtime state carrying a real secret, which
# is the standing reason this repo leaves such files to the app (see
# home/feishin.nix).
#
# `pkgs.claude-code` is unfree (Anthropic's commercial terms, not an OSS
# license), so it needs its name in modules/system/unfree.nix — the usual
# useGlobalPkgs consequence: the allow-list can't live in this file even
# though this file is what installs the package.
#
# Upgrades come from `nix flake update`. The binary's own auto-updater
# cannot write into the store and is expected to no-op; a version banner
# nagging about an update is not a broken install.
{
  pkgs,
  lib,
  osConfig,
  ...
}:
lib.mkIf osConfig.features.development {
  home.packages = [ pkgs.claude-code ];
}
