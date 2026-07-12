{ vars, ... }:
{
  imports = [
    ./features.nix
    ./disko.nix
    ./hardware-configuration.nix
    ./secrets.nix
    ../../profiles/base.nix
    ../../modules/services/snapper.nix
  ];

  networking.hostName = vars.system.hostName;
  time.timeZone = vars.system.timeZone;
  console.keyMap = vars.system.keyMap;

  # Provisional: the latest released stable at scaffold time. Reconfirm
  # against the actually-released version when this host is bootstrapped for
  # real, then leave it untouched — it only marks the compatibility baseline
  # from first install, same rule as the-entertaining-nios-vm.
  system.stateVersion = "26.05";
}
