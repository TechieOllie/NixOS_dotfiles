# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

A flake-based NixOS configuration for three machines, with Home Manager
integrated into the system closure (one `nixos-rebuild switch`, one rollback).

Three documents, three jobs — don't duplicate between them:

- **`ARCHITECTURE.md`** — the design and every convention. The single source of truth; read it in full before making an architectural decision not already reflected in the code.
- **this file** — current state, commands, and the gotchas that will bite again.
- **`docs/decisions.md`** — the investigation log: what was tried, what broke, what was ruled out and why. Read it before re-attempting something, or when you need the reasoning behind a non-obvious choice.
- **`docs/`** also holds runbooks: `bootstrapping-a-host.md`, `secrets.md`, `live-dotfiles.md`, `testing-on-the-vm.md`.

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
nix flake check                          # the full gate: format + statix + deadnix, every
                                         # nixosConfigurations attribute and package, AND a real
                                         # closure build per host. Expensive — see --no-build below.
nix flake check --no-build               # `just check-fast`, and what driver.sh check runs.
nix fmt                                  # nixfmt (RFC 166), in place
nix develop                              # just/nixfmt/statix/deadnix/nixd/nil/sops/age
nix build .#nixosConfigurations.<host>.config.system.build.toplevel
nix build .#installer-iso
nixos-rebuild switch --flake .#<host>
nixos-rebuild switch --rollback          # covers NixOS + integrated Home Manager together
nix flake update
nixos-anywhere --flake .#<host> root@<installer-ip>
sops updatekeys hosts/<host>/secrets/secrets.yaml   # re-encrypt after adding a recipient in .sops.yaml
```

`nix flake check` is the *only* command CI runs, and
`.github/workflows/check.yml` is the *only* workflow — wire new validation in
as a flake check, not a separate script and not as an extra CI step. (A second
workflow, `update.yml`, briefly bumped the `zen-browser` lock daily; it was
removed when Zen moved from the rolling `twilight` channel to `beta`, which
doesn't rot. Nothing in CI writes to the repo any more.) A `justfile` now
exists at the repo root; `just` alone lists the
recipes. Lint exclusions are deliberate and documented: `statix.toml` disables
`empty_pattern`/`repeated_keys`, and generated `hardware-configuration.nix`
files are excluded from all three lints (see `handWrittenNix` in `flake.nix`).

## Hosts

| Host | State | Filesystem | Notes |
| --- | --- | --- | --- |
| `the-entertaining-nios-vm` | bootstrapped, verified live | ext4, no swap | `features.niri = true`. **All development and verification happens here.** Disposable; only ever gets a throwaway test SSH key. Deliberately set up to be driven entirely over SSH — passwordless `wheel` sudo, greetd autologin into niri, and an `in-session` wrapper — see `docs/testing-on-the-vm.md`. Those three are VM-only and must not spread to a real host. |
| `the-entertaining-nios-laptop` | fully wired, eval-clean, **not installed** | btrfs + 32G swap | The machine this repo is developed on, still running CachyOS. Blocked only on the `/dev/CHANGEME` placeholder in its `disko.nix` (needs `lsblk` from an installer). The install is deliberately on hold — it would wipe the live CachyOS system. |
| `the-entertaining-nios-desktop` | scaffold only | btrfs + 16G swap | No `hardware-configuration.nix`, `secrets.nix`, or `flake.nix` entry yet. Also has a `/dev/CHANGEME` placeholder. |

Both real hosts use the same btrfs subvolumes (`@`, `@home`, `@nix`,
`@snapshots`, `@home_snapshots`) so `features.snapshots` can enable
`modules/services/snapper.nix`; swap is sized to each host's own RAM.
Snapshots are file-level recovery via the `snapper` CLI only — deliberately
not wired into the bootloader, since NixOS generation rollback already covers
boot-time recovery.

## What's on disk

- **`flake.nix`** — composition root only. Inputs: `nixpkgs` (nixos-unstable), `home-manager`, `disko`, `sops-nix`, `noctalia-greeter`, `noctalia`, `zen-browser`, `chaotic`, `millennium`. Two `nixosConfigurations` (vm, laptop) built via `lib/mkHost.nix`, plus `packages.${system}.installer-iso`, `formatter`, `devShells` and `checks` (Phase 8).
  - `chaotic` (CachyOS Proton + gaming kernel) and `millennium` (Millennium-patched Steam) also deliberately don't `.follows` this repo's nixpkgs, for two different upstream-stated reasons — chaotic loses its cache and would compile a kernel from source; Millennium's Bun FOD breaks when its pinned revision moves. Both are Phase 7, both only reach hosts that import `profiles/gaming.nix`.
  - `noctalia` deliberately does **not** `.follows` this repo's nixpkgs — following it would disable Noctalia's Cachix cache and force a from-source build of a native Wayland/OpenGL project on every host. The accepted cost is a second nixpkgs copy in the closure. `zen-browser` *does* follow, having no cache to lose.
- **`lib/mkHost.nix`** — `{ system, hostPath }: nixosSystem`, wiring disko, sops-nix, `modules/options.nix`, the host, and `home-manager.nixosModules.home-manager` (with `useGlobalPkgs`). Threads `noctalia-greeter`/`noctalia`/`zen-browser`/`chaotic`/`millennium` through `specialArgs`/`extraSpecialArgs` **without importing them** — the consuming modules import them themselves, so only hosts that want them carry them.
- **`hosts/installer/`** — not a real host and has no `nixosConfigurations` entry: just `variables.nix` holding the operator identity (`user.name`/`fullName`/`sshPublicKey`) that `installer-iso` needs, kept separate so it can't drift from a real host's. A public SSH key isn't a secret, so sops doesn't apply.
- **`modules/options.nix`** — the `features` submodule: `snapshots`, `niri`, `gaming`, `docker`, `tailscale`, `printing`, all defaulting `false`. A submodule, not `attrsOf bool`, so a typo'd flag is an eval error rather than a silently inert one. `docker`/`steam`/`gamemode` were declared here for a long time without a single module ever reading them, and were removed; re-add each in the same commit as the module that consumes it.
- **`modules/system/`** — `boot`, `networking`, `nix`, `ssh`, `users`, `shell`, `fonts`, `nix-ld`, `unfree`. All unconditional, all bundled by `profiles/base.nix`. `unfree` moved here from `modules/desktop/` in Phase 7: gating an unfree allow-list on `features.niri` meant a gaming host with no compositor couldn't allow Steam.
- **`modules/services/`** — `snapper` (`features.snapshots`), `docker`, `tailscale`, `printing` (each on its own flag). The latter three are on the laptop and desktop only; the VM runs none of them.
- **`modules/programs/`** — `steam` (`features.gaming`): Millennium-patched Steam + `proton-cachyos`, imports the `chaotic`/`millennium` flake modules itself.
- **`modules/hardware/`** — `controllers` (`features.gaming`): the `xone`/`xpadneo` out-of-tree Xbox controller kernel modules.
- **`modules/desktop/`** — `niri`, `greetd`, `noctalia`, `theming`, `nautilus`. All gated on `features.niri`.
- **`profiles/`** — `base.nix` (the universal foundation, imported directly by every host) and `gaming.nix` (Phase 7, the first actual role profile: adds the Steam and controller modules, sets `features.gaming = mkDefault true`; desktop only). Role profiles are purely additive and deliberately do **not** import `base.nix` — each host imports it itself, so no host's `default.nix` hides the fact that it has a bootloader. The desktop's CachyOS kernel and `lact` deliberately stay in that host's own `default.nix` — they describe one machine's hardware, not the role.
- **`justfile`, `statix.toml`, `.github/workflows/check.yml`** — Phase 8. CI validates with `nix flake check` and nothing else, and `check.yml` is the only workflow.
- **`home/`** — machine-agnostic Home Manager entry point (`default.nix`) plus one file per program. There is no per-host Home Manager entry point.
- **`wallpapers/`** — the operator's collection (~35 images), read live from each host's own `~/.dotfiles` clone rather than the Nix store.
- **`.sops.yaml`** — two recipients (vm, laptop), each with its own `creation_rules` entry. The desktop gets one when bootstrapped.
- Short `README.md` in each structural directory: a stable "what belongs here and why", not a changelog. Add one when a new structural directory appears; update one only when that directory's *purpose* changes.
- `overlays/`, `pkgs/`, `scripts/`, `assets/` don't exist yet. There is no `.envrc`, so direnv does not enter the dev shell automatically.

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
- **Profiles** describe a *role*: they import the modules that role always needs and set feature defaults with `lib.mkDefault`. Treat "add a module import" and "set its matching `mkDefault`" as one atomic edit — an import without a default is inert code sitting in the closure but switched off. Role profiles must never restate base's module list — but they must not import `base.nix` either; every host imports it directly, so a role profile only ever describes what sits *on top of* the baseline.
- **Modules** configure exactly one feature and gate on `config.features.x` via `lib.mkIf`. One flag can gate several modules (`features.niri` gates all of `modules/desktop/`; `features.gaming` gates `modules/programs/steam.nix`, `modules/hardware/controllers.nix` and `home/heroic.nix`) — one flag per *capability*, not per file. Where something splits across system and user config (niri is the canonical case), the system half (package, session entry, greetd wiring) lives in `modules/desktop/` and the user half (keybindings, layout, appearance) in `home/`.
- **`lib/`** holds helpers. Further helpers beyond `mkHost.nix` should wait until the same pattern has been hand-written at least twice across real hosts.
- Prefer readability over cleverness, one responsibility per module, comments explaining *why* not *what*, small commits. Avoid a second source of truth for anything the module system can already merge by priority.

## Operational conventions

- **Secrets**: sops-nix. Each host owns `hosts/<name>/secrets/secrets.yaml`. Decryption uses a standalone per-host age key (`~/.config/sops/age/<host>.txt`, operator-held, never committed) rather than one derived from the SSH host key, which NixOS regenerates on every reinstall. The private key is provisioned via `nixos-anywhere --extra-files`. Adding a host requires generating its age key, adding it as a `.sops.yaml` recipient, and encrypting its secrets — this doesn't fail at `nix flake check`, only at activation on real hardware, so do it in the same commit as the host directory.
- **New host bootstrap**: disko + nixos-anywhere. No manual `fdisk`/`nixos-generate-config` copy-paste.
- **Filesystem is a per-host choice**, not repo policy.
- **Autostarted apps** get their own `systemd.user.services.<name>` (`PartOf`/`After = "graphical-session.target"`, `WantedBy = [ "graphical-session.target" ]`) in their own Home Manager module — not a shared niri autostart file and not the app's own autostart toggle.
- **Naming**: lowercase files named for responsibility (`greetd.nix`, `docker.nix`), not implementation. `hosts/*/features.nix` and a profile's role file don't share a naming pattern despite both setting `features.*` — grep for `features =` / `config.features` when auditing, not for filenames.
- **Plan substantial work before implementing it** (Plan mode), and research the operator's existing real config before deciding what to port. Every phase so far was done this way, and it has repeatedly caught wrong assumptions that eval alone wouldn't.
- **Eval passing is not verification.** Every phase has produced bugs that only surfaced when an app was actually opened on the VM. Confirm behavior live before calling something done. Phase 7's entire gaming stack is currently eval-only for exactly this reason — it targets the desktop, which has never been booted.
- **A lint or check that cannot fail is worse than none.** Verify each new flake check against a deliberately broken canary file before trusting it; a file-selection expression that silently matches nothing passes just as green as one that works.

## Standing gotchas

Each of these has bitten at least once and will again. Full write-ups in
`docs/decisions.md`.

- **Noctalia's runtime sidecar overrides Nix.** `~/.local/state/noctalia/settings.toml` deep-merges *on top of* the Nix-managed `~/.config/noctalia/config.toml`, replacing arrays wholesale, with no conflict warning. Any time `home/noctalia.nix`'s `builtin_ids`/`community_ids`/other array-typed `theme.*` settings change on an already-provisioned host, check that sidecar for a stale override of the same key — a Nix-side change alone is not guaranteed to take effect.
- **`greeter.toml` is seeded once, never overwritten.** `programs.noctalia-greeter.settings` only seeds `/var/lib/noctalia-greeter/greeter.toml` via a systemd-tmpfiles `C` rule, so changes have no effect on an already-booted host until: `sudo rm /var/lib/noctalia-greeter/greeter.toml && sudo systemd-tmpfiles --create && sudo systemctl restart greetd`. This can't be fixed Nix-side.
- **The same shape recurs for any app's own mutable state** — Zen's `xulstore.json` remembering a window geometry, a stale `nvim/lua/plugins/base16.lua`. When a declared setting appears not to apply, look for state the app seeded itself.
- **niri's KDL config is live-symlinked to a separate `~/.dotfiles` clone** on each host (see `docs/live-dotfiles.md`). Edits in this working tree do not reach a host until pushed and pulled there — `scp` the changed files and `niri msg action load-config-file` to test without a full cycle.
- **niri's blur is invisible without real client-side alpha.** `background-effect { blur true }` draws a blurred backdrop *behind* a surface, so it only shows where the surface's own background is translucent (Ghostty's `background-opacity`, Noctalia's `bar.default.background_opacity` and `shell.panel.transparency_mode = "glass"`). niri's `opacity` window-rule is **not** that — it fades the whole composited window over what's really behind it, so Zen, Nautilus and Vesktop show a sharp backdrop no matter what the blur rules say. A sharp backdrop under an `opacity`-driven window is expected, not a broken config; an app with no client-side transparency can have tinting or nothing.
- **Noctalia's panels are opaque until `shell.panel.transparency_mode` is set.** It defaults to `"solid"` and made the whole blur setup look broken. The TOML path is `[shell.panel]` even though Noctalia's settings schema files the option under `panels` and its values under `shell` — neither of those is the config path. When a Noctalia setting seems not to apply, check `journalctl --user -u noctalia` for `unknown section` / `unknown setting`: an unrecognized key is otherwise ignored in silence. Confirm that warning actually fires (add a junk key) before reading silence as acceptance.
- **niri's KDL `environment {}` block does not reach the systemd `--user` manager.** It only applies to niri's own directly-spawned children, so anything launched as a user service (which is everything Noctalia launches) never sees it. Use `environment.sessionVariables` at the NixOS level instead. This is why `NIXOS_OZONE_WL` lives in `modules/desktop/niri.nix`.
- **Noctalia templates that mutate a file in place conflict with Home Manager.** Any official template using `sed -i` or a temp-file-then-`mv` (starship, lazygit) destroys an HM-managed symlink at that path. Use a custom `theme.templates.user.<id>` template that renders the whole file instead, or point the template at a separate output file HM doesn't manage (ghostty, gtk, qt, yazi). Never manage a file Noctalia's template engine owns.
- **`home.sessionVariables` values are not shell-expanded.** They're written into a script as-is, so `"$XDG_CONFIG_HOME/..."` silently resolves to a broken path. Use `${config.xdg.configHome}`.
- **"Existing file … would be clobbered" during activation**: retry the switch once before assuming the config is wrong. It has occurred as a one-off home-manager activation-ordering race.
- **An ad-hoc SSH shell has no session context.** `NIRI_SOCKET`, `SSH_AUTH_SOCK`, and friends are scoped to the graphical session's own systemd user manager; export them manually (`systemctl --user show-environment`) when driving a live session over SSH. On the VM this is packaged as the `in-session` wrapper (`ssh ol@<vm> in-session niri msg windows`); on a real host it's still manual.
- **`Terminal=true` in a `.desktop` entry does nothing in this session.** There's no desktop environment to answer "which terminal?", and glib picks from a hardcoded list (xterm, gnome-terminal, konsole, …) that Ghostty isn't on. It fails *silently and misleadingly*: `xdg-open somefile.txt`, with `text/plain` resolving to Neovim's own `Terminal=true` entry, opened Zen Browser and left an orphaned headless `nvim` behind. Any terminal program that needs a desktop entry must spawn the terminal itself — `home/neovim.nix` overrides the `nvim` entry with `Exec=ghostty -e nvim %F` and `Terminal=false`.
- **A Home Manager sub-module accepts settings while disabled, and silently discards them.** `xdg.mimeApps.defaultApplications` populated to fifteen correct entries by the zen-browser flake, with `xdg.mimeApps.enable = false`, produced no `mimeapps.list` and no warning — Zen was only the default browser by accident, because it was the sole `x-scheme-handler/http` entry in `mimeinfo.cache`. `home/xdg-mime-apps.nix` now owns that switch. When a third-party HM module offers a "set as default"-style flag, check whether the option group it writes into is actually enabled; eval can't tell you, since discarded settings evaluate fine.
- **`useGlobalPkgs` means Home Manager can't set `nixpkgs.config`.** Unfree allowances must go in `modules/desktop/unfree.nix` at the NixOS level.
- **A rolling input's source rots in place, and `--no-build` can't see it.** No input does this any more — `home/zen-browser.nix` moved off Zen's `twilight` nightly to the `beta` channel precisely because of it — but the shape is worth recognising before adding an input. A rolling source means upstream replaces the tarball behind an already-locked revision every few days, and the fixed-output source derivation then starts failing with a hash mismatch on whatever commit happens to be pushed next, with no relation to what that commit changed. `nix flake check --no-build` (so `just check-fast`, so `driver.sh check`) passes throughout, since it never fetches. Prefer an input with immutable release artifacts; run the *full* `nix flake check` after any `nix flake update` before pushing.
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
| 7 | Extra features — Docker, Tailscale, printing, gaming profile | done, **eval-only** — the gaming stack targets the desktop, which can't be eval'd where it lives (no `nixosConfigurations` entry); verified by temporarily importing `profiles/gaming.nix` on the VM. Nothing has run on hardware. |
| 8 | Long-term — `nix flake check` as the CI gate, `justfile`, doc upkeep, multi-host hardening | done except multi-host hardening, which is blocked on hardware (both `/dev/CHANGEME` placeholders; the desktop's missing `hardware-configuration.nix`, age key and flake entry) |

Six once-planned modules were abandoned and will not be created:
`modules/desktop/stylix.nix` (superseded by Noctalia's own native theming —
adding Stylix would mean two systems fighting over the same GTK/Qt/terminal
files), `modules/desktop/portals.nix` (portals come free with `programs.niri`'s
upstream module), `modules/hardware/bluetooth.nix` and `audio.nix` (Bluetooth
and PipeWire both come from `programs.noctalia.recommendedServices.enable`),
`modules/hardware/graphics.nix` (the only option the stack needs is
`hardware.graphics.enable32Bit`, which lives with the thing requiring it;
AMD needs nothing else declared), and `modules/programs/gaming.nix` (it would
have held gamemode/gamescope/MangoHud, all dropped when the operator chose a
minimal gaming stack). `ARCHITECTURE.md` records all six; don't re-propose
them.

## Software stack

Niri, greetd, Noctalia Greeter, Noctalia Shell v5 (native theming, GTK/Qt theming templates), Papirus icons, Bibata cursors, adw-gtk3, qt5ct/qt6ct · Ghostty, Zsh, Starship, Git, Lazygit, Fastfetch, eza, bat, fd, ripgrep, fzf, zoxide, yazi, btop · Zen Browser, VS Code, Vesktop, Nautilus, Feishin, Obsidian · Steam (Millennium-patched), proton-cachyos, Heroic, umu-launcher, xone/xpadneo · Tailscale · Docker Engine + Compose · PipeWire, Bluetooth, Printing (CUPS + Avahi), NetworkManager, Snapper · nixd, nil, nixfmt, statix, deadnix, just, sops, age (all in the dev shell).

Neovim is **not** Home-Manager-managed: `~/.config/nvim` is an ordinary manual
clone of the operator's separate `github:TechieOllie/neovim_dotfiles` repo,
kept on lazy.nvim/Mason. `home/neovim.nix` only provides the toolchain
prerequisites Mason needs at runtime (`gnumake`, `gcc`, `tree-sitter`,
`python3`, `nodejs`, `go`, `php`, `unzip`, `ripgrep`) — plus
`modules/system/nix-ld.nix`, without which Mason's prebuilt manylinux wheels
can't run at all. It is also the system's default text editor, in both
senses: `EDITOR`/`VISUAL` (`home.sessionVariables`, so every shell rather
than just interactive zsh) and the `text/plain`-and-friends mime defaults,
via an overridden `nvim` desktop entry that launches it inside Ghostty.

The gaming stack is deliberately minimal, by the operator's explicit choice:
gamescope, gamemode, MangoHud, Lutris, Bottles, goverlay, protontricks,
ludusavi, steamtinkerlaunch and vkbasalt were each proposed and declined, and
Proton GE was replaced by CachyOS's fork. The GUI Proton installers
(protonup-qt, protonplus) are also absent on purpose — they write Proton
builds into `~/.steam` by hand, which is the app-owned-mutable-state problem
above; `programs.steam.extraCompatPackages` does it declaratively instead.
Read `docs/decisions.md`'s Phase 7 section before re-proposing any of them.

Millennium is **not** in nixpkgs (open packaging request, nixpkgs#382086) and
neither is CachyOS's Proton or kernel — all three come from third-party
flakes, which is why `flake.nix` has two inputs that don't follow this repo's
nixpkgs.
