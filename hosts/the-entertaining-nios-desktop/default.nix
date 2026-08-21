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

  # Wake-on-LAN, and the shutdown path that pairs with it.
  #
  # A Raspberry Pi on the LAN emulates a Wemo smart plug (fauxmo), so "Alexa,
  # turn on Desktop" sends a magic packet to this NIC and "turn off" makes the
  # Pi SSH in and power the machine down. Host-level for the same reason as
  # the kernel and lact above: it names *this* machine's NIC and trusts *one*
  # specific Pi's key, neither of which another host should inherit.
  #
  # The firmware half is not expressible here. "Wake on PCI-E" (or equivalent)
  # has to be set once in the BIOS, or the NIC loses standby power at S5 and
  # the magic packet is never seen. This option only keeps the driver-side
  # flag set across reboots, which ethtool otherwise forgets.
  networking.interfaces.enp4s0.wakeOnLan.enable = true;

  # The Pi's key, pinned to exactly one command. `restrict` drops port, agent
  # and X11 forwarding plus PTY allocation; the forced command overrides
  # whatever the client asks to run. Together they mean a compromised Pi can
  # power this machine off and do nothing else — worth the care, because
  # fauxmo's whole job is running commands named in a config file.
  #
  # Merges with the key set in modules/system/ssh.nix rather than replacing
  # it: authorizedKeys.keys is a list option.
  #
  # -i for the reason moonshine's Shutdown app documents — systemd otherwise
  # refuses while another session or inhibitor is present. --no-block is the
  # SSH-specific half: without it systemctl waits on a job that only finishes
  # as the machine dies, the connection drops before an exit status is sent,
  # and fauxmo reports failure, which Alexa relays as "something went wrong"
  # after a long pause.
  #
  # Authorization comes from the polkit rule in modules/services/moonshine.nix,
  # which already grants this user the two power-off actions from exactly this
  # kind of non-interactive session. That is a real coupling: turning
  # features.moonshine off would leave this key authenticated but unauthorized,
  # failing with InteractiveAuthorizationRequired.
  users.users.${vars.user.name}.openssh.authorizedKeys.keys = [
    ''restrict,command="/run/current-system/sw/bin/systemctl poweroff -i --no-block" ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIHxwuZAw0GuGTMfyukGCt4KDOx8AY6LBGV3tpfJv7Wft fauxmo@wakeonlan''
  ];

  # Provisional: the latest released stable at scaffold time. Reconfirm
  # against the actually-released version when this host is bootstrapped for
  # real, then leave it untouched — it only marks the compatibility baseline
  # from first install, same rule as the-entertaining-nios-vm.
  system.stateVersion = "26.05";
}
