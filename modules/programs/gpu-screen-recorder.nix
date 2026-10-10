# GPU Screen Recorder: hardware-encoded recording through the RX 6600's own
# encoder, so it costs almost no frame rate. The system half, because
# capturing a monitor without a portal prompt each time goes through
# gsr-kms-server, which needs cap_sys_admin — a capability wrapper only
# NixOS can create. The replay commands and their keybinds are the user
# half, in home/gpu-screen-recorder.nix.
#
# The overlay UI (ui.enable) is deliberately off: see that file for why.
{ config, lib, ... }:
lib.mkIf config.features.gaming {
  programs.gpu-screen-recorder.enable = true;
}
