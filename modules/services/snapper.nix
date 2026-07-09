{ config, lib, vars, ... }:
lib.mkIf config.features.snapshots {
  services.snapper = {
    snapshotInterval = "hourly";
    cleanupInterval = "1d";
    configs = {
      root = {
        subvolume = "/";
        extraConfig = ''
          ALLOW_USERS="${vars.user.name}"
          TIMELINE_CREATE="yes"
          TIMELINE_CLEANUP="yes"
        '';
      };
      home = {
        subvolume = "/home";
        extraConfig = ''
          ALLOW_USERS="${vars.user.name}"
          TIMELINE_CREATE="yes"
          TIMELINE_CLEANUP="yes"
        '';
      };
    };
  };
}
