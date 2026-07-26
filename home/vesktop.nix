# Vesktop settings/Vencord plugin config ported verbatim from the
# operator's real ~/.config/vesktop/{settings.json,settings/settings.json}
# (home/vesktop-config/*.json — copied as real JSON rather than
# hand-transcribed to Nix attrs, since the Vencord plugin list alone is
# ~180 entries and a copy-paste-verified JSON file is far less error-prone
# than retyping that by hand). Only edit made to either file: dropped
# vencord-settings.json's cloud.settingsSyncVersion (a runtime last-sync
# timestamp, not a real preference).
#
# Transparency: went through three iterations before landing here, each
# ruling out a real problem with the previous one rather than guessing —
# worth keeping the history since the wrong-looking-simpler options are
# exactly what a future edit would be tempted to retry:
#   1. niri's own opacity window-rule ALONE (home/niri/cfg/rules.kdl) —
#      works, but it's a blunt, whole-composited-frame multiplier with no
#      concept of text vs. background: it dims every pixel equally,
#      making message text semi-transparent and hard to read. Confirmed
#      live.
#   2. VencordSettings.store.transparent (real Electron-level alpha,
#      confirmed via reading src/main/mainWindow.ts directly — unlike the
#      Windows-only transparencyOption vibrancy dropdown, this one has no
#      platform check) + the theme's --remove-bg-layer toggle, WITHOUT
#      niri opacity. Fixes the text problem (real per-pixel alpha, CSS
#      background-color changes don't touch text color), but
#      --remove-bg-layer only strips one specific wrapper element
#      (.bg__960e4) — every individual panel (chat, sidebar, cards) has
#      its OWN separate background variable, untouched by that toggle, so
#      panels stayed fully opaque. Confirmed live.
#   3. **Landed on**: combine both — real Electron transparency (this
#      settings.json's `transparent: true`) + --remove-bg-layer (strips
#      the base wrapper so there's an actual hole for that alpha channel)
#      + explicit alpha added to the two background variables that
#      actually matter (--bg-3/--bg-4, see extraQuickCss below), via
#      color-mix so it still tracks whatever Noctalia's palette currently
#      resolves to rather than a hardcoded color. No niri opacity at all —
#      text stays fully opaque since only background-color is touched.
#
# --bg-3/--bg-4 identified by reading the theme's @import'd base
# stylesheet directly (refact0r.github.io/midnight-discord/build/midnight.css):
# --bg-3 drives --app-frame-background/--chat-background-default/card
# backgrounds; --bg-4 drives the lowest-level base background
# (--background-base-low/-lower/-lowest). Both are only ever consumed as
# background-color, never as a text/foreground color. --bg-1/--bg-2 (button
# colors) deliberately left alone — solid, legible buttons matter more than
# consistency here.
#
# The active Discord theme (Noctalia's "discord" community template,
# discord-midnight.css — a fork of refact0r/midnight-discord) also has two
# unrelated built-in toggles, independent of whichever transparency
# mechanism is in use: --transparency-tweaks (hides a couple of decorative
# gradient overlays that look wrong once things are transparent),
# --panel-blur (backdrop-filter blur on floating elements only — context
# menus/tooltips/popups, not the sidebar or message area, so text
# legibility is untouched there either). Since the generated theme file
# itself is Noctalia's to own (not managed here — see below), all of this
# is set via extraQuickCss instead: a genuinely separate output file
# (settings/quickCss.css, confirmed via reading home-manager's own
# mkVesktopLikeModule.nix), no conflict with Noctalia's writes, same
# pattern as ghostty/gtk/qt's separate-file treatment. useQuickCss is
# already true in the ported
# vencord-settings.json.
#
# Deliberately does NOT set programs.vesktop.vencord.themes for
# "noctalia"/"noctalia-material" — the two theme CSS files already present
# on the operator's real machine (~/.config/vesktop/themes/*.theme.css)
# turned out to be Noctalia's own community "discord" template output, not
# hand-installed themes (confirmed by reading
# noctalia-dev/community-templates/discord/template.toml: its
# discord_midnight_vesktop/discord_material_vesktop ids write exactly those
# paths). Managing them here would conflict with Noctalia's own writes, the
# same class of conflict already avoided for ghostty/gtk/qt. See
# home/noctalia.nix, where "discord" is added to community_ids instead.
#
# Custom tray/splash assets: ~/.config/vesktop/userAssets/{splash,tray,
# trayUnread} are real, hand-customized binary files (an animated GIF
# splash screen, two 64x64 PNG tray icons) that Vesktop reads by fixed
# filename convention — no settings.json key references them, and no
# home-manager option exists for this (confirmed by reading
# mkVesktopLikeModule.nix/vesktop/default.nix in full). Wired directly via
# xdg.configFile below. Small, static, rarely-changed binaries, so a plain
# Nix store copy is the right call here (unlike wallpapers/'s live-clone
# treatment for a much larger, frequently-changing collection).
#
# Launcher identity: renamed "Discord" (matching the operator's real,
# currently-live AUR vesktop.desktop — nixpkgs' own packaged entry says
# "Vesktop") and using the operator's real custom launcher icon, confirmed
# via that same live desktop file (Icon= there already points at this exact
# tray.png, so no new asset was needed — home/vesktop-assets/discord-icon.png
# is a byte-identical, .png-extensioned copy of the already-ported
# vesktop-assets/tray, since an absolute-path Icon= needs a real image
# extension to be sniffed correctly). Overriding via xdg.desktopEntries.vesktop
# works because home-manager's own module installs it as a hiPrio package
# providing share/applications/vesktop.desktop — same filename as nixpkgs'
# packaged one, so ours wins in the profile (confirmed by reading
# modules/misc/xdg/desktop-entries.nix: "You can ... override existing
# entries"). categories/mimeType/genericName mirror nixpkgs' own vesktop.desktop
# so nothing already working (discord:// deep links, menu category) regresses;
# only name/icon actually change. StartupWMClass is "vesktop" (lowercase) —
# confirmed live by launching the real nixpkgs-built binary under niri and
# reading `niri msg windows`' own app_id, not copied from either packaged
# .desktop file assuming it was right (nixpkgs' own says "Vesktop", capital,
# which is wrong for the actual running process).
#
# Self-gates on osConfig.features.niri, same convention as home/vscode.nix.
{
  config,
  lib,
  osConfig,
  ...
}:
let
  opacity = import ./transparency.nix;
