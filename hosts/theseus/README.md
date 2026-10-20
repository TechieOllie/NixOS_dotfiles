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

Installed 2026-10-19. Left to do, in order:

- [x] Firmware: Secure Boot **off** (Framework's guide; NixOS doesn't boot
      with it on without lanzaboote).
- [x] Boot the installer ISO (`nix build .#installer-iso`). From it, resolve
      the two placeholders in `disko.nix`: the disk's `/dev/disk/by-id/` path,
      and the swap size (`free -g`, rounded up).
- [x] Add the public key `ol@theseus` to GitHub (done 2026-10-17).
- [x] Install with nixos-anywhere, generating `hardware-configuration.nix`
      and passing the LUKS passphrase. Then add the flake entry and commit
      both together. Steps: `docs/bootstrapping-a-host.md`, "Encrypted host".
- [x] First boot: enroll the TPM and a recovery key (`systemd-cryptenroll`),
      then the fingerprint (`fprintd-enroll`). These are machine state no
      module can declare.
- [x] Battery charge limit, also machine state: set it once in the BIOS
      ("Battery Charge Limit", e.g. 80%) or with `sudo framework_tool
      --charge-limit 80`, which nixos-hardware installs. Both are stored in
      the embedded controller, not in NixOS, so they survive reinstalls.
      `framework_tool --charge-limit` with no value reads it back.
- [x] Clone `~/.dotfiles`. Umbriel's config and the wallpapers are
      live-symlinked from it, as niri's are on the desktop
      (`docs/live-dotfiles.md`).
- [ ] Verify live. Confirmed on the hardware on 2026-10-19:
  - TPM unlock: cryptroot opened in 1.5 s with no prompt, against 80 s
    typed on first boot
  - fingerprint at the lock screen and `sudo`; password at the greeter
  - the keyring unlocked after a greeter login (`secret-tool store`, then
    `lookup`, with no prompt) and `ssh -T git@github.com` as `ol@theseus`
  - the GPU on `xe` (`/sys/class/drm/card0/device/driver`; `lspci` isn't
    installed) and VA-API on iHD
  - Wi-Fi and the tailnet
  - the panel's scale: 1.6, in `home/umbriel/cfg/layout.toml`
  - the touchscreen, on the panel alone
  - the AZERTY workspace binds, `Mod+&`…`Mod+ç`
  - the scratchpads, `Mod+Shift+Return`, `Mod+M` and `Mod+D`
  - the resize binds, `Mod+)`/`Mod+=`
  - hibernate and resume through the TPM unlock
  - Steam (Millennium) under Umbriel's Xwayland, once `~/.steam/steam` was
    repaired by hand — see `modules/programs/steam.nix`
  - the replay buffer: `Alt+F10` saves to `~/Videos/Replays`
  - a Proton game, through Steam
  - the docked lid hooks (`[events]` in `home/umbriel/cfg/layout.toml`):
    on the dock, opening the lid brings eDP-1 back and shutting it takes
    the panel out again (2026-10-20)

  Still untested:
  - the LUKS passphrase fallback, at the AZERTY prompt — easiest after the
    next firmware update, when the TPM refuses anyway
  - the lid-closed suspend-then-hibernate after 2 h on battery: afterwards
    `journalctl -b -1 -u systemd-suspend-then-hibernate` shows whether it
    did
  - `replay-auto` turning the buffer on by itself when a game opens (it
    logs nothing either way: `pgrep gpu-screen-rec` while the game runs,
    without having pressed the toggle), and the pointer staying inside the
    game (`confine_pointer`)
  - the touchscreen staying on the laptop panel with an external monitor
    connected

See `CLAUDE.md`'s "Hosts" section for the authoritative, kept-current
status.
