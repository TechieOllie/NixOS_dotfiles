# Bootstrapping a new host

End-to-end runbook for going from an empty `hosts/<name>/` directory to a
booted, declaratively-installed NixOS machine. Rationale for why disko and
nixos-anywhere are used at all is in `ARCHITECTURE.md`'s "Bootstrapping a New
Host" section — this doc is just the steps.

Three distinct keys are in play during a bootstrap; keep them straight:

1. **The operator's SSH key** — baked into the installer ISO, how
   `nixos-anywhere` reaches the target while it's still running the
   installer. One key, reused for every host.
2. **The host's own SSH host key** — generated fresh by NixOS during install,
   used afterward for that host's own sshd. Unrelated to secrets.
3. **The host's sops age key** — generated once by the operator, provisioned
   onto the target during the same install run. Used only to decrypt that
   host's secrets. See `secrets.md` for how this one is created.

## 1. Scaffold the host directory

Before any of this, `hosts/<name>/` should already have `variables.nix`,
`features.nix`, and a `disko.nix` (with a deliberately invalid placeholder
disk device — see step 4), and an entry in `flake.nix`'s
`nixosConfigurations` via `mkHost`.

## 2. Generate `hardware-configuration.nix`

```bash
nixos-generate-config --dir /path/to/hosts/<name>
```

Run this either from the installer environment on the target itself, or —
if the target is still running another Linux distro you have read access to
(as with the laptop while it was still on CachyOS) — read-only alongside the
live install. Either way, **drop the generated `fileSystems` and
`swapDevices` entries** before committing: `disko.nix` owns disk layout, and
leaving the scanned entries in would fight it.

## 3. Wire up secrets

Generate the host's age key, add it as a `.sops.yaml` recipient, and encrypt
its `secrets/secrets.yaml`. Full steps in `secrets.md` — do this before the
install, since the private key needs to be staged in during the
`nixos-anywhere` run (step 6).

## 4. Resolve the real disk device

`disko.nix` starts out with a placeholder (`/dev/CHANGEME`) because the real
device name is only knowable from an installer environment. Boot the target
from the installer (see step 5) and run `lsblk` to find the right device,
then replace the placeholder in `disko.nix` and commit it.

## 5. Build and boot the installer ISO

```bash
nix build .#installer-iso
```

Write the resulting image to a USB drive and boot the target machine from
it. It has the operator's SSH key pre-authorized for root, so no console
interaction is needed beyond booting it and noting its IP.

## 6. Run nixos-anywhere

```bash
nixos-anywhere --flake .#<name> --extra-files ./extra-files root@<installer-ip>
```

