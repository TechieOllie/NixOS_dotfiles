# Video player. Nothing in this repo could open a video file: with no
# registered video/* default, xdg-open fell through to whatever
# mimeinfo.cache happened to list — the same gap home/loupe.nix closed for
# images and home/papers.nix for PDFs, closed the same way.
#
# Celluloid is a GTK4/libadwaita front-end for mpv, so it matches Nautilus,
# Loupe and Papers and inherits this repo's existing Papirus/Bibata/adw-gtk3
# theming (home/gtk.nix, home/cursor.nix) with nothing new needed here.
#
# GNOME's own Showtime was the first choice and had to be abandoned: it is a
# GStreamer front-end, and GStreamer reports a *missing decoder* for the
# telemetry track GoPro cameras mux into every clip
# (meta/x-gst-fourcc-gpmd). Showtime's handler for that message blocks its
# main loop forever on pipeline.get_state(Gst.CLOCK_TIME_NONE), so the window
# is never mapped at all: the process plays the audio, holds the
# org.gnome.Showtime D-Bus name, and shows nothing. mpv ignores the track, so
# Celluloid has no equivalent failure. docs/decisions.md has the full
# measurement.
#
# REVISIT: this choice is about that one upstream bug, not about mpv vs.
# GStreamer, and Showtime is the better fit for the rest of the session if it
# is ever fixed. The fix is a known one-liner —
# https://gitlab.gnome.org/GNOME/showtime/-/merge_requests/96, open and
# unmerged since 2026-07-27, against
# https://gitlab.gnome.org/GNOME/showtime/-/issues/299. Note that landing it
# is necessary but *not* sufficient: with the MR applied by hand, the window
# opened but sat paused on a "Missing Plugin / Unable to Play Video" page
# needing a "Try Anyway" click per file (upstream issues #298 and #277).
# Switch back only once a GoPro clip plays without that prompt.
#
# Self-gates on osConfig.features.niri, same convention as home/loupe.nix and
# home/papers.nix.
{
  pkgs,
  lib,
  osConfig,
  ...
}:
let
  # The video/* half of Celluloid's own packaged desktop entry MimeType= line
  # (read out of this flake's locked nixpkgs, not guessed).
  #
  # Its audio/* half — some 60 types — is deliberately not claimed here:
  # home/decibels.nix owns the audio defaults, and a video player quietly
  # becoming the system's music handler would fight it. Same for the entry's
  # x-scheme-handler/rtsp and friends: a streaming-protocol handler is not
  # what was asked for.
  playableTypes = [
    "video/3gp"
    "video/3gpp"
    "video/3gpp2"
    "video/divx"
    "video/dv"
    "video/fli"
    "video/flv"
    "video/mp2t"
    "video/mp4"
    "video/mp4v-es"
    "video/mpeg"
    "video/mpeg-system"
    "video/msvideo"
    "video/ogg"
    "video/quicktime"
    "video/vnd.mpegurl"
    "video/vnd.rn-realvideo"
    "video/webm"
    "video/x-avi"
    "video/x-flc"
    "video/x-fli"
    "video/x-flv"
    "video/x-m4v"
    "video/x-matroska"
    "video/x-mpeg"
    "video/x-mpeg-system"
    "video/x-mpeg2"
    "video/x-ms-asf"
    "video/x-ms-wm"
    "video/x-ms-wmv"
    "video/x-ms-wmx"
    "video/x-msvideo"
    "video/x-nsv"
    "video/x-ogm+ogg"
    "video/x-theora"
    "video/x-theora+ogg"
  ];
in
lib.mkMerge [
  # The package itself: wanted on any desktop host, niri or GNOME. Same
  # GoPro/Showtime reasoning applies regardless of desktop environment —
  # this is a GStreamer bug, not a niri-specific one.
  (lib.mkIf (osConfig.features.niri || osConfig.features.gnome) {
    home.packages = [ pkgs.celluloid ];
  })

  # MIME defaults stay niri-only — see home/papers.nix's comment for why a
  # GNOME host leaves this to GNOME's own default-application mechanism
  # instead.
  (lib.mkIf osConfig.features.niri {
    xdg.mimeApps.defaultApplications = lib.genAttrs playableTypes (
      _: "io.github.celluloid_player.Celluloid.desktop"
    );
  })
]
