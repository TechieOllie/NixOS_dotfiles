# Vesktop settings/Vencord plugin config ported verbatim from the
# operator's real ~/.config/vesktop/{settings.json,settings/settings.json}
# (home/vesktop-config/*.json — copied as real JSON rather than
# hand-transcribed to Nix attrs, since the Vencord plugin list alone is
# ~180 entries and a copy-paste-verified JSON file is far less error-prone
# than retyping that by hand). Only edit made to either file: dropped
# vencord-settings.json's cloud.settingsSyncVersion (a runtime last-sync
# timestamp, not a real preference).
#
# Transparency: settled on niri's own opacity window-rule
# (home/niri/cfg/rules.kdl) as the SOLE mechanism, uniformly across the
# whole window, rather than Vesktop's own VencordSettings.store.transparent
# (confirmed via reading src/main/mainWindow.ts directly that this
# unconditionally sets `transparent: true` on the Electron BrowserWindow —
# unlike the Windows-only transparencyOption vibrancy dropdown, this one
# has no platform check at all, so it's real, not merely a UI omission).
# Tried first as a belt-and-suspenders pair (same reasoning as Zen's
# fallback), paired with the theme's own --remove-bg-layer toggle (see
# below) to reveal it — but the combination made the *background*
# (removed by --remove-bg-layer, revealing the real Electron alpha
# channel) and the *panels* (only ever affected by niri's opacity) get
# inconsistently different transparency once niri's own multiplier was
# tuned, since each was driven by a different one of the two mechanisms.
# Simplified to niri opacity alone (uniform, single source of truth) —
# transparent reverted to false, --remove-bg-layer left off. Revisit
# VencordSettings.store.transparent again if niri's opacity alone ever
# stops being sufficient (e.g. a niri regression) — known live to work as
# of this writing, just not needed once niri handles the whole effect.
#
# The active Discord theme (Noctalia's "discord" community template,
# discord-midnight.css — a fork of refact0r/midnight-discord) has two
# other built-in toggles kept on regardless of the above (confirmed by
# reading both the local file and its @import'd base stylesheet,
# refact0r.github.io/midnight-discord/build/midnight.css, directly):
# --transparency-tweaks (hides a couple of decorative gradient overlays
# that look wrong once things are transparent), --panel-blur
# (backdrop-filter blur on floating elements only — context menus/
# tooltips/popups, not the sidebar or message area, so text legibility is
# untouched) — both independent of whichever mechanism is doing the actual
# see-through work. Since the generated theme file itself is Noctalia's to
# own (not managed here — see below), these are set via extraQuickCss
# instead: a genuinely separate output file (settings/quickCss.css,
# confirmed via reading home-manager's own mkVesktopLikeModule.nix), no
# conflict with Noctalia's writes, same pattern as ghostty/gtk/qt's
# separate-file treatment. useQuickCss is already true in the ported
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
lib.mkIf osConfig.features.niri {
  programs.vesktop = {
    enable = true;
    settings = builtins.fromJSON (builtins.readFile ./vesktop-config/settings.json);
    vencord.settings = builtins.fromJSON (builtins.readFile ./vesktop-config/vencord-settings.json);

    vencord.extraQuickCss = ''
      body {
        --transparency-tweaks: on;
        --panel-blur: on;
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
