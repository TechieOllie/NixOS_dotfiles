# theseus

Framework 13 Pro, Intel Core Ultra 5 325 (Series 3). Replaces the
never-installed `the-entertaining-nios-laptop`, inheriting its age key and
password hash. It's the desktop's setup on a laptop: `profiles/gaming.nix`,
development, CAD and KDE Connect, and the Noctalia desktop, but on
**Umbriel** instead of niri.

Two properties no other host has:

- **Encrypted disk.** LUKS2 → LVM (swap + btrfs root), unlocked by the TPM at
  boot, with the install passphrase kept as a fallback slot. See
  `disko.nix`.
- **Fingerprint reader** (fprintd, from nixos-hardware) for the lock screen,
  `sudo` and polkit. **Not** for the greeter: the password typed there is
  what unlocks gnome-keyring, and with it the GitHub SSH key from
  `secrets.nix`. See `modules/desktop/greetd.nix`.

Not yet in `flake.nix`'s `nixosConfigurations`, deliberately: its
`hardware-configuration.nix` doesn't exist until the machine has booted the
installer (see `hosts/README.md`).

Left to do before this host can be installed, in order:

- [ ] Firmware: Secure Boot **off** (Framework's guide; NixOS doesn't boot
      with it on without lanzaboote).
- [ ] Boot the installer ISO (`nix build .#installer-iso`). From it, resolve
      the two placeholders in `disko.nix`: the disk's `/dev/disk/by-id/` path,
      and the swap size (`free -g`, rounded up).
- [ ] Add the public key `ol@theseus` (printed when it was generated; also
      `ssh-keygen -y` on the decrypted secret) to GitHub.
- [ ] Install with nixos-anywhere, generating `hardware-configuration.nix`
      and passing the LUKS passphrase. Then add the flake entry and commit
      both together. Steps: `docs/bootstrapping-a-host.md`, "Encrypted host".
- [ ] First boot: enroll the TPM and a recovery key (`systemd-cryptenroll`),
      then the fingerprint (`fprintd-enroll`). These are machine state no
      module can declare.
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
  - suspend, and hibernate/resume through LUKS
  - Wi-Fi
  - Steam under Umbriel's Xwayland
  - the panel's scale, which may need an `[output.eDP-1]` table

See `CLAUDE.md`'s "Hosts" section for the authoritative, kept-current
status.
