# Zen Browser isn't in nixpkgs at all (confirmed via nix eval against this
# repo's pinned nixpkgs) — packaged via the community zen-browser flake
# input instead (see flake.nix/lib/mkHost.nix). Originally set to beta,
# matching the AUR zen-browser-bin build the operator ran at the time;
# bumped to twilight-official (upstream zen-browser/desktop's own release
# artifact for the twilight nightly channel, not the flake maintainer's
# re-hosted mirror — see the flake's own package.nix/sources.json) at the
# operator's explicit request, ahead of what beta tracks.
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
  imports = [ zen-browser.homeModules.twilight-official ];

  config = lib.mkIf osConfig.features.niri {
    programs.zen-browser = {
      enable = true;
      setAsDefaultBrowser = true;
    };
  };
}
