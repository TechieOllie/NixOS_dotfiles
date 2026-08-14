# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

A flake-based NixOS configuration for three machines, with Home Manager
integrated into the system closure (one `nixos-rebuild switch`, one rollback).

Three documents, three jobs — don't duplicate between them:

- **`ARCHITECTURE.md`** — the design and every convention. The single source of truth; read it in full before making an architectural decision not already reflected in the code.
- **this file** — current state, commands, and the gotchas that will bite again.
- **`docs/decisions.md`** — the investigation log: what was tried, what broke, what was ruled out and why. Read it before re-attempting something, or when you need the reasoning behind a non-obvious choice.
- **`docs/`** also holds runbooks: `bootstrapping-a-host.md`, `secrets.md`, `live-dotfiles.md`.

## Commands

Verification runs through the repo's own driver — use it rather than hand-rolling `nix` invocations:

```bash
.claude/skills/run-nixos-dotfiles/driver.sh check          # eval both hosts + installer-iso, no building. Run first after any change.
.claude/skills/run-nixos-dotfiles/driver.sh eval <host>    # eval one host (seconds)
.claude/skills/run-nixos-dotfiles/driver.sh all <host>     # check + eval. Deliberately eval-only.
.claude/skills/run-nixos-dotfiles/driver.sh build <host>   # realize a full system closure (opt-in, heavy)
.claude/skills/run-nixos-dotfiles/driver.sh iso            # realize the installer ISO (opt-in, heavy)
```

`build`/`iso` are deliberately excluded from `all` — eval catches option
typos, missing imports, and assertion failures, which is the right altitude
for routine verification. The driver never runs `nixos-rebuild switch` or
`nixos-anywhere` against a real machine; those are destructive and are the
operator's to run.

Underneath, and for humans:

```bash
nix flake check                          # works today: evaluates every nixosConfigurations attribute and package.
                                         # Formatting/statix/deadnix checks are NOT wired in yet (Phase 8).
nix build .#nixosConfigurations.<host>.config.system.build.toplevel
nix build .#installer-iso
nixos-rebuild switch --flake .#<host>
nixos-rebuild switch --rollback          # covers NixOS + integrated Home Manager together
nix flake update
nixos-anywhere --flake .#<host> root@<installer-ip>
sops updatekeys hosts/<host>/secrets/secrets.yaml   # re-encrypt after adding a recipient in .sops.yaml
```

`nix flake check` is meant to become the *only* command CI runs — wire new
validation in as a flake check, not a separate script. A `justfile` is
deferred to Phase 8; don't add one earlier.

## Hosts

| Host | State | Filesystem | Notes |
| --- | --- | --- | --- |
| `the-entertaining-nios-vm` | bootstrapped, verified live | ext4, no swap | `features.niri = true`. **All development and verification happens here.** Disposable; only ever gets a throwaway test SSH key. |
| `the-entertaining-nios-laptop` | fully wired, eval-clean, **not installed** | btrfs + 32G swap | The machine this repo is developed on, still running CachyOS. Blocked only on the `/dev/CHANGEME` placeholder in its `disko.nix` (needs `lsblk` from an installer). The install is deliberately on hold — it would wipe the live CachyOS system. |
| `the-entertaining-nios-desktop` | scaffold only | btrfs + 16G swap | No `hardware-configuration.nix`, `secrets.nix`, or `flake.nix` entry yet. Also has a `/dev/CHANGEME` placeholder. |

Both real hosts use the same btrfs subvolumes (`@`, `@home`, `@nix`,
`@snapshots`, `@home_snapshots`) so `features.snapshots` can enable
`modules/services/snapper.nix`; swap is sized to each host's own RAM.
Snapshots are file-level recovery via the `snapper` CLI only — deliberately
not wired into the bootloader, since NixOS generation rollback already covers
boot-time recovery.

## What's on disk

