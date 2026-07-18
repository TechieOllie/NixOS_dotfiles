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

## 7. Verify

```bash
nixos-rebuild switch --flake .#<name>
```

should now work directly on the host for all future changes. If a change
ever breaks the boot, `nixos-rebuild switch --rollback` covers NixOS and
integrated Home Manager together.
