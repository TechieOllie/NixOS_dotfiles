# The user half of modules/programs/gpu-screen-recorder.nix: keeps the
# overlay (gsr-ui) running in the background so Alt+Z opens it and its
# replay hotkeys work at any time. Started by this repo's own unit, per the
# autostart convention, rather than by the overlay's own "start on login"
# toggle, which would write a unit into ~/.config behind Home Manager.
#
# The binary must come from the system profile, not from a store path of
# pkgs.gpu-screen-recorder-ui: the NixOS module builds its own copy pointed
# at /run/wrappers, and only that copy finds the capability wrappers.
{
  lib,
  osConfig,
  ...
}:
lib.mkIf osConfig.features.gaming {
  systemd.user.services.gpu-screen-recorder-ui = {
    Unit = {
      Description = "GPU Screen Recorder overlay";
      PartOf = [ "graphical-session.target" ];
      After = [ "graphical-session.target" ];
    };
    Service = {
      ExecStart = "/run/current-system/sw/bin/gsr-ui launch-daemon";
      Restart = "on-failure";
    };
    Install.WantedBy = [ "graphical-session.target" ];
  };
}
