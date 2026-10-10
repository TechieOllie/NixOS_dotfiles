# OBS Studio, for recording or streaming anything more involved than the
# replay clips gpu-screen-recorder covers. Screen capture goes through the
# PipeWire portal niri already provides, so it needs no plugin; game-only
# capture (obs-vkcapture) is left out until there is a reason for it.
#
# On features.gaming alongside gpu-screen-recorder: the two recorders came
# in together, and the gaming host is the only one that records.
{ lib, osConfig, ... }:
lib.mkIf osConfig.features.gaming {
  programs.obs-studio.enable = true;
}
