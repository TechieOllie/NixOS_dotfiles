# Off-machine backup of the operator's home to the NAS, with restic.
#
# Snapper's snapshots live on the disk they protect; this is the copy that
# survives the disk. The NAS runs restic's rest-server in append-only mode,
# one private repo per host, so a compromised host can add snapshots but
# not delete old ones. That is also why nothing here forgets or prunes:
# the NAS's own Backrest does it (DockerComposeFiles, MIGRATION 7.5).
#
# The repository URL and the encryption password come from the host's
# sops file (hosts/<name>/secrets.nix declares them): the URL carries the
# rest-server login, and this repo is public.
{
  config,
  lib,
  pkgs,
  vars,
  ...
}:
let
  home = "/home/${vars.user.name}";
  unit = "restic-backups-nas";
in
lib.mkIf config.features.backup {
  assertions = [
    {
      assertion = config.sops.secrets ? restic-repository && config.sops.secrets ? restic-password;
      message = "features.backup needs the restic-repository and restic-password sops secrets in the host's secrets.nix.";
    }
  ];

  services.restic.backups.nas = {
    repositoryFile = config.sops.secrets.restic-repository.path;
    passwordFile = config.sops.secrets.restic-password.path;
    # First run on a new host creates its repo; afterwards a no-op check.
    initialize = true;

    paths = [ home ];
    exclude = [
      # Separate subvolumes holding games (see the hosts' disko.nix):
      # re-downloadable, and large.
      "${home}/.local/share/Steam"
      "${home}/Games"
      "${home}/.cache"
      "${home}/.local/share/Trash"
      # Re-downloadable, by the operator's choice.
      "${home}/Downloads"
    ];
    # Also skips any directory that marks itself as a cache (CACHEDIR.TAG):
    # build trees, browser and toolchain caches outside ~/.cache.
    extraBackupArgs = [ "--exclude-caches" ];

    # Daily, caught up after sleep or power-off (Persistent), spread over
    # an hour so it doesn't land on the exact moment of every wake-up.
    timerConfig = {
      OnCalendar = "daily";
      Persistent = true;
      RandomizedDelaySec = "1h";
    };
    # Idle sleep waits for the upload to finish. Closing the lid still
    # suspends: logind ignores inhibitors for the lid switch by default.
    inhibitsSleep = true;
  };

  # A failed run is otherwise silent: say so on the desktop, through the
  # same systembus-notify channel smartd uses (modules/system/disk-health.nix).
  services.systembus-notify.enable = true;
  systemd.services.${unit}.onFailure = [ "${unit}-failed.service" ];
  systemd.services."${unit}-failed" = {
    description = "Notify that the restic backup to the NAS failed";
    serviceConfig.Type = "oneshot";
    script = ''
      ${pkgs.dbus}/bin/dbus-send --system / net.nuetzlich.SystemNotifications.Notify \
        'string:Backup to the NAS failed' \
        'string:See: journalctl -u ${unit}'
    '';
  };
}
