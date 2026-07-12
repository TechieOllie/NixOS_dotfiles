{ config, lib, vars, ... }:
lib.mkIf config.features.snapshots {
  services.snapper = {
    snapshotInterval = "hourly";
    cleanupInterval = "1d";
    configs = {
      root = {
        SUBVOLUME = "/";
        ALLOW_USERS = [ vars.user.name ];
        TIMELINE_CREATE = true;
        TIMELINE_CLEANUP = true;
      };
      home = {
        SUBVOLUME = "/home";
        ALLOW_USERS = [ vars.user.name ];
        TIMELINE_CREATE = true;
        TIMELINE_CLEANUP = true;
      };
    };
  };
}
