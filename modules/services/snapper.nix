{
  config,
  lib,
  vars,
  ...
}:
let
  # Snapper's own defaults keep 10 monthly and 10 yearly snapshots, so a
  # deleted file could hold its space for up to a decade. A month of history
  # is enough for file-level recovery (boot-level recovery is NixOS
  # generations' job) and lets deleted data actually leave the disk.
  retention = {
    TIMELINE_LIMIT_HOURLY = 10;
    TIMELINE_LIMIT_DAILY = 7;
    TIMELINE_LIMIT_WEEKLY = 4;
    TIMELINE_LIMIT_MONTHLY = 0;
    TIMELINE_LIMIT_QUARTERLY = 0;
    TIMELINE_LIMIT_YEARLY = 0;
  };
in
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
      }
      // retention;
      # Game libraries under /home are kept out of these snapshots by being
      # separately mounted subvolumes in the host's disko.nix, not by
      # anything here — a snapshot never crosses a mount.
      home = {
        SUBVOLUME = "/home";
        ALLOW_USERS = [ vars.user.name ];
        TIMELINE_CREATE = true;
        TIMELINE_CLEANUP = true;
      }
      // retention;
    };
  };
}
