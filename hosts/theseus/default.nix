{
  pkgs,
  vars,
  nixos-hardware,
  ...
}:
{
  imports = [
    ./features.nix
    ./disko.nix
    ./hardware-configuration.nix
    ./secrets.nix
    ../../profiles/base.nix
    ../../profiles/gaming.nix
    ../../modules/services/snapper.nix
    ../../modules/services/docker.nix
    ../../modules/services/tailscale.nix
    ../../modules/services/printing.nix
    ../../modules/services/kdeconnect.nix

    # The desktop stack, on Umbriel: the desktop's six modules with
    # umbriel.nix in place of niri.nix. features.desktop and .umbriel in
    # ./features.nix are the matching flags; one edit.
    ../../modules/desktop/session.nix
    ../../modules/desktop/umbriel.nix
    ../../modules/desktop/greetd.nix
    ../../modules/desktop/noctalia.nix
    ../../modules/desktop/theming.nix
    ../../modules/desktop/nautilus.nix

    # Framework 13 Pro, Intel Core Ultra 5 325 (Series 3). Turns on fprintd
    # — which reaches sudo, polkit and Noctalia's lock screen, and is kept
    # off the greeter by modules/desktop/greetd.nix — plus fwupd (already in
    # base), the Framework EC module and framework-tool, iio sensors for
    # automatic brightness, and laptop power defaults. Its TLP default stands
    # down by itself, because Noctalia's recommendedServices already enables
    # power-profiles-daemon.
    nixos-hardware.nixosModules.framework-intel-core-ultra-series3
  ];

  networking.hostName = vars.system.hostName;
  time.timeZone = vars.system.timeZone;
  console.keyMap = vars.system.keyMap;

  # The newest kernel rather than nixpkgs' default LTS, which Framework's
  # own NixOS guide for this board rules out ("NOT LTS kernel"): Series 3
  # is new enough that its support is still landing upstream release by
  # release. nixos-hardware only bumps the kernel when
  # the default is older than 6.17, which the 6.18 LTS already isn't.
  # Host-level, like the desktop's CachyOS kernel: a statement about this
  # machine's hardware, not about the gaming role it shares.
  boot.kernelPackages = pkgs.linuxPackages_latest;

  # The xe GPU driver, not i915. nixos-hardware's Series 3 module reaches the
  # *generic* Intel GPU profile (common/gpu/intel), which defaults to i915 —
  # loading it in the initrd for early KMS — and installs both VA-API
  # drivers because it doesn't know the generation. Panther Lake's Xe3
  # graphics belong to xe, which is what nixos-hardware's own Lunar Lake
  # profile already selects for the same reason (these two settings, word
  # for word); Series 3 simply never got a profile of its own. Without this
  # the initrd's early-KMS driver binds nothing on this GPU, so the boot
  # screen (and the LUKS passphrase fallback) would most likely be left on
  # the firmware framebuffer. intel-media-driver alone: the legacy
  # intel-vaapi-driver only covers much older generations, so it adds a
  # VA-API driver to probe and nothing it can drive.
  hardware.intelgpu = {
    driver = "xe";
    vaapiDriver = "intel-media-driver";
  };

  # Closing the lid on battery suspends, and hibernates after two hours of
  # that, so a bag-bound laptop doesn't come back flat. Hibernation was
  # already provisioned for: ./disko.nix sizes swap to RAM inside the LUKS
  # container, and resume goes through the same TPM unlock as a cold boot.
  # On external power plain suspend is enough; docked (lid shut, external
  # monitor) stays logind's default of ignore. Noctalia locks before any of
  # these, since its lockscreen hooks logind's PrepareForSleep.
  services.logind.settings.Login = {
    HandleLidSwitch = "suspend-then-hibernate";
    HandleLidSwitchExternalPower = "suspend";
  };
  systemd.sleep.settings.Sleep.HibernateDelaySec = "2h";

  # The systemd initrd: what lets ./disko.nix's crypttab entry unlock from
  # the TPM (tpm2-device=auto), with the passphrase as the fallback prompt.
  # The scripted initrd ignores crypttab options entirely. It also resumes
  # from hibernation inside the same unlocked container.
  boot.initrd.systemd.enable = true;

  # The French keymap in the initrd too, not only from stage 2 on. That
  # passphrase prompt is typed on this AZERTY keyboard, and without early
  # setup the initrd has no vconsole.conf and reads keys as US: a correct
  # passphrase is then simply rejected. The only host that needs this,
  # since it is the only one that asks for anything before stage 2.
  console.earlySetup = true;

  # The latest released stable at first install (2026-10-19; 26.11 is not
  # out yet). Leave it untouched — it only marks the compatibility baseline
  # from first install, same rule as the-entertaining-nios-vm.
  system.stateVersion = "26.05";
}
