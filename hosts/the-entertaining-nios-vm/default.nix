{ vars, ... }:
{
  imports = [
    ./features.nix
    ./disko.nix
    ./hardware-configuration.nix
    ./secrets.nix
    ../../profiles/base.nix
  ];

  networking.hostName = vars.system.hostName;
  time.timeZone = vars.system.timeZone;
  console.keyMap = vars.system.keyMap;

  # Pinned nixpkgs (nixos-unstable) is currently tracking the 26.11 branch,
  # i.e. 26.05 is the latest released stable version — stateVersion should
  # reference a real release, not the in-development one. Once set, this
  # value should not be bumped on later upgrades; it only marks the
  # compatibility baseline from this host's first install.
  system.stateVersion = "26.05";
}
