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
# just the one real correction (Icon). Unlike the niri keybind in
# home/niri/cfg/keybinds.kdl, which tries each channel's binary in turn, this
# can't be made channel-agnostic the same way: overriding a desktop entry
# means matching its exact filename, which differs per channel
# (zen-beta.desktop vs. zen-twilight.desktop) — this entry (and its
# attribute name below) needs updating again if the channel above ever
# changes.
#
# Self-gates on osConfig.features.niri, same convention as home/vscode.nix.
#
# Transparent Zen mod opacity: the mod itself (installed manually via Zen's
# own Mods UI, not Nix-managed — see below) makes the webpage backplate
# fully see-through with no tint at all; there's no built-in "how much"
# slider for that. To match the rest of this repo's transparent surfaces
# (Ghostty, Noctalia's bar — both driven by the shared opacity value in
# transparency.nix), we give it a custom semi-transparent background color
# instead via its own mod.sameerasw.zen_bg_color_enabled/zen_transparency_color
# prefs (confirmed real via the mod's own preferences.json, mod UUID
# 642854b5-88b4-4c40-b256-e035532109df, github:sameerasw/zen-themes).
#
# Set via policies.Preferences (policies.json), not profiles.<name>.settings
# (prefs.js) — deliberately, not just following the flake's own examples:
# profiles.*.settings requires declaring a profiles.<name> entry, which
# hands the whole profile directory over to Home Manager to manage/create.
# This repo has never done that for Zen (see the "no extension/policy
# porting" comment above), and the VM already has a real ad hoc profile
# from earlier live testing with its own session state — there's no
# guarantee a Nix-declared "default" profile lines up with whatever that
# one is actually called on disk, risking Home Manager creating and
# switching to a second, empty profile instead. policies.Preferences is
# stock home-manager Firefox `policies` (confirmed by reading
# mkFirefoxModule.nix directly): applied at package-wrap time, fully
# independent of any profiles.* declaration, so it reaches whichever
# profile is actually in use with no such risk. Status = "default" (not
# "locked") throughout: seeds the starting value but leaves it a normal,
# user-editable pref afterward, so Transparent Zen's own settings panel
# still works normally for live tweaking.
{
  lib,
  osConfig,
  zen-browser,
  ...
}:
let
  opacity = import ./transparency.nix;
in
{
  imports = [ zen-browser.homeModules.twilight-official ];

  config = lib.mkIf osConfig.features.niri {
    programs.zen-browser = {
      enable = true;
      setAsDefaultBrowser = true;

      policies.Preferences = {
        "browser.tabs.allow_transparent_browser" = {
          Value = true;
          Status = "default";
        };
        "zen.widget.linux.transparency" = {
          Value = true;
          Status = "default";
        };
        "mod.sameerasw.zen_bg_color_enabled" = {
          Value = true;
          Status = "default";
        };
        "mod.sameerasw.zen_transparency_color" = {
          # Plain black, matching this repo's globally dark theming (Noctalia
          # theme.mode = "dark", GTK/Papirus dark variants). 8-digit hex
          # (#RRGGBBAA), NOT CSS rgba()/percentage syntax — confirmed via
          # live devtools inspection that the mod's preference-to-CSS-variable
          # binding silently zeroes out anything that isn't hex (its own
          # default value is "#00000000", the same format), so an rgba()
          # string was accepted as a valid pref value but never actually
          # reached the element it themes.
          Value = "#000000${lib.fixedWidthString 2 "0" (lib.toHexString (builtins.floor (opacity * 255)))}";
          Status = "default";
        };
        "mod.sameerasw.zen_no_shadow" = {
          # The mod's own multi-layer box-shadow around the webpage view
          # (chrome.css) is meant to blend invisibly against an opaque
          # white page — with a transparent backplate it shows up instead
          # as a stray rim just inside niri's own border. Confirmed via
          # live testing.
          Value = true;
          Status = "default";
        };
      };
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

    # Second instance of the same upstream naming bug as the Icon= fix above.
    # setAsDefaultBrowser = true routes through the flake's own
    # hm-module/default-browser.nix, which derives everything from the *flake
    # attribute* name — `BROWSER = "zen-${name}"`, plus mime associations
    # pointing at `zen-${name}.desktop`. Correct for the `beta` and `twilight`
    # channels; wrong for this one, where the attribute is `twilight-official`
    # but the package it builds is plain zen-twilight (confirmed: its store
    # path holds only bin/zen-twilight and share/applications/
    # zen-twilight.desktop — no -official anywhere, in any output).
    #
    # Only BROWSER actually needed fixing. The mime half of the same bug is
    # inert here: xdg.mimeApps.enable is false, so home-manager writes no
    # mimeapps.list at all and those associations never reach disk — verified
    # live on the VM, where the only mimeapps.list is a runtime-written file
    # containing one Discord handler, and `xdg-settings get
    # default-web-browser` already resolves to the correct zen-twilight.desktop
    # via the desktop entry's own MimeType. Overriding them would have been
    # dead config; enabling xdg.mimeApps to make them live would hand
    # home-manager a file that currently works as mutable runtime state.
    #
    # BROWSER is set at normal priority upstream, hence mkForce. Revisit
    # alongside the desktop entry above if the channel ever changes: on `beta`
    # or `twilight` this becomes unnecessary rather than wrong.
    home.sessionVariables.BROWSER = lib.mkForce "zen-twilight";
  };
}
