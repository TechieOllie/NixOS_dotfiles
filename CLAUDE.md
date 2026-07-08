# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Current state of the repository

This repo currently contains only `NixOS-Configuration-Guide.md` — the design document for a NixOS flake configuration that has **not been implemented yet** (Phase 1 of the roadmap below has not started). There is no `flake.nix`, no `hosts/`, `modules/`, `profiles/`, or `home/` directory yet, and no build/lint/test tooling to run.

When asked to start implementing, follow the guide's Phase 1 order (see Roadmap) rather than scaffolding the full target structure at once — this repo's stated philosophy is to avoid building abstractions before a real, repeated need exists.

The guide (`NixOS-Configuration-Guide.md`) is the single source of truth for this project's design; read it in full before making architectural decisions. What follows is a condensed map of its content, not a replacement for it.

## Commands (once the flake exists)

```bash
nixos-rebuild switch --flake .          # build and switch to the current host's config
nixos-rebuild switch --rollback         # roll back (covers NixOS + integrated Home Manager together)
nix flake update                        # update flake inputs
nix flake check                         # single validation gate: formatting (alejandra), static
                                         # analysis (statix), dead code (deadnix), eval of every
                                         # nixosConfigurations attribute
nix build .#nixosConfigurations.<host>.config.system.build.toplevel   # build one host without switching
sops updatekeys secrets/secrets.yaml    # re-encrypt secrets after adding a recipient in .sops.yaml
```

`nix flake check` is meant to be the *only* command CI runs — it should stay the single thing that gates a commit both locally and in CI, so wire new validation in as a flake check rather than a separate script. A `justfile` wrapping these (`just switch`, `just build`, `just check`, ...) is intentionally deferred to Phase 7, once the commands are actually being typed by hand often enough to justify it — don't add one earlier.

## Architecture

The design separates responsibilities along one line: **configuration lives in modules, wiring lives in `flake.nix`, machine identity lives in `variables.nix`, machine capability lives in `features.nix`.** Layering, top to bottom: `flake.nix` → Host → Profile → Modules → Options → generated system. Each layer only needs to understand the layer directly below it; a module never knows which host or profile is using it.

- **`flake.nix`** is the composition root only — inputs, `nixosConfigurations`, per-host `pkgs`/overlays, Home Manager wiring. It should never contain system settings.
- **Two distinct data-passing mechanisms, not interchangeable:**
  - `vars` (identity: hostname, timezone, user) is plain, non-optional data passed via `specialArgs`. Any module reads it as a function argument: `{ vars, ... }:`.
  - `features` (capability toggles: docker, steam, bluetooth, ...) needs real default/override merge semantics, so it is declared once as a NixOS option (a submodule, in `modules/options.nix` — deliberately *not* `attrsOf bool`, so a typo'd flag is an eval error instead of a silently-inert one) and set through normal module config. Modules read it as `config.features.x`; Home Manager modules read the NixOS side via the `osConfig` special arg (`osConfig.features.x`), since Home Manager doesn't see NixOS `config` directly.
  - Never pass `features` through `specialArgs` "just in case" and never reach into `hosts/` via ad hoc `import` — one path per kind of data is load-bearing for the whole merge model.
- **Hosts** (`hosts/<name>/`) describe one physical machine: generated `hardware-configuration.nix` (never hand-edited), `variables.nix`, `features.nix` (normal-priority, wins over profile defaults), and which profile(s) it imports. Hosts stay small.
- **Profiles** (`profiles/*.nix`) describe a *role*, not a machine: they import the modules a role always needs and set feature defaults with `lib.mkDefault` (low priority) so a host can still override. Treat "add a module import" and "set its matching `mkDefault`" as one atomic edit — an import without a default is inert code sitting in the closure but off.
- **Modules** (`modules/{system,hardware,desktop,services,programs}/`) each configure exactly one feature and gate on `config.features.x` via `lib.mkIf`. For anything split between system and user config (Niri is the canonical example), the system half (package, session entry, greetd wiring) lives in `modules/desktop/`, and the user half (keybindings, layout, appearance) lives in `home/`.
- **`lib/`** holds helper functions (`mkHost.nix`, `mkUser.nix`, ...) — introduce a helper only once the same pattern has already been hand-written at least twice across real hosts, not preemptively.
- Target top-level layout: `hosts/ profiles/ modules/ home/ lib/ overlays/ pkgs/ secrets/ scripts/ wallpapers/ assets/`.

## Operational conventions

- **Secrets**: sops-nix from the start, per-host `secrets.yaml`, decrypted at activation using a host SSH key. Never commit plaintext secrets. Adding a host requires manually adding its key as a recipient in `.sops.yaml` and re-running `sops updatekeys` — this doesn't fail at `nix flake check`, only at activation on real hardware, so do it in the same commit as the host directory.
- **New host bootstrap**: disko (declarative disk partitioning as a Nix module, `hosts/<name>/disko.nix`) + nixos-anywhere (`nixos-anywhere --flake .#<host> root@<installer-ip>`) — no manual `fdisk`/`nixos-generate-config` copy-paste.
- **SSH agent unlock**: gpg-agent acts as the SSH agent, unlocked via `pam_gnupg` hooked into greetd's PAM service, gated entirely behind `config.features.sshAgentUnlock`.
- **Naming**: lowercase files named for responsibility (`bluetooth.nix`, `docker.nix`), not implementation. `hosts/*/features.nix` and a profile's role file (`gaming.nix`) don't share a naming pattern even though both set `features.*` — grep for `features =` / `config.features` when auditing, not for filenames.
- Prefer readability over cleverness, one responsibility per module, comments that explain *why* not *what*, and small commits. Avoid a second source of truth for anything the module system can already merge by priority.

## Roadmap (implementation order)

1. **Foundation** — repo structure, flake `specialArgs`/`features` option wiring, sops-nix, disko + nixos-anywhere, first bootable host with no profiles yet.
2. **Profiles** — introduced only once ≥2 hosts exist with visibly overlapping imports.
3. **Desktop environment** — Niri, greetd, Noctalia Greeter, Stylix, SSH agent auto-unlock.
4. **Terminal environment** — Ghostty, Zsh, Starship, Git, Lazygit, shell migrated into Home Manager.
5. **Applications** — VS Code, Zen Browser, Vesktop, Nautilus.
6. **Extra features** — Docker, Steam, Proton GE, Tailscale, gaming profile.
7. **Long-term** — `nix flake check` as the CI gate, `justfile` command runner, doc upkeep, multi-host hardening.

## Software stack (for context on what modules will eventually cover)

Niri, greetd, Noctalia Greeter/V5, Stylix, GTK/Qt theming · Ghostty, Zsh, Starship, Git, Lazygit, Fastfetch, eza, bat, fd, ripgrep, fzf, zoxide, yazi, btop · Zen Browser, VS Code, Vesktop, Nautilus · Steam, Proton GE, Gamescope, MangoHud, Gamemode, Millennium · Tailscale · Docker Engine + Compose · PipeWire, Bluetooth, Printing, NetworkManager · nixd, nil, alejandra, statix, deadnix, direnv, just.
