# Qt platform theme — closes a gap left open since Phase 4: home/zsh.nix and
# home/niri/cfg/misc.kdl have set QT_QPA_PLATFORMTHEME=qt6ct as a bare env
# var since then, but the actual qt5ct/qt6ct packages were deliberately never
# installed (see CLAUDE.md's Phase 4 note). Wired properly here via
# home-manager's own qt.* module instead.
#
# Deliberately color-theming only, no Kvantum, no rounded corners: reading
# Kvantum's own source confirmed its themes (including kvmarwaita, the
# closest rounded/libadwaita-style match) hardcode their own palette and
# never read qt5ct/qt6ct's colors, and reading Noctalia v5's own qt template
# confirmed it specifically targets qt5ct/qt6ct's native [ColorScheme]
# mechanism (which Fusion reads) with no Kvantum awareness at all. Switching
# to Kvantum would mean losing Noctalia's live wallpaper-driven color
# tracking for Qt apps — decided against that trade-off for now; revisit
# Kvantum + kvmarwaita later as its own research task if wanted.
#
# The pre-existing QT_QPA_PLATFORMTHEME env vars in home/zsh.nix and
# home/niri/cfg/misc.kdl become redundant (this module's platformTheme.name
# sets the same value) but harmless — left as-is, no need to touch either
# file for this.
#
# Deliberately NOT setting qt.style.name: that sets QT_STYLE_OVERRIDE, which
# forces one QStyle globally and bypasses qt5ct/qt6ct's own style
# application entirely — confirmed live and in qt5ct's own source
# (mainwindow.cpp's checkConfiguration(): `if (env.contains
# ("QT_STYLE_OVERRIDE")) m_errors << "Please remove the QT_STYLE_OVERRIDE
# environment variable..."`), which is exactly the "not themed correctly"
# warning qt5ct/qt6ct showed once this was set. Nothing is lost by omitting
# it either: qt5ct's own default Appearance.style is already "Fusion"
# (same source, line 363), so qt5ct/qt6ct apply the same style on their own
# once they're actually in charge.
{
  lib,
  config,
  osConfig,
  ...
}:
lib.mkIf osConfig.features.niri {
  qt = {
    enable = true;
    platformTheme.name = "qtct"; # installs + wires qt5ct/qt6ct properly

    # Keeps Qt apps' icon theme in sync with GTK's (home/gtk.nix) — a
    # separate setting since Qt apps read qt5ct/qt6ct's own icon_theme key,
    # not GTK's.
    #
    # color_scheme_path is what actually makes qt5ct/qt6ct *use* Noctalia's
    # live-generated [ColorScheme] file (home/noctalia.nix's "qt" builtin_ids
    # template, ~/.config/qt5ct|qt6ct/colors/noctalia.conf) — confirmed by
    # reading qt5ct's/qt6ct's own appearancepage.cpp source directly, since
    # merely having that file exist doesn't make either app read it. Uses
    # ${config.xdg.configHome} (resolved by Nix at eval time) rather than a
    # literal "$XDG_CONFIG_HOME" string — this is written into a plain INI
    # file the app parses directly, not a shell script, so there's no shell
    # expansion to rely on. Exactly the same class of bug already found and
    # fixed once for home/lazygit.nix's LG_CONFIG_FILE (Phase 4) — avoided
    # here from the start rather than repeated.
    #
    # custom_palette = true is required too, and was the actual remaining
    # bug found via live testing (qt5ct/qt6ct still reported "not themed
    # correctly" with color_scheme_path alone): both apps' own
    # readSettings() only calls loadColorScheme(schemePath, ...) when
    # `!schemePath.isEmpty() && settings.value("custom_palette", false)`
    # — confirmed identical in both qt5ctplatformtheme.cpp and
    # qt6ctplatformtheme.cpp — so color_scheme_path was being silently
    # ignored without this flag, defaulting to false.
    qt5ctSettings.Appearance = {
      icon_theme = "Papirus-Dark";
      color_scheme_path = "${config.xdg.configHome}/qt5ct/colors/noctalia.conf";
      custom_palette = true;
    };
    qt6ctSettings.Appearance = {
      icon_theme = "Papirus-Dark";
      color_scheme_path = "${config.xdg.configHome}/qt6ct/colors/noctalia.conf";
      custom_palette = true;
    };
  };
}
