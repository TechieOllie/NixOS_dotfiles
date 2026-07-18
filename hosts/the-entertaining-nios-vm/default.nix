{ vars, ... }:
{
  imports = [
    ./features.nix
    ./disko.nix
    ./hardware-configuration.nix
    ./secrets.nix
    ../../profiles/base.nix
    ../../modules/desktop/niri.nix
    ../../modules/desktop/greetd.nix
    ../../modules/desktop/noctalia.nix
  ];

  networking.hostName = vars.system.hostName;
  time.timeZone = vars.system.timeZone;
  console.keyMap = vars.system.keyMap;

  # QEMU/SPICE guest tooling — belongs directly on this host rather than a
  # shared module, since it's only relevant because this host *is* a VM, not
  # a general capability another host would ever opt into. Syncs cursor
  # (fixes SPICE's own duplicate cursor overlay against niri's), clipboard,
  # and display resolution with the SPICE client.
  services.spice-vdagentd.enable = true;

  # Pinned nixpkgs (nixos-unstable) is currently tracking the 26.11 branch,
  # i.e. 26.05 is the latest released stable version — stateVersion should
  # reference a real release, not the in-development one. Once set, this
  # value should not be bumped on later upgrades; it only marks the
  # compatibility baseline from this host's first install.
  system.stateVersion = "26.05";
}
