# GPU Screen Recorder: hardware-encoded recording with a ShadowPlay-style
# replay buffer ("save the last N seconds"), through the RX 6600's own
# encoder so it costs almost no frame rate. The system half, because both
# pieces need capability wrappers only NixOS can create: gsr-kms-server
# (cap_sys_admin) to capture without a portal prompt each time, and
# gsr-global-hotkeys (cap_setuid) so the overlay's Alt+Z works under any
# Wayland compositor. The overlay's background service is the user half,
# in home/gpu-screen-recorder.nix.
{ config, lib, ... }:
lib.mkIf config.features.gaming {
  programs.gpu-screen-recorder = {
    enable = true;
    ui.enable = true;
  };
}
