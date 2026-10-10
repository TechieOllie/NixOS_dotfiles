# Early warning for failing or silently corrupting disks. Snapper (where a
# host has it) is not this: snapshots live on the same disk they protect.
{ config, lib, ... }:
{
  # smartd polls each drive's own SMART health data and reports trouble
  # before a drive dies outright. mkDefault so a host without SMART-capable
  # disks can turn it off: smartd exits with an error when autodetection
  # finds nothing to monitor, which is exactly the VM's virtio disk.
  #
  # Reported as a desktop notification through systembus-notify, because
  # neither default route reaches anyone here: no host has a mail setup,
  # and `wall` only writes to terminals a person happens to be looking at.
  services.smartd = {
    enable = lib.mkDefault true;
    notifications.systembus-notify.enable = true;
  };

  # A monthly read of every block on the root btrfs filesystem, verifying
  # checksums, so silent corruption surfaces while there is still a
  # snapshot or a copy to restore from. Self-gating on the root filesystem
  # type rather than a features flag: there is nothing to choose, only a
  # fact about the host's disks.
  #
  # Only "/": scrub works on a whole filesystem, not a subvolume, and the
  # option's default lists every btrfs *mount point* — on the desktop that
  # is seven subvolumes of the same filesystem, so seven full scrubs of the
  # same data each month.
  services.btrfs.autoScrub = lib.mkIf (config.fileSystems."/".fsType == "btrfs") {
    enable = true;
    fileSystems = [ "/" ];
  };
}
