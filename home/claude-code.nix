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
# The package comes from the `claude-code` flake input rather than nixpkgs,
# so it can be upgraded on its own with `just update-claude-code` without
# moving nixpkgs (see flake.nix). Its package.nix is called with this
# repo's own pkgs — exactly what the input's overlay does — rather than
# taken from its `packages` output, which is built from a nixpkgs instance
# with `allowUnfree = true` and would silently bypass the allow-list above.
# Upstream's wrapper sets DISABLE_AUTOUPDATER, so the binary does not try to
# update itself out of the store.
{
  pkgs,
  lib,
  osConfig,
  claude-code,
  ...
}:
lib.mkIf osConfig.features.development {
  home.packages = [ (pkgs.callPackage "${claude-code}/package.nix" { }) ];
}
