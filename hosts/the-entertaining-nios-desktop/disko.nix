{ ... }:
{
  disko.devices = {
    # The 1TB NVMe: the whole of it becomes this machine's system disk.
    # Addressed by /dev/disk/by-id rather than /dev/nvme0n1 — the kernel's
    # enumeration order is not a promise, and an installer that happens to
    # bring the drives up in a different order would otherwise point this
    # layout at the wrong disk. This one is the Samsung SSD 980 1TB, serial
    # S649NL0T998840Y; confirm against `ls -l /dev/disk/by-id/` from the
    # installer before running nixos-anywhere. (The same device also answers
    # to an `nvme-eui.…` alias and a `…_1` duplicate of this name; both are
    # the same disk, this spelling is just the legible one.)
    disk.main = {
      device = "/dev/disk/by-id/nvme-Samsung_SSD_980_1TB_S649NL0T998840Y";
      type = "disk";
      content = {
        type = "gpt";
        partitions = {
          ESP = {
            # Real (non-VM) host: sized for multiple generations/snapshots,
            # unlike the throwaway VM's 512M.
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
            # Matches RAM (16G) so hibernation (suspend-to-disk) works.
            size = "16G";
            content = {
              type = "swap";
              resumeDevice = true;
            };
          };
          root = {
            size = "100%";
            content = {
              type = "btrfs";
              extraArgs = [ "-f" ];
              subvolumes = {
                "@" = {
                  mountpoint = "/";
                  mountOptions = [
                    "compress=zstd"
                    "noatime"
                  ];
                };
                "@home" = {
                  mountpoint = "/home";
                  mountOptions = [
                    "compress=zstd"
                    "noatime"
                  ];
                };
                "@nix" = {
                  # Nix store churns constantly; keep it out of root's
                  # snapshot scope so root snapshots stay small and
                  # meaningful (a rollback of / shouldn't also roll back
                  # /nix, which NixOS generations already manage).
                  mountpoint = "/nix";
                  mountOptions = [
                    "compress=zstd"
                    "noatime"
                  ];
                };
                "@snapshots" = {
                  # Snapper convention: a subvolume's snapshots live in a
                  # ".snapshots" subvolume nested under that subvolume's
                  # own mountpoint.
                  mountpoint = "/.snapshots";
                  mountOptions = [
                    "compress=zstd"
                    "noatime"
                  ];
                };
                "@home_snapshots" = {
                  mountpoint = "/home/.snapshots";
                  mountOptions = [
                    "compress=zstd"
                    "noatime"
                  ];
                };
              };
            };
          };
        };
      };
    };

    # The 2TB drive: bulk storage (game libraries, video), no part of the
    # system closure. Deliberately plain ext4 with a single partition rather
    # than btrfs — nothing here wants snapshots or compression (a games and
    # video library is already-compressed data that btrfs would spend CPU
    # failing to shrink), and features.snapshots' snapper configs cover /
    # and /home only.
    disk.storage = {
      # Placeholder, same convention and same reason as the ESP/swap sizes
      # above being real: this drive is not attached to the machine yet, so
      # its by-id path is unknowable. Resolve it from
      # `ls -l /dev/disk/by-id/` once the drive is physically installed —
      # left obviously invalid so a premature nixos-anywhere run fails loudly
      # rather than silently formatting whatever /dev/sdb happens to be.
      device = "/dev/CHANGEME-storage";
      type = "disk";
      content = {
        type = "gpt";
        partitions = {
          storage = {
            size = "100%";
            content = {
              type = "filesystem";
              format = "ext4";
              mountpoint = "/mnt/storage";
              # nofail is load-bearing, not defensive boilerplate: this is a
              # secondary drive on a machine that has already booted without
              # it. Without nofail, systemd treats the mount as required by
              # local-fs.target and a missing or dead drive drops the whole
              # boot to an emergency shell.
              mountOptions = [ "nofail" ];
            };
          };
        };
      };
    };
  };
}
