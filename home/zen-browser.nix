# Zen Browser isn't in nixpkgs at all (confirmed via nix eval against this
# repo's pinned nixpkgs) — packaged via the community zen-browser flake
# input instead (see flake.nix/lib/mkHost.nix). Beta channel, matching the
# AUR zen-browser-bin build the operator actually runs today; the flake's
# twilight/twilight-official channels are both a newer, more unstable
# nightly channel than what's running now, not a closer match.
#
# No extension/policy porting: the operator's real profile (bookmarks,
# logins, manually-installed extensions like uBlock Origin/Dark Reader/
# Obsidian Web Clipper) lives in mutable Firefox-style profile state
# (~/.config/zen/<profile>/...), out of scope for Nix the same way it
# always is in this repo. Zen's own theming (userChrome.css/userContent.css)
# is handled by Noctalia's "zen-browser" community template instead (see
# home/noctalia.nix) — it mutates that same mutable profile state directly,
# so there's nothing for Nix to conflict with here either.
#
# Self-gates on osConfig.features.niri, same convention as home/vscode.nix.
{
  lib,
  osConfig,
  zen-browser,
  ...
}:
{
  imports = [ zen-browser.homeModules.beta ];

  config = lib.mkIf osConfig.features.niri {
    programs.zen-browser = {
      enable = true;
      setAsDefaultBrowser = true;
    };
  };
}
