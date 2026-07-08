{ vars, ... }:
{
  imports = [
    ./features.nix
    ../../modules/system/boot.nix
    ../../modules/system/nix.nix
    ../../modules/system/networking.nix
    ../../modules/system/users.nix
  ];

  networking.hostName = vars.system.hostName;
  time.timeZone = vars.system.timeZone;

  # No disko.nix / hardware-configuration.nix yet — this host hasn't been
  # installed for real. system.build.vm overrides fileSystems for its own
  # ephemeral disk, so this placeholder only exists to satisfy eval; it
  # gets replaced when the full disko + nixos-anywhere install happens.
  fileSystems."/" = {
    device = "/dev/disk/by-label/nixos";
    fsType = "ext4";
  };

  # Pinned nixpkgs (nixos-unstable) is currently tracking the 26.11 branch,
  # i.e. 26.05 is the latest released stable version — stateVersion should
  # reference a real release, not the in-development one. Once set, this
  # value should not be bumped on later upgrades; it only marks the
  # compatibility baseline from this host's first install.
  system.stateVersion = "26.05";
}