in
lib.mkIf osConfig.features.niri {
  programs.vesktop = {
    enable = true;
    settings = builtins.fromJSON (builtins.readFile ./vesktop-config/settings.json);
    vencord.settings = builtins.fromJSON (builtins.readFile ./vesktop-config/vencord-settings.json);

    vencord.extraQuickCss = ''
      body {
        --transparency-tweaks: on;
        --panel-blur: on;
        --remove-bg-layer: on;
        --bg-3: color-mix(in srgb, var(--bg-3) ${toString (builtins.floor (opacity * 100))}%, transparent);
        --bg-4: color-mix(in srgb, var(--bg-4) ${toString (builtins.floor (opacity * 100))}%, transparent);
      }
    '';
  };

  # extraQuickCss (mkVesktopLikeModule.nix) writes this via home.file with
  # no force option exposed through the module itself. Vesktop creates an
  # empty placeholder here on its own first launch whenever useQuickCss is
  # enabled (which it already was, before extraQuickCss was ever set) — a
  # real pre-existing file on any host that's already run Vesktop once,
  # not a transient activation race. Forced here so a fresh
  # nixos-rebuild switch doesn't fail the first time this lands on a host.
  home.file."${config.xdg.configHome}/vesktop/settings/quickCss.css".force = true;

  xdg.configFile = {
    "vesktop/userAssets/splash".source = ./vesktop-assets/splash;
    "vesktop/userAssets/tray".source = ./vesktop-assets/tray;
    "vesktop/userAssets/trayUnread".source = ./vesktop-assets/trayUnread;
  };

  xdg.desktopEntries.vesktop = {
    name = "Discord";
    genericName = "Internet Messenger";
    exec = "vesktop %U";
    icon = ./vesktop-assets/discord-icon.png;
    categories = [
      "Network"
      "InstantMessaging"
      "Chat"
    ];
    mimeType = [ "x-scheme-handler/discord" ];
    settings.StartupWMClass = "vesktop";
  };
}
