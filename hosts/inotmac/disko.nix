{ ... }:
{
  disko.devices = {
    # The one internal drive: a spinning SATA HDD (WDC WD5000AAKS-402AA0,
    # 500GB, serial WD-WCAWFD627269) — confirmed via
    # `ls -l /dev/disk/by-id/` on the live installer ISO (10.28.31.2), no
    # placeholder involved (unlike the laptop's /dev/CHANGEME). No Fusion
    # Drive, no SSD — this Mid-2011 21.5" iMac (iMac12,1) shipped and still
    # runs on the original HDD.
    disk.main = {
      device = "/dev/disk/by-id/ata-WDC_WD5000AAKS-402AA0_WD-WCAWFD627269";
      type = "disk";
      content = {
        type = "gpt";
        partitions = {
          ESP = {
            size = "1G";
            type = "EF00";
            content = {
              type = "filesystem";
              format = "vfat";
              mountpoint = "/boot";
              mountOptions = [ "umask=0077" ];
            };
          };
          swap = {
            # Matches this machine's RAM (7.7Gi reported by the live
            # installer, i.e. an 8GB machine), for hibernation support via
            # resumeDevice, same as every other real host here.
            size = "8G";
            content = {
              type = "swap";
              resumeDevice = true;
            };
          };
          root = {
            size = "100%";
            content = {
              # Plain ext4, not btrfs+subvolumes like the other two real
              # hosts — a deliberate, operator-made choice for this host
              # specifically: it's a single spinning 2011-era SATA HDD
              # (not the NVMe ARCHITECTURE.md's "CoW overhead is
              # effectively free" argument is about), shared by four
              # accounts. No features.snapshots, no snapper, no subvolumes.
              type = "filesystem";
              format = "ext4";
              mountpoint = "/";
            };
          };
        };
      };
    };
  };
}
