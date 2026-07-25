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
# Icon fix: the twilight-official channel's own packaged .desktop entry
# (~/.nix-profile/share/applications/zen-twilight.desktop) sets
# Icon=zen-twilight-official, which matches no installed icon file at
# all — confirmed live that the package only ever ships zen-twilight.png
# (every hicolor size), never a "-official"-suffixed name. Since that name
# resolves to nothing, Noctalia's launcher was falling back to some
# unrelated icon rather than erroring visibly. Fixed the same way as
# Vesktop's launcher override (home/vesktop.nix): xdg.desktopEntries
# installs as a hiPrio package providing share/applications/<name>.desktop,
# so ours wins over the flake-packaged one — same filename, same fields,
# just the one real correction (Icon). Unlike the niri keybind above, this
# can't be made channel-agnostic the same way: overriding a desktop entry
# means matching its exact filename, which differs per channel
# (zen-beta.desktop vs. zen-twilight.desktop) — this entry (and its
# attribute name below) needs updating again if the channel above ever
# changes.
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

    xdg.desktopEntries.zen-twilight = {
      name = "Zen Browser (Twilight)";
      genericName = "Web Browser";
      exec = "zen-twilight --name zen-twilight %U";
      icon = "zen-twilight";
      categories = [
        "Network"
        "WebBrowser"
      ];
      mimeType = [
        "text/html"
        "text/xml"
        "application/xhtml+xml"
        "application/vnd.mozilla.xul+xml"
        "x-scheme-handler/http"
        "x-scheme-handler/https"
      ];
      startupNotify = true;
      settings.StartupWMClass = "zen-twilight";
      actions = {
        new-private-window = {
          name = "New Private Window";
          exec = "zen-twilight --private-window %U";
        };
        new-window = {
          name = "New Window";
          exec = "zen-twilight --new-window %U";
        };
        profile-manager-window = {
          name = "Profile Manager";
          exec = "zen-twilight --ProfileManager";
        };
      };
    };
  };
}
