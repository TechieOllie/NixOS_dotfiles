{ pkgs, vars, ... }:
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
    ../../modules/services/moonshine.nix
    ../../modules/services/kdeconnect.nix

    # The desktop stack, the same five modules the VM imports — this is the
    # machine's daily driver session, not a headless box. features.niri in
    # ./features.nix is the matching flag; the two are one edit.
    ../../modules/desktop/niri.nix
    ../../modules/desktop/greetd.nix
    ../../modules/desktop/noctalia.nix
    ../../modules/desktop/theming.nix
    ../../modules/desktop/nautilus.nix
  ];

  # Pin the login greeter to the primary monitor. amdgpu exposes a
  # `Writeback-1` DRM connector alongside the two real ones (DP-1, HDMI-A-1),
  # and noctalia-greeter's default behaviour — mirror onto every output —
  # counts it as a third display, builds a surface on it that can never be
  # presented, and dies with an xdg_surface protocol error before it draws
  # anything. The result is a black screen with a live cursor. Naming one
  # connector skips the multi-output path entirely.
  #
  # Host-level, not in modules/desktop/greetd.nix: a connector name describes
  # this machine's cabling, and the VM (which shares that module) has neither
  # a DP-1 nor a writeback connector.
  programs.noctalia-greeter.settings.output.name = "DP-1";

  networking.hostName = vars.system.hostName;
  time.timeZone = vars.system.timeZone;
  console.keyMap = vars.system.keyMap;

  # CachyOS's gaming kernel. Host-level rather than a module, on the same
  # reasoning as the VM's spice-vdagentd: this is a choice about *this*
  # machine (the one that runs games), not a capability another host would
  # opt into — and profiles/gaming.nix deliberately doesn't impose a
  # kernel on every future gaming host. The attribute comes from the
  # chaotic-nyx overlay, which modules/programs/steam.nix brings in via
  # profiles/gaming.nix; the same flake's binary cache is what keeps this
  # from being a from-source kernel build.
  boot.kernelPackages = pkgs.linuxPackages_cachyos;

  # Stop the Logitech Z407's control puck from also driving the host's volume.
  #
  # The speaker enumerates a HID consumer-control keyboard (046d:0a4c, event8)
  # next to its audio interface. Turning the puck moves the speaker's own
  # amplifier *and* sends KEY_VOLUMEUP/DOWN, which keybinds.kdl acts on — two
  # independent gain stages for one gesture, while the keyboard's volume keys
  # move only one. That mismatch is the symptom: dial and keyboard disagree.
  #
  # Verified on hardware, not inferred. With those two binds commented out so
  # the host volume could not move, turning the puck still changed loudness —
  # which is only possible if the puck reaches the amplifier directly. A
  # capture of event8 during the same test shows one clean press/release per
  # detent, so this is not key repeat or a double-firing device.
  #
  # Windows does not have this problem because it drives the speaker's UAC
  # Feature Unit, so its slider and the puck converge on the *same* gain
  # element. Linux cannot: kernel 7.1's check_sticky_volume_control() disables
  # that unit at probe (`sticky mixer values ... disabling`), leaving the host
  # with software attenuation that stacks on top of the amplifier instead of
  # being it. See docs/decisions.md.
  #
  # A hwdb remap of the three volume usages rather than LIBINPUT_IGNORE_DEVICE
  # on the whole node: the same HID interface also carries play/pause/next/prev
  # (confirmed present in event8's keybits), and ignoring the device would take
  # those with it. The codes are HID consumer-page usages — 0xE9 increment,
  # 0xEA decrement, 0xE2 mute — not evdev keycodes. Mapping them to `reserved`
  # clears the keybit, so nothing is emitted for niri to act on. It is matched
  # on this speaker's own vendor:product, so a keyboard's volume keys are
  # untouched and still reach volume-step.
  #
  # The trade-off, accepted: with no reachable hardware control, the host
  # cannot know the amplifier's position, so Noctalia's OSD no longer tracks
  # the puck. That is how any speaker with a physical knob behaves.
  #
  # Host-level for the same reason as the kernel and lact below: it describes a
  # peripheral plugged into this machine, not a capability another host would
  # opt into. hwdb is read at device enumeration, so a switch alone won't apply
  # it to an already-connected speaker — replug it, or run
  # `sudo udevadm trigger --subsystem-match=input --action=change`.
  services.udev.extraHwdb = ''
    evdev:input:b0003v046Dp0A4C*
      KEYBOARD_KEY_c00e9=reserved
      KEYBOARD_KEY_c00ea=reserved
      KEYBOARD_KEY_c00e2=reserved
  '';

  # Fan curves, clock and power limits for the Radeon RX 6600. amdgpu
  # itself needs nothing declared — the kernel driver and Mesa's RADV are
  # already the default — so this is the only GPU-specific config the
  # machine needs. Host-level for the same reason as the kernel above: it
  # describes this machine's hardware, not a reusable capability.
  services.lact.enable = true;

  # The 2TB bulk-storage drive from ./disko.nix. Host-level for the same
  # reason as the kernel and lact above: only this machine has this drive.
  #
  # disko formats the ext4 filesystem but its root directory ends up owned by
  # root, so the `d` rule is what actually makes it writable as the user. The
  # `L+` symlink puts it one click away in Nautilus and in every file dialog
  # without mounting anything inside /home — a mountpoint under /home would
  # sit in the middle of snapper's @home scope (features.snapshots), and
  # would silently look like an empty folder rather than a missing disk if
  # the drive ever dropped out. It deliberately isn't in home/: that entry
  # point is machine-agnostic (there's no per-host Home Manager module), so a
  # symlink declared there would dangle on the VM and the laptop.
  systemd.tmpfiles.rules = [
    "d /mnt/storage 0755 ${vars.user.name} users - -"
    "L+ /home/${vars.user.name}/Storage - - - - /mnt/storage"
  ];

  # Provisional: the latest released stable at scaffold time. Reconfirm
  # against the actually-released version when this host is bootstrapped for
  # real, then leave it untouched — it only marks the compatibility baseline
  # from first install, same rule as the-entertaining-nios-vm.
  system.stateVersion = "26.05";
}
