{ vars, ... }:
let
  home = "/home/${vars.user.name}";

  btrfsOpts = [
    "compress=zstd"
    "noatime"
  ];
in
{
  # As on the desktop: a mounted subvolume's root is owned by root, and
  # systemd creates any missing parent of a mountpoint as root too, so Steam
  # and Heroic would otherwise find their own libraries unwritable on a fresh
  # install.
  systemd.tmpfiles.rules = map (d: "d ${home}/${d} - ${vars.user.name} users -") [
    ".local"
    ".local/share"
    ".local/share/Steam"
    "Games"
  ];

  # The only encrypted host so far: ESP, then one LUKS2 container holding an
  # LVM volume group with swap and the btrfs root.
  #
  # LVM-on-LUKS rather than ARCHITECTURE.md's usual plain swap partition,
  # deliberately. A swap partition beside the LUKS one would need its own
  # encryption — a second container, so a second TPM enrollment and a second
  # recovery key to keep in step — and swap here *has* to be encrypted:
  # hibernation writes all of RAM to it, keyring and SSH agent included. One
  # container means one unlock covers root, swap and resume alike.
  disko.devices = {
    disk.main = {
      # The 1T WD_BLACK SN7100, by /dev/disk/by-id/ as on the desktop —
      # kernel enumeration order is not a promise. Read from the installer
      # (`ls -l /dev/disk/by-id/`) on 2026-10-19.
      device = "/dev/disk/by-id/nvme-WD_BLACK_SN7100_1TB_26011T802238";
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
          luks = {
            size = "100%";
            content = {
              type = "luks";
              name = "cryptroot";
              # The passphrase for the initial luksFormat only, read from the
              # installer's /tmp — nixos-anywhere puts it there with
              # `--disk-encryption-keys /tmp/disk.key <local file>`. It
              # becomes keyslot 0: the fallback typed at boot whenever the
              # TPM refuses (firmware update, cleared TPM, another machine).
              # The TPM slot itself is enrolled after first boot, since
              # disko has no TPM enrollment; see
              # docs/bootstrapping-a-host.md.
              passwordFile = "/tmp/disk.key";
              settings = {
                # TRIM through to the NVMe. Leaks which blocks are free, the
                # standard trade for SSD wear and performance.
                allowDiscards = true;
                # Try the TPM first, then fall back to asking. Needs the
                # systemd initrd (./default.nix); the scripted one ignores
                # crypttab options.
                crypttabExtraOpts = [ "tpm2-device=auto" ];
              };
              content = {
                type = "lvm_pv";
                vg = "pool";
              };
            };
          };
        };
      };
    };

    lvm_vg.pool = {
      type = "lvm_vg";
      lvs = {
        swap = {
          # Matches RAM (32G, MemTotal 30.9 GiB from the installer), so
          # hibernation fits.
          size = "32G";
          content = {
            type = "swap";
            resumeDevice = true;
          };
        };
        root = {
          # disko creates "100%" volumes last and turns this into
          # lvcreate -l 100%FREE, so it takes whatever swap leaves.
          size = "100%";
          content = {
            type = "btrfs";
            extraArgs = [ "-f" ];
            # The same layout as the desktop (see ARCHITECTURE.md's btrfs
            # section), game libraries included, since this host carries
            # profiles/gaming.nix too.
            subvolumes = {
              "@" = {
                mountpoint = "/";
                mountOptions = btrfsOpts;
              };
              "@home" = {
                mountpoint = "/home";
                mountOptions = btrfsOpts;
              };
              "@nix" = {
                mountpoint = "/nix";
                mountOptions = btrfsOpts;
              };
              "@snapshots" = {
                mountpoint = "/.snapshots";
                mountOptions = btrfsOpts;
              };
              "@home_snapshots" = {
                mountpoint = "/home/.snapshots";
                mountOptions = btrfsOpts;
              };
              # Outside @home so snapper's hourly snapshots never pin game
              # files — the desktop's disko.nix has the full story.
              "@steam" = {
                mountpoint = "${home}/.local/share/Steam";
                mountOptions = btrfsOpts ++ [ "x-gvfs-hide" ];
              };
              "@games" = {
                mountpoint = "${home}/Games";
                mountOptions = btrfsOpts ++ [ "x-gvfs-hide" ];
              };
            };
          };
        };
      };
    };
  };
}
