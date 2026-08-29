# the-entertaining-nios-desktop

An ASRock B550M Pro4 with a Ryzen 5 5600X, 16 GB of RAM and a Radeon RX 6600,
still running CachyOS. It is the only host that imports `profiles/gaming.nix`,
and it carries the full niri + Noctalia desktop stack.

Wired on the Nix side: real `disko.nix` (both disks), `features.nix`, a
generated `hardware-configuration.nix`, a `nixosConfigurations` entry in
`flake.nix`, a dedicated sops age key registered in `.sops.yaml`, an
encrypted `secrets/secrets.yaml` + `secrets.nix`, and the five
`modules/desktop/*` imports matching `features.niri = true`.

`secrets.nix` provisions two things: the login password hash, and a real
per-host SSH key decrypted to `~/.ssh/id_ed25519` and unlocked at login by
the GCR agent niri already runs. Its public half — add this one to GitHub —
is:

```
ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAINK969JoQS2K7NuxD5TYEP+2QXevdSdwpc6BAb/lAWRt ol@the-entertaining-nios-desktop
```

That is a different identity from the operator's bootstrap key, which exists
to reach installer ISOs. Both now appear in every host's `variables.nix`
`sshPublicKeys` list: this repo is edited here and remote rebuilds are driven
from here, so the desktop has to be able to reach the other machines as
itself.

Two disks, deliberately asymmetric:

- **1 TB Samsung 980 NVMe** — the system disk, addressed by `by-id`. Whole
  disk: 1 G ESP, 16 G swap (hibernation), btrfs root with the repo's standard
  subvolumes. Currently holds Windows, which the install replaces.
- **2 TB drive** — bulk storage, plain ext4 at `/mnt/storage` with a
  `~/Storage` symlink, `nofail` so a missing drive can't block boot. Now
  physically attached and addressed by its real `by-id` path (Seagate
  ST2000DM008, serial ZK3055P8). It still carries its old NTFS partition
  labelled `Extra`, which the install destroys.

The 500 GB Samsung 860 EVO holding the live CachyOS install is deliberately
**not** declared in `disko.nix` at all, so the install leaves it alone and it
stays bootable as a fallback system.

Left to do before this host can actually be installed:

- [ ] Copy anything worth keeping off the 2 TB drive's existing NTFS
      partition (`Extra`) — `disko` reformats the whole disk.
- [ ] Run `nixos-anywhere` — the destructive step. It wipes the NVMe
      (Windows) and reformats the 2 TB drive.

After install:

- [ ] `git clone <this repo> ~/.dotfiles` — **not optional** with
      `features.niri`. niri's KDL config and Noctalia's wallpapers are live
      symlinks into that clone and dangle silently without it
      (`docs/live-dotfiles.md`).
- [ ] `sudo tailscale up`, and `ssh-add ~/.ssh/id_ed25519` once from inside a
      real graphical session (not an SSH shell — see `docs/decisions.md` for
      why `ssh-add -l` is the wrong way to check it worked).

See `CLAUDE.md`'s "Hosts" section for the authoritative, kept-current status;
this list is a convenience copy for whoever is working in this directory.
