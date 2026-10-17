# theseus

Framework 13 Pro, Intel Core Ultra 5 325 (Series 3). Replaces the
never-installed `the-entertaining-nios-laptop`, inheriting its age key and
password hash. It's the desktop's setup on a laptop: `profiles/gaming.nix`,
development, CAD and KDE Connect, and the Noctalia desktop, but on
**Umbriel** instead of niri.

Three properties no other host has:

- **Encrypted disk.** LUKS2 → LVM (swap + btrfs root), unlocked by the TPM at
  boot, with the install passphrase kept as a fallback slot. See
  `disko.nix`.
- **Fingerprint reader** (fprintd, from nixos-hardware) for the lock screen,
  `sudo` and polkit. **Not** for the greeter: the password typed there is
  what unlocks gnome-keyring, and with it the GitHub SSH key from
  `secrets.nix`. See `modules/desktop/greetd.nix`.
- **Touchscreen.** Nothing is declared for it, on purpose. Umbriel enables
  touch by default and, without `input.touch.map_to_output`, maps the screen
  to the device's reported output, or else to the one built-in panel (`eDP-*`).
  That means touch stays on the laptop screen when an external monitor is
  plugged in. Add `[input.touch] map_to_output` to
  `home/umbriel/cfg/input.toml`'s generator in `home/umbriel.nix` only if
  that guess turns out wrong on the hardware.

Not yet in `flake.nix`'s `nixosConfigurations`, deliberately: its
`hardware-configuration.nix` doesn't exist until the machine has booted the
installer (see `hosts/README.md`).

Left to do before this host can be installed, in order:

- [ ] Firmware: Secure Boot **off** (Framework's guide; NixOS doesn't boot
      with it on without lanzaboote).
- [ ] Boot the installer ISO (`nix build .#installer-iso`). From it, resolve
      the two placeholders in `disko.nix`: the disk's `/dev/disk/by-id/` path,
      and the swap size (`free -g`, rounded up).
- [x] Add the public key `ol@theseus` to GitHub (done 2026-10-17).
- [ ] Install with nixos-anywhere, generating `hardware-configuration.nix`
      and passing the LUKS passphrase. Then add the flake entry and commit
      both together. Steps: `docs/bootstrapping-a-host.md`, "Encrypted host".
- [ ] First boot: enroll the TPM and a recovery key (`systemd-cryptenroll`),
      then the fingerprint (`fprintd-enroll`). These are machine state no
      module can declare.
- [ ] Battery charge limit, also machine state: set it once in the BIOS
      ("Battery Charge Limit", e.g. 80%) or with `sudo framework_tool
      --charge-limit 80`, which nixos-hardware installs. Both are stored in
      the embedded controller, not in NixOS, so they survive reinstalls.
      `framework_tool --charge-limit` with no value reads it back.
- [ ] Clone `~/.dotfiles`. Umbriel's config and the wallpapers are
      live-symlinked from it, as niri's are on the desktop
      (`docs/live-dotfiles.md`).
- [ ] Verify live, since none of this has run on the real hardware yet:
  - TPM unlock, and the passphrase fallback
  - fingerprint at the lock screen, `sudo` and polkit, and password-only at
    the greeter
  - the keyring unlocked after a greeter login: `secret-tool store` and then
    `lookup` work without a prompt, and `ssh -T git@github.com` authenticates
    as `ol@theseus`. Not `ssh-add -l`, whose list is transient (see
    `docs/decisions.md`)
  - suspend, and hibernate/resume through LUKS: `systemctl hibernate`
    tests the resume path directly. Lid closed on battery should then
    hibernate on its own after 2 h; afterwards
    `journalctl -b -1 -u systemd-suspend-then-hibernate` shows whether it
    did
  - the GPU is on `xe` (`lspci -k` shows "Kernel driver in use: xe") and
    VA-API works (`vainfo` lists the iHD driver)
  - Wi-Fi
  - Steam under Umbriel's Xwayland
  - the panel's scale, which may need an `[output.eDP-1]` table
  - the touchscreen: taps land where touched, and stay on the laptop panel
    with an external monitor connected (`libinput list-devices` should show
    it with the `touch` capability)
  - the AZERTY binds: `Mod+&`…`Mod+ç` switch workspaces, `Mod+)`/`Mod+=`
    resize
  - scratchpads: `Mod+Shift+Return`, `Mod+M` and `Mod+D` launch, then show
    and hide, the dropdown Ghostty, Feishin and Vesktop. Vesktop starts
    hidden after login. Feishin's app_id is assumed to be `feishin` (from
    its package.json) and has not been seen live (`umbriel windows`)
  - the replay buffer: `systemctl --user status replay-auto` is running,
    starting a Proton game turns the buffer on, and `Alt+F10` saves to
    `~/Videos/Replays`. Needs `UMBRIEL_SOCKET` (or `WAYLAND_DISPLAY`) in the
    user manager's environment, which Umbriel publishes itself
  - games keep the pointer inside them (`confine_pointer`)

See `CLAUDE.md`'s "Hosts" section for the authoritative, kept-current
status.
