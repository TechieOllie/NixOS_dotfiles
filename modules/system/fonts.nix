# System-level font installation and the fontconfig defaults every toolkit
# resolves through. Unconditional, no features.* flag — same reasoning as
# modules/system/shell.nix: every real host that gets a terminal environment
# needs this, so there's no per-host axis of variation for a flag to express.
#
# Two families, one job each:
#   - Adwaita Sans — the shared UI font for every graphical surface (Noctalia's
#     bar and panels, GTK apps, Qt apps). Ships in the same `adwaita-fonts`
#     package as Adwaita Mono; upstream's own description is "Adwaita Sans, a
#     variation of Inter, and Adwaita Mono, Iosevka customized to match Inter",
#     so this is simultaneously the "matches libadwaita/adw-gtk3 natively"
#     choice and the "neutral modern UI sans" one.
#   - JetBrains Mono Nerd Font — terminal/editor monospace, unchanged
#     (home/ghostty.nix's font-family, plus the Nerd Font glyphs Starship and
#     eza depend on). Deliberately NOT replaced by Adwaita Mono, which carries
#     no Nerd Font patches.
#
# defaultFonts is the actual single lever that unifies UI typography, and is
# why neither this file nor home/qt.nix sets a per-app Qt font. Every toolkit
# ultimately asks fontconfig to resolve the generic family names: Noctalia's
# own default for shell.font_family is the literal string "sans-serif", GTK's
# default gtk-font-name is "Sans 10", and Qt's default font resolves the same
# way. Before this was set, each of those independently landed on whatever
# fontconfig happened to rank first (DejaVu Sans), which is how the bar,
# Nautilus and a Qt dialog could all disagree about the UI font while every
# one of them was "correctly" using its own default.
#
# Doing this here rather than in home/ matters for the same reason
# modules/desktop/theming.nix installs cursors system-wide: noctalia-greeter
# runs before login, outside any user's Home Manager profile, so a user-scoped
# fontconfig setting would leave the greeter on a different font from the
# session it launches. It also avoids the qt5ct/qt6ct font problem — those
# store their font preference as a serialized QFont blob
# (`@Variant(\0\0\0@...)`) that can't be written as plain INI text through
# home-manager's qt5ctSettings, so letting Qt fall through to fontconfig is
# the only clean way to get it on the same family as everything else.
{ pkgs, ... }:
{
  fonts.packages = [
    pkgs.adwaita-fonts
    pkgs.nerd-fonts.jetbrains-mono
  ];

  # serif is deliberately NOT set. Only sansSerif and monospace describe UI
  # surfaces; serif is what a web page or document asks for when it actually
  # wants a serif face, and pointing it at Adwaita Sans would silently render
  # those in a sans — a content bug dressed up as theming. Left to nixpkgs'
  # own default (DejaVu Serif).
  fonts.fontconfig.defaultFonts = {
    sansSerif = [ "Adwaita Sans" ];
    monospace = [ "JetBrainsMono Nerd Font" ];
  };
}
