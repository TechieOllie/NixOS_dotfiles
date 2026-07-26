# Vesktop settings/Vencord plugin config ported verbatim from the
# operator's real ~/.config/vesktop/{settings.json,settings/settings.json}
# (home/vesktop-config/*.json — copied as real JSON rather than
# hand-transcribed to Nix attrs, since the Vencord plugin list alone is
# ~180 entries and a copy-paste-verified JSON file is far less error-prone
# than retyping that by hand). Only edit made to either file: dropped
# vencord-settings.json's cloud.settingsSyncVersion (a runtime last-sync
# timestamp, not a real preference).
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
  lib,
  osConfig,
  ...
}:
lib.mkIf osConfig.features.niri {
  programs.vesktop = {
    enable = true;
    settings = builtins.fromJSON (builtins.readFile ./vesktop-config/settings.json);
    vencord.settings = builtins.fromJSON (builtins.readFile ./vesktop-config/vencord-settings.json);
  };

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
