{ config, vars, ... }:
{
  imports = [
    ./features.nix
    ./disko.nix
    ./hardware-configuration.nix
    ./secrets.nix
    ../../profiles/base.nix
    ../../modules/desktop/gnome.nix
    ../../modules/programs/chrome.nix
    ../../modules/services/printing.nix
  ];

  networking.hostName = vars.system.hostName;
  time.timeZone = vars.system.timeZone;
  console.keyMap = vars.system.keyMap;

  # Firmware for the Radeon HD 6750M (Turks/Whistler, radeon driver — not
  # amdgpu, which has no PCI ID match for anything pre-GCN), the Broadcom
  # Bluetooth controller's patch blob, and the Realtek microcode. Confirmed
  # live on the installer ISO that radeon already binds and does full KMS
  # with no extra kernel params needed, and that Bluetooth (btusb) and Wi-Fi
  # (ath9k — Atheros, not Broadcom; fully in-kernel, no firmware file at all)
  # both come up clean already, so this is the one remaining piece worth
  # stating explicitly rather than relying on whatever the installer image
  # happened to default to.
  hardware.enableRedistributableFirmware = true;

  # Fan control: applesmc autoloads and exposes real sensors (confirmed live
  # — `fan=3`, hwmon0/coretemp both present) but nothing here drives an
  # active curve — Apple's SMC firmware holds its own fixed floor on its
  # own. Deliberately left alone for now (operator's call, not a gap found
  # during research): revisit only if the machine actually runs hot under
  # real GNOME use.

  # SANE (modules/services/printing.nix, features.printing) and whipper
  # (home/whipper.nix) both need real device-group membership that neither
  # package grants on its own. Applied to every account on this shared
  # machine, not just ol, since all four people use the same physical
  # scanner-capable printer and the same optical drive.
  users.groups.scanner.members = [
    vars.user.name
  ]
  ++ map (u: u.name) vars.extraUsers;
  users.groups.cdrom.members = [
    vars.user.name
  ]
  ++ map (u: u.name) vars.extraUsers;

  # This machine has no Ethernet run to it — it joined the network over
  # Wi-Fi during install and has no wired fallback, so a host that boots
  # without credentials is a host nobody can reach. Declared here rather
  # than in a module because an SSID describes where this one machine
  # physically sits, the same reasoning that keeps the desktop's kernel
  # and lact host-level.
  #
  # The PSK never enters the store or git: sops decrypts it to an
  # environment file at activation and NetworkManager substitutes
  # $WIFI_PSK by name while writing the profile.
  networking.networkmanager.ensureProfiles = {
    environmentFiles = [ config.sops.secrets.wifi-env.path ];
    profiles.home = {
      connection = {
        id = "home";
        type = "wifi";
        autoconnect = true;
      };
      wifi = {
        ssid = "Unknown SSID";
        mode = "infrastructure";
      };
      wifi-security = {
        key-mgmt = "wpa-psk";
        psk = "$WIFI_PSK";
      };
      ipv4.method = "auto";
      ipv6.method = "auto";
    };
  };

  # Provisional: reconfirm against the actually-released stable at install
  # time, then leave untouched — same rule as every other host's
  # system.stateVersion.
  system.stateVersion = "26.05";
}