- **`flake.nix`** — composition root only. Inputs: `nixpkgs` (nixos-unstable), `home-manager`, `disko`, `sops-nix`, `noctalia-greeter`, `noctalia`, `zen-browser`. Two `nixosConfigurations` (vm, laptop) built via `lib/mkHost.nix`, plus a `packages.${system}.installer-iso` output.
  - `noctalia` deliberately does **not** `.follows` this repo's nixpkgs — following it would disable Noctalia's Cachix cache and force a from-source build of a native Wayland/OpenGL project on every host. The accepted cost is a second nixpkgs copy in the closure. `zen-browser` *does* follow, having no cache to lose.
- **`lib/mkHost.nix`** — `{ system, hostPath }: nixosSystem`, wiring disko, sops-nix, `modules/options.nix`, the host, and `home-manager.nixosModules.home-manager` (with `useGlobalPkgs`). Threads `noctalia-greeter`/`noctalia`/`zen-browser` through `specialArgs`/`extraSpecialArgs` **without importing them** — the consuming modules import them themselves, so only hosts that want them carry them.
- **`hosts/installer/`** — not a real host and has no `nixosConfigurations` entry: just `variables.nix` holding the operator identity (`user.name`/`fullName`/`sshPublicKey`) that `installer-iso` needs, kept separate so it can't drift from a real host's. A public SSH key isn't a secret, so sops doesn't apply.
- **`modules/options.nix`** — the `features` submodule: `snapshots` and `niri`, both defaulting `false`. A submodule, not `attrsOf bool`, so a typo'd flag is an eval error rather than a silently inert one. `docker`/`steam`/`gamemode` were declared here for a long time without a single module ever reading them, and were removed; re-add each in the same commit as the module that consumes it.
- **`modules/system/`** — `boot`, `networking`, `nix`, `ssh`, `users`, `shell`, `fonts`, `nix-ld`. All unconditional, all bundled by `profiles/base.nix`.
- **`modules/services/`** — `snapper` (gated on `features.snapshots`).
- **`modules/desktop/`** — `niri`, `greetd`, `noctalia`, `theming`, `nautilus`, `unfree`. All gated on `features.niri`.
- **`profiles/base.nix`** — the only profile so far. The universal foundation every host needs regardless of role, not a role itself.
- **`home/`** — machine-agnostic Home Manager entry point (`default.nix`) plus one file per program. There is no per-host Home Manager entry point.
- **`wallpapers/`** — the operator's collection (~35 images), read live from each host's own `~/.dotfiles` clone rather than the Nix store.
- **`.sops.yaml`** — two recipients (vm, laptop), each with its own `creation_rules` entry. The desktop gets one when bootstrapped.
- Short `README.md` in each structural directory: a stable "what belongs here and why", not a changelog. Add one when a new structural directory appears; update one only when that directory's *purpose* changes.
- `overlays/`, `pkgs/`, `scripts/`, `assets/`, `modules/hardware/`, `modules/programs/` don't exist yet.

## Architecture

**Configuration lives in modules, wiring lives in `flake.nix`, machine
identity lives in `variables.nix`, machine capability lives in
`features.nix`.** Layering, top to bottom: `flake.nix` → Host → Profile →
Modules → Options → generated system. Each layer only needs to understand the
one directly below it; a module never knows which host or profile uses it.

- **Two data-passing mechanisms, not interchangeable:**
  - `vars` (identity: hostname, timezone, user) is plain, non-optional data via `specialArgs`. Modules read it as a function argument: `{ vars, ... }:`.
  - `features` (capability toggles) needs real default/override merge semantics, so it's a NixOS option. Modules read `config.features.x`; Home Manager modules read the NixOS side via `osConfig.features.x`.
  - Never pass `features` through `specialArgs` "just in case", and never reach into `hosts/` with an ad hoc `import`. One path per kind of data is load-bearing for the whole merge model.
- **Hosts** describe one machine and stay small: generated `hardware-configuration.nix` (never hand-edited), `variables.nix`, `features.nix` (normal priority, wins over profile defaults), and which profiles they import.
- **Profiles** describe a *role*: they import the modules that role always needs and set feature defaults with `lib.mkDefault`. Treat "add a module import" and "set its matching `mkDefault`" as one atomic edit — an import without a default is inert code sitting in the closure but switched off. Future role profiles should import `base.nix` rather than duplicate it.
- **Modules** configure exactly one feature and gate on `config.features.x` via `lib.mkIf`. Where something splits across system and user config (niri is the canonical case), the system half (package, session entry, greetd wiring) lives in `modules/desktop/` and the user half (keybindings, layout, appearance) in `home/`.
- **`lib/`** holds helpers. Further helpers beyond `mkHost.nix` should wait until the same pattern has been hand-written at least twice across real hosts.
- Prefer readability over cleverness, one responsibility per module, comments explaining *why* not *what*, small commits. Avoid a second source of truth for anything the module system can already merge by priority.

