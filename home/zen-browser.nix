# Zen Browser isn't in nixpkgs at all (confirmed via nix eval against this
# repo's pinned nixpkgs) — packaged via the community zen-browser flake
# input instead (see flake.nix/lib/mkHost.nix). Channel: `beta`, Zen's own
# versioned release channel. It was briefly on `twilight-official` (the
# nightly), which is a *rolling* source: upstream replaces the tarball behind
# an already-locked revision every few days, so the fixed-output source
# derivation starts failing with a hash mismatch on whatever commit happens
# to be pushed next, unrelated to what that commit changed. That cost a
# scheduled CI job whose only purpose was to bump this one input daily.
# `beta` publishes immutable per-release artifacts, so a locked revision
# stays buildable and the lock only moves when the operator moves it.
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
# No desktop-entry override here, unlike home/vesktop.nix. This channel's
# own packaged entry (share/applications/zen-beta.desktop) is internally
# consistent — Icon=zen-browser, and the package really does ship
# zen-browser.png at every hicolor size (verified against the built store
# path). That was *not* true of twilight-official, whose entry pointed at a
# zen-twilight-official icon the package never shipped and which therefore
# needed a hiPrio xdg.desktopEntries copy to correct; that override is gone
# with the channel. If the channel ever changes again, re-check the built
# package's own .desktop and icon names before assuming they line up.
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
  imports = [ zen-browser.homeModules.beta ];

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

    # No BROWSER override needed on this channel. setAsDefaultBrowser = true
    # routes through the flake's own hm-module/default-browser.nix, which
    # derives everything from the *flake attribute* name — `BROWSER =
    # "zen-${name}"`, plus mime associations pointing at `zen-${name}.desktop`.
    # On `beta` the attribute and the package agree (bin/zen-beta,
    # share/applications/zen-beta.desktop), so upstream's own values are
    # already correct; the mkForce that corrected them under
    # `twilight-official` is gone with the channel. The mime half was inert
    # either way: xdg.mimeApps.enable is false, so home-manager writes no
    # mimeapps.list at all and those associations never reach disk.
  };
}
