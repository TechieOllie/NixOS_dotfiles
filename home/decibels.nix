# Audio player. Nothing in this repo could open a music file: with no
# registered audio/* default, xdg-open fell through to whatever
# mimeinfo.cache happened to list — the same gap home/loupe.nix closed for
# images, home/papers.nix for PDFs and home/celluloid.nix for video, closed
# the same way.
#
# Decibels is GNOME's own audio player, GTK4/libadwaita like Nautilus, Loupe
# and Papers, so it inherits this repo's existing Papirus/Bibata/adw-gtk3
# theming (home/gtk.nix, home/cursor.nix) with nothing new needed here. It is
# deliberately a *file* player — one track at a time, no queue and no
# library — which is exactly the role being filled: home/feishin.nix remains
# the library/streaming client, and the two don't overlap. Amberol was the
# alternative considered (queue-based, plays a folder through); it claims
# inode/directory in its desktop entry, which would have had to be left
# unclaimed anyway so Nautilus keeps owning folders.
#
# Self-gates on osConfig.features.niri, same convention as home/loupe.nix and
# home/celluloid.nix.
#
# Verified live on the desktop 2026-08-23: music opens in Decibels.
{
  pkgs,
  lib,
  osConfig,
  ...
}:
let
  # The types Decibels should own. NOT simply its packaged
  # org.gnome.Decibels.desktop MimeType= line: that list is written in the
  # legacy aliases (audio/x-flac, audio/x-mp3, audio/wav,
  # audio/x-vorbis+ogg), and shared-mime-info in this flake's pin resolves
  # real files to the canonical names instead —
  #
  #   .flac -> audio/flac      .ogg/.oga/.opus -> audio/ogg
  #   .m4a  -> audio/mp4       .aac            -> audio/aac
  #   .wav  -> audio/vnd.wave  .mp3            -> audio/mpeg
  #
  # so claiming the desktop entry's list alone would have registered a
  # default for names nothing produces and left most of a real library
  # without one. Checked against shared-mime-info's own globs2, not guessed.
  # The +ogg and x-wav entries below are the specific-alias forms that
  # content sniffing can still return, kept so both spellings resolve.
  #
  # Not claimed: audio/x-mpegurl and application/vnd.apple.mpegurl (.m3u).
  # Decibels has no playlist support, so pointing playlists at it would open
  # one file and silently drop the rest.
  playableTypes = [
    "audio/mpeg"
    "audio/flac"
    "audio/ogg"
    "audio/x-vorbis+ogg"
    "audio/x-opus+ogg"
    "audio/mp4"
    "audio/x-m4b"
    "audio/aac"
    "audio/vnd.wave"
    "audio/x-wav"
    "audio/x-aiff"
    "audio/x-wavpack"
    "audio/x-ape"
    "audio/x-ms-wma"
  ];
in
lib.mkMerge [
  # The package itself: wanted on any desktop host, niri or GNOME.
  (lib.mkIf (osConfig.features.niri || osConfig.features.gnome) {
    home.packages = [ pkgs.decibels ];
  })

  # MIME defaults stay niri-only — see home/papers.nix's comment for why a
  # GNOME host leaves this to GNOME's own default-application mechanism
  # instead.
  (lib.mkIf osConfig.features.niri {
    xdg.mimeApps.defaultApplications = lib.genAttrs playableTypes (_: "org.gnome.Decibels.desktop");
  })
]