## Operational conventions

- **Secrets**: sops-nix. Each host owns `hosts/<name>/secrets/secrets.yaml`. Decryption uses a standalone per-host age key (`~/.config/sops/age/<host>.txt`, operator-held, never committed) rather than one derived from the SSH host key, which NixOS regenerates on every reinstall. The private key is provisioned via `nixos-anywhere --extra-files`. Adding a host requires generating its age key, adding it as a `.sops.yaml` recipient, and encrypting its secrets — this doesn't fail at `nix flake check`, only at activation on real hardware, so do it in the same commit as the host directory.
- **New host bootstrap**: disko + nixos-anywhere. No manual `fdisk`/`nixos-generate-config` copy-paste.
- **Filesystem is a per-host choice**, not repo policy.
- **Autostarted apps** get their own `systemd.user.services.<name>` (`PartOf`/`After = "graphical-session.target"`, `WantedBy = [ "graphical-session.target" ]`) in their own Home Manager module — not a shared niri autostart file and not the app's own autostart toggle.
- **Naming**: lowercase files named for responsibility (`greetd.nix`, `docker.nix`), not implementation. `hosts/*/features.nix` and a profile's role file don't share a naming pattern despite both setting `features.*` — grep for `features =` / `config.features` when auditing, not for filenames.
- **Plan substantial work before implementing it** (Plan mode), and research the operator's existing real config before deciding what to port. Every phase so far was done this way, and it has repeatedly caught wrong assumptions that eval alone wouldn't.
- **Eval passing is not verification.** Every phase has produced bugs that only surfaced when an app was actually opened on the VM. Confirm behavior live before calling something done.

## Standing gotchas

Each of these has bitten at least once and will again. Full write-ups in
`docs/decisions.md`.

- **Noctalia's runtime sidecar overrides Nix.** `~/.local/state/noctalia/settings.toml` deep-merges *on top of* the Nix-managed `~/.config/noctalia/config.toml`, replacing arrays wholesale, with no conflict warning. Any time `home/noctalia.nix`'s `builtin_ids`/`community_ids`/other array-typed `theme.*` settings change on an already-provisioned host, check that sidecar for a stale override of the same key — a Nix-side change alone is not guaranteed to take effect.
- **`greeter.toml` is seeded once, never overwritten.** `programs.noctalia-greeter.settings` only seeds `/var/lib/noctalia-greeter/greeter.toml` via a systemd-tmpfiles `C` rule, so changes have no effect on an already-booted host until: `sudo rm /var/lib/noctalia-greeter/greeter.toml && sudo systemd-tmpfiles --create && sudo systemctl restart greetd`. This can't be fixed Nix-side.
- **The same shape recurs for any app's own mutable state** — Zen's `xulstore.json` remembering a window geometry, a stale `nvim/lua/plugins/base16.lua`. When a declared setting appears not to apply, look for state the app seeded itself.
- **niri's KDL config is live-symlinked to a separate `~/.dotfiles` clone** on each host (see `docs/live-dotfiles.md`). Edits in this working tree do not reach a host until pushed and pulled there — `scp` the changed files and `niri msg action load-config-file` to test without a full cycle.
- **niri's KDL `environment {}` block does not reach the systemd `--user` manager.** It only applies to niri's own directly-spawned children, so anything launched as a user service (which is everything Noctalia launches) never sees it. Use `environment.sessionVariables` at the NixOS level instead. This is why `NIXOS_OZONE_WL` lives in `modules/desktop/niri.nix`.
- **Noctalia templates that mutate a file in place conflict with Home Manager.** Any official template using `sed -i` or a temp-file-then-`mv` (starship, lazygit) destroys an HM-managed symlink at that path. Use a custom `theme.templates.user.<id>` template that renders the whole file instead, or point the template at a separate output file HM doesn't manage (ghostty, gtk, qt, yazi). Never manage a file Noctalia's template engine owns.
- **`home.sessionVariables` values are not shell-expanded.** They're written into a script as-is, so `"$XDG_CONFIG_HOME/..."` silently resolves to a broken path. Use `${config.xdg.configHome}`.
- **"Existing file … would be clobbered" during activation**: retry the switch once before assuming the config is wrong. It has occurred as a one-off home-manager activation-ordering race.
- **An ad-hoc SSH shell has no session context.** `NIRI_SOCKET`, `SSH_AUTH_SOCK`, and friends are scoped to the graphical session's own systemd user manager; export them manually (`systemctl --user show-environment`) when driving a live session over SSH.
- **`useGlobalPkgs` means Home Manager can't set `nixpkgs.config`.** Unfree allowances must go in `modules/desktop/unfree.nix` at the NixOS level.
- **The VM has its own rendering quirks** (cursor duplication/orientation, occasional MESA errors) traced to `virtio-gpu-gl`/SPICE, not this repo. Don't chase them as config bugs; garbled text is usually virt-manager's View → Scale Display.