`--extra-files` stages arbitrary files onto the target during install —
here, `./extra-files/var/lib/sops-nix/key.txt` should hold the host's private
age key (matching `sops.age.keyFile` in that host's `secrets.nix`), so the
machine boots already able to decrypt its own secrets.

**This step wipes the target disk.** Never run it against a machine still in
daily use unless you mean to replace what's currently on it.

## 7. Clone this repo to `~/.dotfiles` on the new host

```bash
git clone <this repo> ~/.dotfiles
```

Not optional on any host with `features.desktop`: the compositor's config
(niri's KDL or Umbriel's TOML) and Noctalia's wallpaper directory are
symlinked *live* into this clone rather
than copied into the Nix store, so without it those symlinks dangle — the
build still succeeds and the switch still reports success, which is exactly
what makes this easy to miss. See [`live-dotfiles.md`](./live-dotfiles.md).

## 8. Post-install steps Nix cannot do for you

Two things stay imperative by nature, because their state lives outside this
repo entirely. Neither fails loudly — the host will simply be missing the
capability it looks configured for.

(Game libraries on a host with both `features.snapshots` and
`features.gaming` are *not* one of them: the desktop's `disko.nix` declares
`@steam` and `@games` as their own subvolumes mounted into the home
directory, so snapper's `/home` snapshots never contain them. Copy that
pattern to any new gaming host. Adding subvolumes to an *already installed*
host's `disko.nix` does not create them — disko only runs at install — so
see "Adding a subvolume to an installed host" below.)

**Join the tailnet** (any host with `features.tailscale`):

```bash
sudo tailscale up
```

`services.tailscale.enable` only installs and starts the daemon. Node
identity lives in `/var/lib/tailscale`, so a rebuilt host is *ready* to join,
not joined.

**Unlock the SSH agent once** (any host whose `secrets.nix` provisions an SSH
key), from inside a real graphical session, not an ad-hoc SSH shell:

```bash
ssh-add ~/.ssh/id_ed25519
```

After that gnome-keyring caches the passphrase across reboots. See
`docs/decisions.md` for why `ssh-add -l` is the wrong way to check this
worked.

## 9. Verify

```bash
nixos-rebuild switch --flake .#<name>
```

should now work directly on the host for all future changes, from a clone
of this repo.

A host that has no clone — because nobody works on it, so there is no
reason to give it a git identity — rebuilds straight from the public
flake instead, needing neither credentials nor a working tree:

```bash
sudo nixos-rebuild switch --refresh --flake github:TechieOllie/NixOS_dotfiles#<name>
```

`--refresh` is not optional here. Without it Nix reuses whatever revision
it has already cached for that URL, so the rebuild quietly succeeds
against a stale commit and looks exactly like a change that had no
effect. `inotmac` is the host this applies to.

If a change ever breaks the boot, `nixos-rebuild switch --rollback` covers
NixOS and integrated Home Manager together.

## Encrypted host (LUKS + TPM)

`theseus` is the only host so far whose disk is encrypted. The steps above
still apply; these are the differences, in the order they come up. Its
`disko.nix` has the layout and the reasoning behind it.

**Before booting the installer**, turn Secure Boot **off** in the firmware.
Framework's own NixOS guide requires it, and a stock NixOS doesn't boot with
it on. The TPM unlock below still works with Secure Boot off; see the last
paragraph for what that costs.

**Step 2 happens during the install instead.** The target has no other
Linux install to read, so let nixos-anywhere generate the file on the
target itself. **Step 6** also needs the LUKS passphrase. Put it in a local
file only you can read, then pass both:

```bash
install -m 600 /dev/null /tmp/theseus-disk.key
$EDITOR /tmp/theseus-disk.key   # the passphrase; a trailing newline is ignored
nixos-anywhere --flake .#theseus \
  --disk-encryption-keys /tmp/disk.key /tmp/theseus-disk.key \
  --generate-hardware-config nixos-generate-config ./hosts/theseus/hardware-configuration.nix \
  --extra-files ./extra-files \
  root@<installer-ip>
shred -u /tmp/theseus-disk.key
```

`--disk-encryption-keys` copies the local file to the installer's
`/tmp/disk.key`, the path `disko.nix`'s `passwordFile` reads. The
passphrase becomes LUKS keyslot 0 and stays the fallback for good, so
**choose one you can type**: it's what you'll be asked for whenever the TPM
won't release the key, for example after a firmware update.

`.#theseus` has to exist in `flake.nix` for this command to resolve, and
`hosts/README.md` keeps it out until `hardware-configuration.nix` is real.
That's a chicken-and-egg problem. Break it by adding the entry *uncommitted*
for this one run, and commit the entry and the generated file **together**
afterwards. nixos-anywhere (1.13) takes care of the rest of step 2: it runs
`nixos-generate-config --no-filesystems`, so there are no scanned
`fileSystems` to strip, and it marks the new file `git add --intent-to-add`
before evaluating, so the flake can see it.

**After first boot**, three things are machine state no module can declare:

```bash
# Let the TPM unlock the disk from now on. PCR 7 is the Secure Boot state,
# which stays stable across kernel and NixOS updates, unlike PCRs that
# measure the kernel or initrd themselves. Asks for the passphrase once.
sudo systemd-cryptenroll --tpm2-device=auto --tpm2-pcrs=7 /dev/disk/by-partlabel/disk-main-luks

# A high-entropy recovery key in its own slot. It's printed once: store it
# off this machine (password manager or paper), never in this repo.
sudo systemd-cryptenroll --recovery-key /dev/disk/by-partlabel/disk-main-luks

# The fingerprint, for the lock screen, sudo and polkit (not the greeter;
# see modules/desktop/greetd.nix).
fprintd-enroll
```

Reboot once to confirm the disk now opens without a prompt. `sudo
cryptsetup luksDump /dev/disk/by-partlabel/disk-main-luks` should list three
keyslots or tokens: the passphrase, the `systemd-tpm2` token and the
`systemd-recovery` one.

**What TPM unlock with Secure Boot off protects against**: a drive taken out
of the machine. The key is sealed to this board's TPM, so the NVMe alone is
unreadable. It does **not** protect against someone with the whole laptop
and time, who can replace the unencrypted kernel or initrd on `/boot` with
one that keeps the key once the TPM releases it, because with Secure Boot off
nothing checks what boots. Closing that gap means lanzaboote (signed boot
with Secure Boot on) and re-enrolling with `--wipe-slot=tpm2`, and needs no
reinstall.

## Adding a subvolume to an installed host

disko's layout is applied once, by nixos-anywhere. On a running host a new
entry in `disko.nix` only produces a `fileSystems` mount for a subvolume
that doesn't exist yet — and since it isn't `nofail`, booting that
generation fails. Create the subvolume by hand *before* switching. The
desktop's game libraries were moved this way on 2026-09-28, launchers
closed first:

```bash
sudo mkdir -p /mnt/btrfs-root
sudo mount -o subvolid=5 /dev/disk/by-partlabel/disk-main-root /mnt/btrfs-root

# EITHER it is already a nested subvolume (`stat -c %i ~/Games` prints
# 256): a rename, instant.
sudo mv /mnt/btrfs-root/@home/ol/Games /mnt/btrfs-root/@games

# OR it is a plain directory: new subvolume, reflink copy (shares extents,
# no extra space), then remove the original.
sudo btrfs subvolume create /mnt/btrfs-root/@games
sudo cp -a --reflink=always ~/Games/. /mnt/btrfs-root/@games/
rm -rf ~/Games

mkdir ~/Games                        # the mountpoint
sudo umount /mnt/btrfs-root
sudo nixos-rebuild switch --flake .#<name> && reboot
```

Space the old copy occupied only comes back once the `home` snapshots taken
before the move are gone (`sudo snapper -c home delete --sync <first>-<last>`).
