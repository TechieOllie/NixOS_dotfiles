# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Current state of the repository

Phase 1 (Foundation) is done, Phase 2 (Profiles) is in progress: `flake.nix` still has only one `nixosConfigurations` entry, `the-entertaining-nios-vm` (a VM, bootstrapped and verified via a full nixos-anywhere install), wired directly in `flake.nix` (no `mkHost` helper yet — deferred until a second *bootstrapped* host makes the pattern worth extracting). A second host, `the-entertaining-nios-desktop`, is scaffolded on disk but deliberately **not yet wired into `flake.nix`** — it has no `hardware-configuration.nix` or `secrets.nix` yet since it hasn't been bootstrapped against real hardware. `home/`, `lib/`, `overlays/`, `pkgs/` still don't exist — that's Phase 3+.

What exists on disk today:
- `flake.nix` — inputs (`nixpkgs` nixos-unstable, `home-manager`, `disko`, `sops-nix`), the single `nixosConfigurations.the-entertaining-nios-vm`, and a `packages.${system}.installer-iso` output (a minimal installer ISO with the operator's SSH key pre-authorized for root, so `nixos-anywhere` can bootstrap new hosts without a manual console step).
- `modules/options.nix` — the `features` submodule option (currently: `docker`, `steam`, `gamemode`, `bluetooth`, `sshAgentUnlock`, `snapshots`; all default `false`).
- `modules/system/` — `boot.nix`, `networking.nix`, `nix.nix`, `ssh.nix`, `users.nix`. `modules/services/` now exists with one module, `snapper.nix` (gated on `config.features.snapshots`). No `hardware/`, `desktop/`, or `programs/` subdirectories yet.
- `profiles/base.nix` — the first (and so far only) profile: bundles the 5 `modules/system/*` modules every host needs regardless of role (not a role itself — see the guide's "Filesystem Choice and Snapshots"-adjacent profile-naming discussion). Both hosts import it instead of the individual modules.
- `hosts/the-entertaining-nios-vm/` — fully bootstrapped: `default.nix`, `variables.nix` (`hostName`/`timeZone`/`keyMap`), `features.nix` (all flags `false`), `disko.nix` (single-disk GPT, ESP + ext4 root, no swap), `hardware-configuration.nix`, `secrets.nix` (wires `sops-nix`, `password-hash` marked `neededForUsers`), `secrets/secrets.yaml`.
- `hosts/the-entertaining-nios-desktop/` — scaffold only: `default.nix`, `variables.nix`, `features.nix` (`snapshots = true`, rest `false`), `disko.nix` (btrfs with `@`/`@home`/`@nix`/`@snapshots`/`@home_snapshots` subvolumes, `compress=zstd`+`noatime`, a 16G swap partition with `resumeDevice = true` for hibernation, and a placeholder `/dev/CHANGEME` disk device that must be replaced before any real install). No `hardware-configuration.nix` or `secrets.nix` yet — added once this host is actually bootstrapped.
- `.sops.yaml` — one recipient keyed to `the-entertaining-nios-vm`'s age key only; `the-entertaining-nios-desktop` gets its own recipient added when it's bootstrapped.
- No Home Manager modules under `home/` yet, even though the `home-manager` input is already pinned in `flake.nix` — it isn't wired into `nixosConfigurations` until Phase 3+ needs it.
- No `nix flake check` checks (formatting/statix/deadnix) are wired up yet — that's Phase 7.

The guide (`NixOS-Configuration-Guide.md`) is the single source of truth for this project's design; read it in full before making architectural decisions that aren't already reflected in the code. What follows is a condensed map of its content, not a replacement for it.

## Commands

```bash
nixos-rebuild switch --flake .#the-entertaining-nios-vm   # build and switch to this host's config
nixos-rebuild switch --rollback         # roll back (covers NixOS + integrated Home Manager together)
nix flake update                        # update flake inputs
nix flake check                         # single validation gate (once wired up): formatting (alejandra),
                                         # static analysis (statix), dead code (deadnix), eval of every
                                         # nixosConfigurations attribute
nix build .#nixosConfigurations.the-entertaining-nios-vm.config.system.build.toplevel   # build without switching
nix build .#installer-iso               # build the bootstrap installer ISO
nixos-anywhere --flake .#the-entertaining-nios-vm root@<installer-ip>   # (re-)bootstrap this host
sops updatekeys hosts/the-entertaining-nios-vm/secrets/secrets.yaml     # re-encrypt after adding a recipient in .sops.yaml
```

`nix flake check` is meant to become the *only* command CI runs once it's wired up — it should stay the single thing that gates a commit both locally and in CI, so wire new validation in as a flake check rather than a separate script. A `justfile` wrapping these (`just switch`, `just build`, `just check`, ...) is intentionally deferred to Phase 7, once the commands are actually being typed by hand often enough to justify it — don't add one earlier.

## Architecture

The design separates responsibilities along one line: **configuration lives in modules, wiring lives in `flake.nix`, machine identity lives in `variables.nix`, machine capability lives in `features.nix`.** Layering, top to bottom: `flake.nix` → Host → Profile → Modules → Options → generated system. Each layer only needs to understand the layer directly below it; a module never knows which host or profile is using it.

- **`flake.nix`** is the composition root only — inputs, `nixosConfigurations`, per-host `pkgs`/overlays, Home Manager wiring. It should never contain system settings.
- **Two distinct data-passing mechanisms, not interchangeable:**
  - `vars` (identity: hostname, timezone, user) is plain, non-optional data passed via `specialArgs`. Any module reads it as a function argument: `{ vars, ... }:`.
  - `features` (capability toggles: docker, steam, bluetooth, ...) needs real default/override merge semantics, so it is declared once as a NixOS option (a submodule, in `modules/options.nix` — deliberately *not* `attrsOf bool`, so a typo'd flag is an eval error instead of a silently-inert one) and set through normal module config. Modules read it as `config.features.x`; Home Manager modules read the NixOS side via the `osConfig` special arg (`osConfig.features.x`), since Home Manager doesn't see NixOS `config` directly.
  - Never pass `features` through `specialArgs` "just in case" and never reach into `hosts/` via ad hoc `import` — one path per kind of data is load-bearing for the whole merge model.
- **Hosts** (`hosts/<name>/`) describe one physical machine: generated `hardware-configuration.nix` (never hand-edited), `variables.nix`, `features.nix` (normal-priority, wins over profile defaults), and which profile(s) it imports. Hosts stay small.
- **Profiles** (`profiles/*.nix`) describe a *role*, not a machine: they import the modules a role always needs and set feature defaults with `lib.mkDefault` (low priority) so a host can still override. Treat "add a module import" and "set its matching `mkDefault`" as one atomic edit — an import without a default is inert code sitting in the closure but off. `profiles/base.nix` is the one exception to "a profile is a role" — it's the universal foundation (boot/nix/networking/users/ssh) every host needs regardless of role, extracted once a second host's imports visibly overlapped with the first, per the guide's Phase 2 trigger. Future role-specific profiles (`desktop.nix`, `server.nix`, ...) should import `base.nix` rather than duplicate it.
- **Modules** (`modules/{system,hardware,desktop,services,programs}/`) each configure exactly one feature and gate on `config.features.x` via `lib.mkIf`. For anything split between system and user config (Niri is the canonical example), the system half (package, session entry, greetd wiring) lives in `modules/desktop/`, and the user half (keybindings, layout, appearance) lives in `home/`.
- **`lib/`** holds helper functions (`mkHost.nix`, `mkUser.nix`, ...) — introduce a helper only once the same pattern has already been hand-written at least twice across real hosts, not preemptively.
- Target top-level layout: `hosts/ profiles/ modules/ home/ lib/ overlays/ pkgs/ scripts/ wallpapers/ assets/`. Secrets are not a top-level directory — see below.

## Operational conventions

- **Secrets**: sops-nix from the start. Each host owns `hosts/<name>/secrets/secrets.yaml`, colocated with that host's other data files rather than a shared top-level `secrets/`. Decryption uses a standalone per-host age key (`~/.config/sops/age/<host>.txt`, operator-held, never committed) rather than a key derived from the host's SSH host key — NixOS regenerates the SSH host key on every reinstall, which would otherwise break secrets decryption every time. The private key is provisioned onto the target via `nixos-anywhere --extra-files` in the same run that installs the rest of the config. Never commit plaintext secrets. Adding a host requires generating its age key, adding it as a recipient in `.sops.yaml`, and encrypting its secrets — this doesn't fail at `nix flake check`, only at activation on real hardware, so do it in the same commit as the host directory.
- **New host bootstrap**: disko (declarative disk partitioning as a Nix module, `hosts/<name>/disko.nix`) + nixos-anywhere (`nixos-anywhere --flake .#<host> root@<installer-ip>`) — no manual `fdisk`/`nixos-generate-config` copy-paste.
- **Filesystem is a per-host choice**, not a repo-wide policy: `the-entertaining-nios-vm` uses plain ext4 (disposable test VM, no snapshot need); `the-entertaining-nios-desktop` uses btrfs with subvolumes (`@`, `@home`, `@nix`, `@snapshots`, `@home_snapshots`) so `config.features.snapshots` can enable `modules/services/snapper.nix`. Snapshots are file-level recovery via the `snapper` CLI, deliberately *not* wired into the bootloader (no GRUB/`grub-btrfs` switch) — NixOS's own generation rollback already covers boot-time recovery.
- **SSH agent unlock**: gpg-agent acts as the SSH agent, unlocked via `pam_gnupg` hooked into greetd's PAM service, gated entirely behind `config.features.sshAgentUnlock`.
- **Naming**: lowercase files named for responsibility (`bluetooth.nix`, `docker.nix`), not implementation. `hosts/*/features.nix` and a profile's role file (`gaming.nix`) don't share a naming pattern even though both set `features.*` — grep for `features =` / `config.features` when auditing, not for filenames.
- Prefer readability over cleverness, one responsibility per module, comments that explain *why* not *what*, and small commits. Avoid a second source of truth for anything the module system can already merge by priority.

## Roadmap (implementation order)

1. **Foundation** — repo structure, flake `specialArgs`/`features` option wiring, sops-nix, disko + nixos-anywhere, first bootable host with no profiles yet. ✅ done (`the-entertaining-nios-vm`).
2. **Profiles** — introduced only once ≥2 hosts exist with visibly overlapping imports. ← in progress: `profiles/base.nix` extracted once `the-entertaining-nios-desktop` was scaffolded with the same base imports as the VM. Remaining: actually bootstrap `the-entertaining-nios-desktop` (hardware-configuration.nix, secrets, wire into `flake.nix`), and introduce role-specific profiles once a third host's role diverges enough to need one.
3. **Desktop environment** — Niri, greetd, Noctalia Greeter, Stylix, SSH agent auto-unlock.
4. **Terminal environment** — Ghostty, Zsh, Starship, Git, Lazygit, shell migrated into Home Manager.
5. **Applications** — VS Code, Zen Browser, Vesktop, Nautilus.
6. **Extra features** — Docker, Steam, Proton GE, Tailscale, gaming profile.
7. **Long-term** — `nix flake check` as the CI gate, `justfile` command runner, doc upkeep, multi-host hardening.

## Software stack (for context on what modules will eventually cover)

Niri, greetd, Noctalia Greeter/V5, Stylix, GTK/Qt theming · Ghostty, Zsh, Starship, Git, Lazygit, Fastfetch, eza, bat, fd, ripgrep, fzf, zoxide, yazi, btop · Zen Browser, VS Code, Vesktop, Nautilus · Steam, Proton GE, Gamescope, MangoHud, Gamemode, Millennium · Tailscale · Docker Engine + Compose · PipeWire, Bluetooth, Printing, NetworkManager, Snapper (btrfs snapshots) · nixd, nil, alejandra, statix, deadnix, direnv, just.