## Roadmap

| # | Phase | Status |
| --- | --- | --- |
| 1 | Foundation — structure, `specialArgs`/`features`, sops-nix, disko + nixos-anywhere | done |
| 2 | Profiles — introduced once ≥2 hosts had overlapping imports | in progress: `base.nix` exists; role-specific profiles still deferred, since desktop and laptop haven't diverged. Remaining: bootstrap the desktop, then install the laptop. |
| 3 | Desktop — niri, greetd, Noctalia Greeter, Noctalia Shell, SSH agent unlock | done, verified live |
| 4 | Terminal — Ghostty, Zsh, Starship, Git, Lazygit | done, verified live |
| 5 | Theming — cursor, icons, GTK/Qt | done, verified live |
| 6 | Applications — VS Code, Zen Browser, Vesktop, Nautilus, Feishin, Obsidian | done, verified live |
| 7 | Extra features — Docker, Steam, Proton GE, Tailscale, gaming profile | not started |
| 8 | Long-term — `nix flake check` as the CI gate, `justfile`, doc upkeep, multi-host hardening | not started |

Three once-planned modules were abandoned and will not be created:
`modules/desktop/stylix.nix` (superseded by Noctalia's own native theming —
adding Stylix would mean two systems fighting over the same GTK/Qt/terminal
files), `modules/desktop/portals.nix` (portals come free with `programs.niri`'s
upstream module), and `hardware/bluetooth.nix` (Bluetooth comes from
`programs.noctalia.recommendedServices.enable`). `ARCHITECTURE.md` records all
three; don't re-propose them.

## Software stack

Niri, greetd, Noctalia Greeter, Noctalia Shell v5 (native theming, GTK/Qt theming templates), Papirus icons, Bibata cursors, adw-gtk3, qt5ct/qt6ct · Ghostty, Zsh, Starship, Git, Lazygit, Fastfetch, eza, bat, fd, ripgrep, fzf, zoxide, yazi, btop · Zen Browser, VS Code, Vesktop, Nautilus, Feishin, Obsidian · Steam, Proton GE, Gamescope, MangoHud, Gamemode, Millennium · Tailscale · Docker Engine + Compose · PipeWire, Bluetooth, Printing, NetworkManager, Snapper · nixd, nil, alejandra, statix, deadnix, direnv, just.

Neovim is **not** Home-Manager-managed: `~/.config/nvim` is an ordinary manual
clone of the operator's separate `github:TechieOllie/neovim_dotfiles` repo,
kept on lazy.nvim/Mason. `home/neovim.nix` only provides the toolchain
prerequisites Mason needs at runtime (`gnumake`, `gcc`, `tree-sitter`,
`python3`, `nodejs`, `go`, `php`, `unzip`, `ripgrep`) — plus
`modules/system/nix-ld.nix`, without which Mason's prebuilt manylinux wheels
can't run at all.
