{ ... }:
{
  # Placeholder: this host hasn't been installed yet, so the real disk
  # device is unknown. Replace with the actual device (check via `lsblk`
  # from the installer) before ever running nixos-anywhere against real
  # hardware — left as an obviously-invalid path so a premature run fails
  # loudly instead of silently targeting the wrong disk.
  disko.devices = {
    disk.main = {
      device = "/dev/CHANGEME";
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
            # Matches RAM (32G) so hibernation (suspend-to-disk) works.
            size = "32G";
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
                  mountOptions = [ "compress=zstd" "noatime" ];
                };
                "@home" = {
                  mountpoint = "/home";
                  mountOptions = [ "compress=zstd" "noatime" ];
                };
                "@nix" = {
                  # Nix store churns constantly; keep it out of root's
                  # snapshot scope so root snapshots stay small and
                  # meaningful (a rollback of / shouldn't also roll back
                  # /nix, which NixOS generations already manage).
                  mountpoint = "/nix";
                  mountOptions = [ "compress=zstd" "noatime" ];
                };
                "@snapshots" = {
                  # Snapper convention: a subvolume's snapshots live in a
                  # ".snapshots" subvolume nested under that subvolume's
                  # own mountpoint.
                  mountpoint = "/.snapshots";
                  mountOptions = [ "compress=zstd" "noatime" ];
                };
                "@home_snapshots" = {
                  mountpoint = "/home/.snapshots";
                  mountOptions = [ "compress=zstd" "noatime" ];
                };
              };
            };
          };
        };
      };
    };
  };
}
