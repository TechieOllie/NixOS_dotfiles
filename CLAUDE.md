# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

A flake-based NixOS configuration for several machines (see Hosts), with Home Manager
integrated into the system closure (one `nixos-rebuild switch`, one rollback).

Three documents, three jobs — don't duplicate between them:

- **`ARCHITECTURE.md`** — the design and every convention. The single source of truth; read it in full before making an architectural decision not already reflected in the code.
- **this file** — current state, commands, and the gotchas that will bite again.
- **`docs/decisions.md`** — the investigation log: what was tried, what broke, what was ruled out and why. Read it before re-attempting something, or when you need the reasoning behind a non-obvious choice.
- **`docs/`** also holds runbooks: `bootstrapping-a-host.md`, `secrets.md`, `live-dotfiles.md`, `testing-on-the-vm.md`.

## Commands

Verification runs through the repo's own driver — use it rather than hand-rolling `nix` invocations:

```bash
.claude/skills/run-nixos-dotfiles/driver.sh check          # eval every host + installer-iso, no building. Run first after any change.
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
nix fmt                                  # nixfmt (RFC 166), in place; skips generated hardware-configuration.nix
nix develop                              # just/nixfmt/statix/deadnix/nixd/nil/sops/age
nix build .#nixosConfigurations.<host>.config.system.build.toplevel
nix build .#installer-iso
nixos-rebuild switch --flake .#<host>
sudo nixos-rebuild switch --refresh --flake github:TechieOllie/NixOS_dotfiles#<host>
                                         # for a host with no clone (inotmac). --refresh is
                                         # required, or Nix reuses a cached stale revision.
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
| `the-entertaining-nios-vm` | bootstrapped, verified live | ext4, no swap | `features.desktop` + `niri`. **All verification happens here.** Disposable; only ever gets a throwaway test SSH key. Deliberately set up to be driven entirely over SSH — passwordless `wheel` sudo, greetd autologin into niri, and an `in-session` wrapper — see `docs/testing-on-the-vm.md`. Those three are VM-only and must not spread to a real host. |
| `theseus` | **installed 2026-10-19, booted, partly verified live** | LUKS2 (TPM) → LVM → btrfs + swap | Framework 13 Pro, Intel Core Ultra 5 325 (Series 3), via nixos-hardware's `framework-intel-core-ultra-series3`; `linuxPackages_latest`, per Framework's "not LTS" guidance. Replaced the never-installed `the-entertaining-nios-laptop` (2026-10-17), inheriting its age key and password hash, plus a per-host GitHub key `ol@theseus`. The desktop's setup on a laptop — `profiles/gaming.nix`, `development`, `cad`, `kdeconnect` — and, like the desktop since 2026-10-20, the Noctalia desktop on **Umbriel** (`features.umbriel`). The only encrypted host: the TPM unlocks LUKS through the systemd initrd, the install passphrase stays as fallback, and swap sits inside the same container so hibernation is encrypted too. The only host with a fingerprint reader: fprintd covers the lock screen, `sudo` and polkit, never the greeter (see the fprintd gotcha). Also the only touchscreen, with nothing declared for it: Umbriel enables touch by default and maps it to the single built-in panel by itself. Host-level corrections to nixos-hardware: `hardware.intelgpu.driver = "xe"` (its Series 3 module falls through to the generic Intel profile's `i915`) and `intel-media-driver` only. Lid close on battery is suspend-then-hibernate after 2 h, on AC plain suspend. The battery charge limit lives in the EC (BIOS or `framework_tool`), not in Nix. Installed with nixos-anywhere on 2026-10-19 (1T WD_BLACK SN7100, 32G swap). `console.earlySetup` is on so the initrd's passphrase prompt reads AZERTY — without it the initrd has no keymap and rejects a correct passphrase. Verified live 2026-10-19: boot, TPM unlock (no prompt), fingerprint (lock screen, `sudo`) with password-only at the greeter, the keyring, `xe` + VA-API (iHD), Wi-Fi, the tailnet, touch, the AZERTY workspace binds, the scratchpads, hibernate, Steam (Millennium) under Xwayland and a Proton game, the replay buffer, the charge limit (80), and SSH to GitHub as the per-host key. The panel runs at scale 1.6 with HDR **off** (it supports PQ/BT.2020). Always-on HDR (2026-10-20) caused a few seconds of artifacting after some logins and was dropped the same day; `"auto"` (HDR only while a fullscreen window shows HDR content) also tested clean at login and is the setting to try next (`docs/decisions.md`, "theseus's HDR"). Both in `home/umbriel/cfg/layout.toml`. Untested: `replay-auto` starting the buffer on its own, the lid-timed hibernate, and the LUKS passphrase fallback — see `hosts/theseus/README.md`. Install steps in `docs/bootstrapping-a-host.md`, "Encrypted host"; remaining checklist in `hosts/theseus/README.md`; install write-up and dated verification in `docs/decisions.md` ("theseus installed (2026-10-19)", "Host verification log"). The operator's main machine since 2026-10-19: its `ol@theseus` key is authorized on every host and the installer. |
| `the-entertaining-nios-desktop` | **bootstrapped, booted, session verified live** | btrfs + 16G swap (system disk) | ASRock B550M Pro4, Ryzen 5 5600X, 16G RAM, RX 6600; two monitors (DP-1 2560x1440, run at its preferred 144 Hz though it can do 165; HDMI-A-1 1920x1080@60). One of the two hosts with `profiles/gaming.nix`, `kdeconnect`, `cad` and `development` (theseus is the other), and the only one setting `features.moonshine` (tailnet-only). Carries the full Noctalia desktop on **Umbriel** since 2026-10-20 (niri before, which is where most of this file's niri history comes from); its Samsung is keyed by monitor identity in `home/umbriel/cfg/layout.toml`, and Moonshine's "Desktop" stream is a nested Umbriel. Verified remotely 2026-10-20: the headless Moonshine "Desktop" branch end to end (with a headless Weston standing in for Moonshine's compositor: full Noctalia session, `Mod` binds on Super, teardown in ~6 s, immediate reconnect), the Samsung's EDID identity and its 144 Hz preferred mode, and `Writeback-1` being invisible to wlroots (it never sets `DRM_CLIENT_CAP_WRITEBACK_CONNECTORS`). Not yet verified on the physical screen: a local Umbriel login, the outputs as actually driven, Steam under Umbriel's Xwayland, and the bare Moonshine branch on this host. Disks: the 1T NVMe system disk by `/dev/disk/by-id/`; a 2T Seagate as bulk ext4 at `/mnt/storage` (`nofail`, symlinked to `~/Storage`); the 500G SATA SSD holding the old CachyOS install is deliberately undeclared and still bootable as a fallback. `secrets.nix` provisions the password hash and a per-host GitHub SSH key (`~/.ssh/id_ed25519`, separate from `variables.nix`'s bootstrap key); `~/.dotfiles` uses the SSH remote. Its `default.nix` carries host-level pins for the greeter output, the OfficeJet queue and the Z407 default sink (see the matching gotchas). Everything on it is verified live except `xpadneo` — no Bluetooth pad has been paired yet. Dated verification history: `docs/decisions.md`, "Host verification log". |
| `inotmac` | **bootstrapped, booted, GDM + session verified live** | ext4, no swap | Mid-2011 21.5" iMac shared by four people — the only multi-user host and the only GNOME one (`features.gnome`, GDM) instead of niri. Radeon HD 6750M on the **`radeon`** driver, not `amdgpu` (nothing pre-GCN matches there); the idle `card1`/i915 and its VBT warning are benign, as are the dbus-broker duplicate-name errors in the boot journal. Wi-Fi only: `networking.networkmanager.ensureProfiles` declares the SSID and sops substitutes `$WIFI_PSK` at activation. `ol` is admin and nothing else — `features.workstation` is **off**, so only Zsh + Starship reach that account. `liz`/`regis`/`jolan` come from `vars.extraUsers` (pinned uids 1001-1003, no wheel, no Home Manager), which is why their apps (Chrome, Picard, Rhythmbox) are `modules/programs/` system packages rather than `home/` modules. `regis`/`jolan` are French (see the AccountsService gotcha). No `~/.dotfiles` clone and no GitHub identity, deliberately: rebuild from the public flake (see Commands). |

Both btrfs hosts (desktop, theseus) use the same btrfs subvolumes (`@`, `@home`, `@nix`,
`@snapshots`, `@home_snapshots`) so `features.snapshots` can enable
`modules/services/snapper.nix`; swap is sized to each host's own RAM. Both
gaming hosts add `@steam` and `@games`, mounted at `~/.local/share/Steam` and
`~/Games` (hidden from Nautilus with `x-gvfs-hide`), so the hourly `/home`
snapshots never pin game files — before that they held ~65G of uninstalled
and patched-over games. Snapper keeps 10 hourly, 7 daily, 4 weekly and nothing
older. A subvolume added to an installed host's `disko.nix` must be created by
hand before switching — see the end of `docs/bootstrapping-a-host.md`.
Snapshots are file-level recovery via the `snapper` CLI only — deliberately
not wired into the bootloader, since NixOS generation rollback already covers
boot-time recovery.

## What's on disk

- **`flake.nix`** — composition root only. Inputs: `nixpkgs` (nixos-unstable), `home-manager`, `disko`, `sops-nix`, `noctalia-greeter`, `noctalia`, `zen-browser`, `chaotic`, `millennium`, `moonshine`, `claude-code`, `nix-index-database`, `umbriel`, `nixos-hardware`. One `nixosConfigurations` entry per `hosts/<name>/` (except `installer`), built via `lib/mkHost.nix`, plus `packages.${system}.installer-iso`, `formatter`, `devShells` and `checks` (Phase 8).
  - `chaotic` (CachyOS Proton + gaming kernel) and `millennium` (Millennium-patched Steam) also deliberately don't `.follows` this repo's nixpkgs, for two different upstream-stated reasons — chaotic loses its cache and would compile a kernel from source; Millennium pins a specific nixpkgs commit because its Bun FOD is version-sensitive. That FOD is also unreproducible outright — see the standing gotcha. Both are Phase 7, both only reach hosts that import `profiles/gaming.nix`.
  - `noctalia` deliberately does **not** `.follows` this repo's nixpkgs — following it would disable Noctalia's Cachix cache and force a from-source build of a native Wayland/OpenGL project on every host. The accepted cost is a second nixpkgs copy in the closure. `zen-browser` *does* follow, having no cache to lose, and so does `moonshine` — same reasoning, and it only reaches the desktop.
  - `umbriel` (Noctalia's compositor) follows `noctalia`'s rules exactly: no `.follows`, and the `cachix` branch, both to keep its binary cache. `nixos-hardware` follows nixpkgs (its own copy only feeds its formatter and tests) and is the one input a *host* imports rather than a module — `hosts/theseus/default.nix`.
  - `claude-code` (`sadjow/claude-code-nix`) exists only so Claude Code can move faster than nixpkgs: `just update-claude-code` (`nix flake update claude-code`) bumps it alone. It follows nixpkgs, and `home/claude-code.nix` calls its `package.nix` with this repo's `pkgs` rather than taking its `packages` output — that output is built with `allowUnfree = true` and would bypass `modules/system/unfree.nix`.
  - `nix-index-database` is a prebuilt weekly nix-index database (command-not-found, `nix-locate`, comma), imported by `home/nix-index.nix`. Pinned like any input, so its package list only refreshes on `just update` (or `nix flake update nix-index-database`) — let it move with nixpkgs, or its hints drift from what the host actually has. Its module enables `programs.nix-index` with `mkDefault true` on import, which is why that file assigns the flag rather than wrapping itself in `mkIf`.
- **`lib/mkHost.nix`** — `{ system, hostPath }: nixosSystem`, wiring disko, sops-nix, `modules/options.nix`, the host, and `home-manager.nixosModules.home-manager` (with `useGlobalPkgs` *and* `useUserPackages`, so `home.packages` land in `/etc/profiles/per-user/<name>` as part of the generation rather than in `~/.nix-profile`). Threads `noctalia-greeter`/`noctalia`/`zen-browser`/`chaotic`/`millennium`/`moonshine`/`claude-code`/`umbriel`/`nixos-hardware` through `specialArgs`/`extraSpecialArgs` **without importing them** — the consuming modules import them themselves, so only hosts that want them carry them.
- **`hosts/installer/`** — not a real host and has no `nixosConfigurations` entry: just `variables.nix` holding the operator identity (`user.name`/`fullName`/`sshPublicKeys`) that `installer-iso` needs, kept separate so it can't drift from a real host's. A public SSH key isn't a secret, so sops doesn't apply.
- **`modules/options.nix`** — the `features` submodule: `snapshots`, `desktop`, `niri`, `umbriel`, `gnome`, `gaming`, `docker`, `tailscale`, `printing`, `moonshine`, `kdeconnect`, `cad`, `photography`, `development`, `workstation`, `laptop`, all defaulting `false`. `laptop` (theseus only) just adds the battery and Wi-Fi widgets to Noctalia's bar. `workstation` is the odd one out in *kind*: it gates no hardware or service, only the operator's own terminal environment (`home/`'s ghostty/git/lazygit/neovim/yazi/direnv), and exists because `inotmac` is a machine ol administers rather than works on. Zsh and Starship are deliberately outside it and stay unconditional. `desktop` is the Noctalia desktop (greetd + noctalia-greeter, the shell, theming, Nautilus, every graphical app in `home/`); `niri` and `umbriel` only pick its compositor, and the module asserts exactly one per `desktop` host (since 2026-10-17 — before that `niri` meant the whole stack). A submodule, not `attrsOf bool`, so a typo'd flag is an eval error rather than a silently inert one. `docker`/`steam`/`gamemode` were declared here for a long time without a single module ever reading them, and were removed; re-add each in the same commit as the module that consumes it.
- **`modules/system/`** — `boot`, `networking`, `nix`, `ssh`, `users`, `shell`, `fonts`, `nix-ld`, `unfree`, `firmware` (fwupd), `disk-health` (smartd with desktop notifications via systembus-notify, and a monthly btrfs scrub of `/` only — the option's default would scrub each subvolume's mount point, i.e. the same filesystem seven times on the desktop). The VM opts out of smartd in its own `default.nix`, since smartd fails with no SMART-capable disk. `boot` caps systemd-boot at 15 entries. `users.nix` pins the primary user to `uid = 1000` — the value it would be allocated anyway, stated so that `services.moonshine` can read it (that module asserts rather than guesses). All unconditional, all bundled by `profiles/base.nix`. `unfree` moved here from `modules/desktop/` in Phase 7: gating an unfree allow-list on `features.niri` meant a gaming host with no compositor couldn't allow Steam.
- **`modules/services/`** — `snapper` (`features.snapshots`), `docker`, `tailscale`, `printing`, `moonshine`, `kdeconnect` (each on its own flag). `docker`/`tailscale`/`printing`/`kdeconnect` are on the desktop and theseus; `moonshine` is desktop-only; the VM runs none of them. `kdeconnect` is only the firewall half (TCP/UDP 1714-1764 plus the package) — the daemon is started by the package's own XDG autostart entry (no unit in this repo), and `home/kdeconnect.nix` only adds the Noctalia plugin's runtime tools (`gdbus`, `sshfs`). There is no tray indicator, deliberately.
- **`modules/programs/`** — `steam` (`features.gaming`): Millennium-patched Steam + `proton-cachyos` (x86-64-v3 build) and `proton-ge-bin` as the fallback, imports the `chaotic`/`millennium` flake modules itself. Plus `gpu-screen-recorder` (`features.gaming`; the `gsr-kms-server` capability wrapper for promptless monitor capture — the `replay` command, its keybinds and the `replay-auto` unit that starts it while a game window is open are `home/gpu-screen-recorder.nix`, and the overlay UI is deliberately off). Plus `chrome`, `picard` and `rhythmbox` (all `features.gnome`), which are *system* packages purely because three of inotmac's four accounts have no Home Manager profile to put them in — the shape to copy for any future app on a shared host.
- **`modules/hardware/`** — `controllers` and `ntsync` (both `features.gaming`): the `xone`/`xpadneo` out-of-tree Xbox controller kernel modules, and loading the in-tree `ntsync` module so `/dev/ntsync` exists for Proton.
- **`modules/desktop/`** — `session` (NIXOS_OZONE_WL, the keyring daemon, wl-clipboard), `greetd`, `noctalia`, `theming`, `nautilus`, all gated on `features.desktop`; the compositors `niri` (`features.niri`, plus xwayland-satellite) and `umbriel` (`features.umbriel`, whose package brings its own Xwayland); plus `gnome` (GDM + GNOME Shell) on `features.gnome`. The two desktop stacks are mutually exclusive by construction — separate flags, and neither module reads the other's.
- **`profiles/`** — `base.nix` (the universal foundation, imported directly by every host) and `gaming.nix` (Phase 7, the first actual role profile: adds the Steam and controller modules, sets `features.gaming = mkDefault true`; desktop only). Role profiles are purely additive and deliberately do **not** import `base.nix` — each host imports it itself, so no host's `default.nix` hides the fact that it has a bootloader. The desktop's CachyOS kernel and `lact` deliberately stay in that host's own `default.nix` — they describe one machine's hardware, not the role.
- **`justfile`, `statix.toml`, `.github/workflows/check.yml`** — Phase 8. CI validates with `nix flake check` and nothing else, and `check.yml` is the only workflow.
- **`home/`** — machine-agnostic Home Manager entry point (`default.nix`) plus one file per program. There is no per-host Home Manager entry point, so a desktop-only app is expressed as a `features` flag the module self-gates on, not as a host-side import: `freecad.nix`/`kicad.nix`/`slicers.nix` (Orca Slicer) (`features.cad`), `darktable.nix` (`features.photography`), `jetbrains.nix`/`claude-code.nix`/`gh.nix` (`features.development`), `kdeconnect.nix` (`features.kdeconnect`), `lazydocker.nix` (`features.docker`), `moonlight.nix` (`features.gaming` *and not* `features.moonshine` — the streaming client, so theseus only), `prismlauncher.nix`, `obs-studio.nix` and `gpu-screen-recorder.nix` (`features.gaming`, riding the same flag as `heroic.nix`; the recorder's watcher reads whichever compositor's event stream the host runs, chosen at eval time), the compositors' user halves `niri.nix` and `umbriel.nix` (each on its own flag, config live-symlinked from `home/niri/` and `home/umbriel/`), the graphical apps (`features.desktop`), `direnv.nix` and the rest of the terminal toolkit — `eza`/`bat`/`btop`/`fzf`/`ripgrep`/`fastfetch`/`nix-index`/`yazi`/`jq`/`tealdeer`/`dust`/`nh` (`features.workstation`; `nh` points `NH_FLAKE` at `~/.dotfiles` and leaves cleaning to `nix.gc`, and `just switch` runs `nh os switch --ask`).
- **`wallpapers/`** — the operator's collection (~35 images), read live from each host's own `~/.dotfiles` clone rather than the Nix store.
- **`.sops.yaml`** — one age recipient per host, each with its own `creation_rules` entry.
- **`extra-files/`** — gitignored staging tree for `nixos-anywhere --extra-files` (the per-host age key); never commit it. See `docs/bootstrapping-a-host.md`.
- Short `README.md` in each structural directory: a stable "what belongs here and why", not a changelog. Add one when a new structural directory appears; update one only when that directory's *purpose* changes.
- **`assets/`** — static files copied into the store: so far only `avatar.jpg`, the operator's account picture, which `modules/system/users.nix` symlinks to `/var/lib/AccountsService/icons/<user>` on every host (greeter, GDM, and Noctalia's fallback all read it from there). Public, like the rest of the repo.
- `overlays/`, `pkgs/`, `scripts/` don't exist yet. `overlays/` existed briefly for a fre:ac fix and was removed with it — `docs/decisions.md` has the write-up, which is worth reading before adding the directory back. `.envrc` (`use flake`) is at the repo root, so direnv enters the dev shell on `cd` — see `home/direnv.nix`, which is gated on `features.workstation`, and note that `direnv allow` is per-clone mutable state no module can declare.

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
- **Modules** configure exactly one feature and gate on `config.features.x` via `lib.mkIf`. One flag can gate several modules (`features.desktop` gates the shared half of `modules/desktop/` and every graphical app in `home/`; `features.gaming` gates `modules/programs/steam.nix`, `modules/hardware/controllers.nix` and `home/heroic.nix`) — one flag per *capability*, not per file. Where something splits across system and user config (niri is the canonical case), the system half (package, session entry, greetd wiring) lives in `modules/desktop/` and the user half (keybindings, layout, appearance) in `home/`.
- **`lib/`** holds helpers. Further helpers beyond `mkHost.nix` should wait until the same pattern has been hand-written at least twice across real hosts.
- Prefer readability over cleverness, one responsibility per module, comments explaining *why* not *what*, small commits. Avoid a second source of truth for anything the module system can already merge by priority.

## Operational conventions

- **Secrets**: sops-nix. Each host owns `hosts/<name>/secrets/secrets.yaml`. Decryption uses a standalone per-host age key (`~/.config/sops/age/<host>.txt`, operator-held, never committed) rather than one derived from the SSH host key, which NixOS regenerates on every reinstall. The private key is provisioned via `nixos-anywhere --extra-files`. Adding a host requires generating its age key, adding it as a `.sops.yaml` recipient, and encrypting its secrets — do it in the same commit as the host directory. Every rule also lists `*recovery`, an operator key held **only** in the password manager that decrypts everything, so a lost host key means rotation rather than loss — keep it on new rules (`docs/secrets.md`, "Recovery key"); inotmac's file doesn't carry it yet. **A secret marked `neededForUsers` fails at *eval*, not activation**: sops-nix's `secrets-for-users` module reads the file as a literal git-tracked path while the config is being evaluated, so a missing — or merely untracked — `secrets.yaml` throws `Path '...' does not exist in Git repository` and breaks `nix flake check` for the **whole repo**, not just that host. Creating the file is not enough; `git add` it. Ordinary (non-`neededForUsers`) secrets do behave the older way, failing only at activation on real hardware. This is why a host's `nixosConfigurations` entry and its `secrets.yaml` have to land together — wiring the entry first makes every other host un-evaluable too.
- **New host bootstrap**: disko + nixos-anywhere. No manual `fdisk`/`nixos-generate-config` copy-paste.
- **Filesystem is a per-host choice**, not repo policy.
- **Autostarted apps** get their own `systemd.user.services.<name>` (`PartOf`/`After = "graphical-session.target"`, `WantedBy = [ "graphical-session.target" ]`) in their own Home Manager module — not a shared niri autostart file and not the app's own autostart toggle.
- **Naming**: lowercase files named for responsibility (`greetd.nix`, `docker.nix`), not implementation. `hosts/*/features.nix` and a profile's role file don't share a naming pattern despite both setting `features.*` — grep for `features =` / `config.features` when auditing, not for filenames.
- **Plan substantial work before implementing it** (Plan mode), and research the operator's existing real config before deciding what to port. Every phase so far was done this way, and it has repeatedly caught wrong assumptions that eval alone wouldn't.
- **Eval passing is not verification.** Every phase has produced bugs that only surfaced when an app was actually opened on the VM. Confirm behavior live before calling something done. Phase 7's gaming stack sat eval-only for exactly this reason until the desktop was booted, and the two bugs it then hit on first use (no XWayland for Steam, `extraCompatPackages` never reaching Heroic) were both invisible to eval.
- **A lint or check that cannot fail is worse than none.** Verify each new flake check against a deliberately broken canary file before trusting it; a file-selection expression that silently matches nothing passes just as green as one that works.

## Standing gotchas

Each of these has bitten at least once and will again. Every bullet is the
symptom and the rule; the full write-up of each — mechanism, evidence, dates,
history — is in `docs/decisions.md`, "Standing gotchas, full text", under the
same bold lead.

### Noctalia

- **Noctalia's runtime sidecar overrides Nix.** `~/.local/state/noctalia/settings.toml` deep-merges over the Nix-managed `config.toml` (arrays replaced wholesale) and nothing ever prunes it, so any value once set in the UI shadows this repo — and *removing* a setting from `home/noctalia.nix` doesn't remove it from a provisioned host either. After changing or removing a setting, check the sidecar for the same key. To prune: stop `noctalia` first, delete only keys identical to the evaluated `programs.noctalia.settings`, report the rest. Never delete `lockscreen_widgets.widget`/`.grid`/`.widget_order` (the desktop's hand-built lockscreen, not backed up). Nothing tied to a display (connector ids, pixel coordinates, per-output tables) is declared in Nix.
- **Noctalia's own config validator warns but never fails.** An unknown key still gives `✓ Config is valid`; read `nix log` for `WARN` lines. The `unrecognized widget type` / `no loaded plugin with this id` warnings for the community plugins are expected and permanent.
- **Noctalia's panels are opaque until `shell.panel.transparency_mode` is set**, and an unrecognised Noctalia key is ignored in silence — check `journalctl --user -u noctalia` for `unknown section`/`unknown setting`, after confirming with a junk key that the warning fires.
- **`bar.default` is correct despite Noctalia's `example.toml` saying `[bar.main]`.** Don't "fix" it.
- **Noctalia templates that mutate a file in place conflict with Home Manager.** A template using `sed -i` or temp-file-then-`mv` destroys an HM symlink. Use a custom user template that renders the whole file, or point it at a file HM doesn't manage; never manage a file Noctalia's template engine owns. Escapes in use: declare the exact line a guarded hook checks for (`home/btop.nix`), or declare no file and let the hook own it (`home/bat.nix`, which also has to force HM's ghostty module out of `programs.bat.config`).
- **Noctalia's `umbriel` template writes into `config.toml` unless its include line is already final — and through the live symlink that write lands in `~/.dotfiles`.** Keep `home/umbriel/config.toml`'s `[include.optional] files = ["style.toml", "noctalia.toml"]` exactly as is — one line, `noctalia.toml` last — and re-check after a Noctalia bump.
- **A fresh install runs Noctalia's first theme pass before any app has started.** Every template output (and directory on the way) exists before its app has run once; this broke Ghostty's HM `onChange` and Steam's `~/.steam/steam` link on theseus. When adding a template, or config that names a template's output, ask what happens on a machine where neither exists yet. Invisible to eval and to already-provisioned hosts.
- **A Home-Manager-seeded copy of an app-recolored theme goes stale between theme passes.** `home/gtk.nix`'s `seedPapirusIcons` re-runs Noctalia's cached `papirus-icons` `apply.sh` after re-copying; its `makeBinPath` must include `pkgs.getent`, or it dies with `Error: Failed to apply papirus-folders`.
- **Shape/typography have one source of truth: the `style` block in `home/noctalia.nix`.** Corner radius reaches niri via the `niri-style` template and Umbriel via `umbriel/style.toml`. No `geometry-corner-radius` in KDL, no `home/style.nix`.
- **UI fonts are unified through `fonts.fontconfig.defaultFonts`, not per-app** (NixOS-level, so the greeter matches; Qt has no per-app route).

### Greeter, session and keyring

- **`greeter.toml` is declarative again — the old seed-once dance is obsolete.** The upstream module force-symlinks it on every activation, so a plain switch applies a change; don't perform the `rm` + tmpfiles dance older `docs/decisions.md` entries describe. Runtime-learned greeter state lives in `sync.toml`, deliberately unmanaged.
- **amdgpu's `Writeback-1` connector counts as a monitor to noctalia-greeter**, which mirrors onto every output: a black screen with a live, themed cursor at the greeter is this. Fixed by the desktop's `output.name` pin; check `/sys/class/drm/card*-*/status` before assuming an output count. Sessions (wlroots, niri) never see that connector.
- **Nothing in nixpkgs unlocks the gnome-keyring login keyring at greetd login — this repo has to** (`modules/desktop/greetd.nix`). Chromium-based apps additionally need `--password-store=gnome-libsecret` (see `home/vscode.nix`), because they fall back to plaintext under any `XDG_CURRENT_DESKTOP` but GNOME/KDE.
- **`services.fprintd.enable` adds pam_fprintd to *every* PAM service, the greeter included, and a fingerprint can't unlock the keyring.** The fix is `security.pam.services.login.fprintAuth = false` — on `login`, not `greetd`, whose per-service flags render nothing. Check the rendered `login` stack (no pam_fprintd, pam_gnome_keyring before pam_unix), not the flag. Sudo, polkit and the lock screen still take a finger.
- **fprintd grabs the fingerprint sensor out from under a fwupd update.** The sensor re-enumerates after flashing, fprintd (or a `sudo` waiting for a finger) opens it first, and fwupd fails with `device … did not come back` and then drops the sensor from its list (`is already open` in the journal). The flash itself had landed. Run `sudo -v` first, then `sudo systemctl stop fprintd` before `fwupdmgr update`, and restart `fwupd` to read the version back.
- **An ad-hoc SSH shell has no session context.** Export `UMBRIEL_SOCKET`/`WAYLAND_DISPLAY` (`NIRI_SOCKET` on the VM), `SSH_AUTH_SOCK` etc. from `systemctl --user show-environment`; the VM has an `in-session` wrapper. A whole desktop session can also be exercised over SSH with a headless Weston standing in for Moonshine's compositor — see "Testing it remotely" in `docs/decisions.md`; clean up transient units and runtime drop-ins afterwards.
- **`Terminal=true` in a `.desktop` entry does nothing here** (glib's hardcoded terminal list lacks Ghostty, and fails misleadingly). A terminal program's entry must spawn the terminal itself, as `home/neovim.nix` does.

### Compositors

- **The compositor config is live-symlinked to a separate `~/.dotfiles` clone** on each host (`docs/live-dotfiles.md`) — `home/umbriel/cfg/*.toml` on the desktop and theseus, `home/niri/cfg/*.kdl` on the VM. Edits here reach a host only once pushed and pulled; `scp` to test (Umbriel reloads on save, niri needs `niri msg action load-config-file`). A *new* file needs a Home Manager switch for its symlink. Validate Umbriel edits with `umbriel config validate` on the host.
- **On AZERTY, an Umbriel bind written for a US keyboard parses, validates and never fires.** Binds match the unshifted keysym, so the number row is `ampersand eacute quotedbl …` and `Mod+Minus` is physically 6. Check new binds against `xkbcli compile-keymap --layout fr --variant azerty`. Noctalia's own digit shortcuts need the same rebinding (done for the session menu).
- **XWayland exists now, via `xwayland-satellite` — and it is niri's own integration, not a service this repo wires up.** It only needs the binary on greetd's PATH (`modules/desktop/niri.nix`) — no KDL block, not `home.packages`, fresh login to take effect. It needs ≥ 0.8.3; Steam menus flashing open and closing is 0.8.2, not a Steam bug. Umbriel runs plain Xwayland itself. VM only now.
- **Adding an `include` to niri's `config.kdl` requires seeding the file** — a missing include is fatal to niri and bricked a fresh VM login once (`home.activation.seedNiriStyle` is the pattern).
- **niri's KDL `environment {}` block does not reach the systemd `--user` manager.** Use `environment.sessionVariables` for anything user services need.
- **"Zen crashes on start" is not a crash — it is `xulstore.json` fighting a niri window-rule** (maximize, then Zen unsets it and lands at half width). The fix is compositor-side: uncomment `default-column-width` in `home/niri/cfg/rules.kdl`. Get the on-screen symptom in one sentence before investigating any "crash".
- **Blur/transparency is currently OFF**, neutralized not deleted: `home/transparency.nix` is `1.0`. Turning it back on: `0.80` there, `shell.panel.transparency_mode = "glass"`, then delete `[appearance.blur] enabled = false` in `home/umbriel/cfg/misc.toml` (Umbriel) or uncomment the blur blocks in `rules.kdl`/`misc.kdl` (niri).
- **niri's blur is invisible without real client-side alpha.** It draws behind a surface, so it only shows where the client itself is translucent; niri's `opacity` rule just fades the whole window over a sharp backdrop, which is expected.

### Home Manager and Nix

- **Check a wrapper in *this* pin's nixpkgs, not whatever `nixpkgs#` resolves to locally.** A flags file or env-var hook that exists in a newer nixpkgs evaluates green and does nothing here (`~/.config/code-flags.conf` was this). Build through the flake's locked input to inspect.
- **A Home Manager sub-module accepts settings while disabled, and silently discards them** (`xdg.mimeApps.defaultApplications` with `xdg.mimeApps.enable = false`). Check the option group a third-party "set as default" flag writes into is actually enabled.
- **Zen's `policies.Preferences` silently drops any pref outside Firefox's prefix allowlist, and `zen.*`/`mod.*` are not on it.** The only trace is one `Preference not allowed for stability reasons` line in the browser console. Read the allowlist out of the shipped `omni.ja` (`Policies.sys.mjs`), not the docs. `zen.*` prefs need `profiles.<name>.settings`, i.e. handing the profile to Home Manager — declined so far.
- **The same shape recurs for any app's own mutable state** (Zen's `xulstore.json`, a stale `nvim/lua/plugins/base16.lua`): when a declared setting doesn't apply, look for state the app seeded itself.
- **`home.sessionVariables` values are not shell-expanded** — use `${config.xdg.configHome}`, not `$XDG_CONFIG_HOME`.
- **A `services.logind.settings` change does nothing until logind re-reads its config, and a switch doesn't make it.** The new `logind.conf` lands in `/etc`, but NixOS only reloads `systemd-logind` when its *unit* changes. Until then the old action runs (theseus's power key kept powering off). Reboot, or `sudo systemctl reload systemd-logind` (`Type=notify-reload`, so no session is lost); check with `busctl get-property org.freedesktop.login1 /org/freedesktop/login1 org.freedesktop.login1.Manager HandlePowerKey`, not the file.
- **"Existing file … would be clobbered" during activation**: retry once; it has been a one-off ordering race.
- **`useGlobalPkgs` means Home Manager can't set `nixpkgs.config`** — unfree allowances go in `modules/system/unfree.nix`.
- **The unfree allow-list keys on a package's *pname*, so an upstream `pkgs/by-name` move can silently unmatch an entry** (`idea` → `intellij-idea`). After `nix flake update`, read an unfree failure as a possible rename first: `nix eval .#nixosConfigurations.<host>.pkgs.<attr>.name`.
- **A rolling input's source rots in place, and `--no-build` can't see it.** Prefer inputs with immutable release artifacts, and run the *full* `nix flake check` after any `nix flake update` before pushing.
- **Switching `useUserPackages` on doesn't clean up the old profile, and `~/.nix-profile` wins on PATH** (VM only).
- **A system unit naming a user's package needs `/etc/profiles/per-user/<name>/bin/...`, not `/run/current-system/sw/bin/...`** — which works only because `useUserPackages` is on.
- **A MIME default has two ways to silently claim nothing.** A desktop entry's `MimeType=` names aren't what files resolve to (`audio/x-flac` vs `audio/flac`), and a type with its own glob never falls back to `text/plain`. Build lists from `globs2` and check real files; `.ts` is a Qt translation file. The 2026-08-23 audit has the full table.

### Gaming

- **Millennium's Bun FOD is not reproducible, so CI routes around it**: `flake.nix`'s `ciClosure` builds gaming hosts with stock Steam. A different wrong hash each time is this, not upstream drift; locally it is expected and unfixable here.
- **Protontricks must come from `programs.steam.protontricks.enable`, never `home.packages`** — a plain one can't see `STEAM_EXTRA_COMPAT_TOOLS_PATHS` (`Could not find configured Proton installation!`). It is never substituted, and CI deselects one test that fails only on GitHub's runner.
- **`programs.steam.extraCompatPackages` reaches Steam and nothing else.** Heroic sees `proton-cachyos` only through `home/heroic.nix`'s symlink, which must point where the tool tree actually lives — check it after a `chaotic` bump. Don't rename Heroic's links (it orphans games) and don't update `GE-Proton-latest` from Heroic's Wine Manager.

### Moonshine

- **Moonshine's config is NixOS-side, and a `home/moonshine.nix` would be inert** (`services.moonshine.settings`). Likewise a polkit rule needs `security.polkit.extraConfig`, not `/etc/polkit-1/rules.d`.
- **A Moonshine app that fails to start produces no output by default.** Keep `stdout`/`stderr = "journal"` on every entry; logs are in `journalctl --user -u moonshine-session.service`.
- **Both game launchers are single-instance, so Moonshine has to close them before it can stream them** (each entry's `pre_command`). The Heroic one refuses while a download, install or game is running — a stream that fails instead of starting can be that guard; read the log first.
- **Moonshine's automatic box art can never resolve on NixOS, so every app entry must declare `boxart`** (rasterized Papirus-Dark PNGs). Render a candidate icon and look at it against a dark grid before picking it.
- **Moonshine's "Desktop" stream is a nested Umbriel started by hand, never `start-umbriel`.** `umbriel -s <startup>` nests by itself and publishes nothing; the startup command does the session wiring. `mod_key` is pinned to Super because a nested Umbriel defaults to Alt (its `mod key: Alt` log line ignores the pin). A blank stream with a live cursor means the nested compositor never rendered. **Keys dropped while the mouse works means no keyboard focus**: Moonshine's default `steam_mode` makes focus Steam-controlled, so only a window with a Steam game id is focusable (`No focus candidates; clearing focus` in its `focus=debug` log). The entry's `command` therefore carries a dummy `AppId=2000000000`, which Moonshine finds by scanning the Umbriel window's parent command lines; `steam_mode` is server-wide, so turning it off instead would change the Steam and Heroic streams too.
- **Streaming the desktop while logged in locally degrades to a bare compositor, deliberately** (`graphical-session.target` is per-user; look for `already belongs to a local login`). The teardown trap must queue `umbriel-shutdown.target` with **`--no-block`** (a blocking start deadlocks with the unit's own stop), and `noctalia.service`'s 5 s `TimeoutStopSec` bounds Noctalia's hang when its compositor dies first — which a normal logout also triggers.

### Hardware and audio (desktop)

- **The desktop's Z407 has two gain stages, because kernel 7.1 disabled the hardware one** — the puck drives both, so uneven stepping is expected. Measure before theorising: comment out the volume binds in `home/umbriel/cfg/keybinds.toml`, freeze the host volume and turn the puck.
- **PipeWire's volume scale is cubic, so a percentage is not a loudness**; read `pw-dump`, not `wpctl get-volume`, at low volume. A dB-stepping wrapper was built and deliberately removed — don't re-propose it.
- **The desktop's default audio output is fixed at login, deliberately; a runtime pick does not persist.** The Z407 wins by priority (matched by MAC) once Bluetooth reconnects, ~10 s after login.
- **`ensurePrinters` with `model = "everywhere"` can take CUPS down at boot**, so the desktop vendors its OfficeJet PPD. Keep a declared queue's `name` equal to a hand-made one's; cups-browsed queues need removing by hand with `sudo lpadmin -x`.

### Other hosts

- **A keyboard has two independent namespaces, and only one of them locks you out**: `console.keyMap` and `services.xserver.xkb.layout`. Leaving the second unset gave GDM a US keyboard (a plain auth failure in the journal). Set both from `vars.system`, together.
- **`TERM` travels over SSH, so a host needs terminfo for terminals it does not have** (`modules/system/shell.nix`, all hosts). Guard `bindkey`s on a non-empty capability with `if`, not `&&`.
- **A GSettings override file is not a dconf file**: headers are dotted schema ids (`[org.gnome.shell]`); a slash header compiles clean and does nothing. Verify against the `gnome-gsettings-overrides` derivation in the host's closure.
- **A `.gschema.override` cannot set a relocatable schema, and says nothing when it fails.** Use `programs.dconf.profiles.<name>.databases` (`modules/programs/rhythmbox.nix`), and verify by dumping that database in isolation.
- **Per-user GNOME language can only be seeded, never declared** — AccountsService owns and rewrites the per-user file. The tmpfiles `f` rule only reaches an account that has never logged in, so expect the manual Settings pass; the rule needs a *literal* `\n` and an existing locale.
- **Starship has no prompt config on a host without Noctalia**, hence `home/starship.nix`'s inverted gate; the prompt is defined once there. After touching a Nerd Font `symbol`, check the codepoints — private-use glyphs get silently stripped.
- **The VM has its own rendering quirks** (virtio-gpu-gl/SPICE) — not config bugs.

## Roadmap

| # | Phase | Status |
| --- | --- | --- |
| 1 | Foundation — structure, `specialArgs`/`features`, sops-nix, disko + nixos-anywhere | done |
| 2 | Profiles — introduced once ≥2 hosts had overlapping imports | in progress: `base.nix` and `gaming.nix` exist; further role profiles still deferred. The desktop and theseus share the gaming profile, the compositor and most features, and a `desktop.nix`/`laptop.nix` split would say nothing a host's own `default.nix` doesn't. |
| 3 | Desktop — niri, greetd, Noctalia Greeter, Noctalia Shell, SSH agent unlock | done, verified live |
| 4 | Terminal — Ghostty, Zsh, Starship, Git, Lazygit | done, verified live |
| 5 | Theming — cursor, icons, GTK/Qt | done, verified live |
| 6 | Applications — VS Code, Zen Browser, Vesktop, Nautilus, Feishin, Obsidian | done, verified live |
| 7 | Extra features — Docker, Tailscale, printing, gaming profile | done, **verified live** on the desktop (2026-08-20): Steam under `xwayland-satellite`, a game played through Heroic on `proton-cachyos`, and a wired Xbox pad on `xone`. `nix flake check` also eval's and closure-builds the gaming stack on its real host rather than by temporarily importing `profiles/gaming.nix` on the VM. Only `xpadneo` (Bluetooth pads) is still untested. |
| 8 | Long-term — `nix flake check` as the CI gate, `justfile`, doc upkeep, multi-host hardening | done except multi-host hardening, now partly closed: the desktop has its flake entry, age key, real system-disk path and desktop stack. theseus is installed and largely verified live (2026-10-19); what remains is its few untested items (`hosts/theseus/README.md`) and inotmac's recovery-key re-encryption |

**Deferred, not declined: backups.** Nothing backs up personal data yet — Snapper's snapshots live on the disk they protect, and `ARCHITECTURE.md` scopes the repo's recoverability to config, not data. The operator chose **restic** (`services.restic.backups`, password via sops) on 2026-10-10 and postponed it; destination and contents are still open. See `docs/decisions.md`, "Maintenance tooling".

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

Umbriel (desktop, theseus) or niri + xwayland-satellite (the VM), greetd, Noctalia Greeter, Noctalia Shell v5 (native theming, GTK/Qt theming templates), Papirus icons, Bibata cursors, adw-gtk3, qt5ct/qt6ct, Adwaita Sans (UI) + JetBrains Mono Nerd (mono) · Ghostty, Zsh, Starship, Git + delta, Lazygit, Lazydocker, Fastfetch, eza, bat, fd, ripgrep, fzf, zoxide, yazi, btop, nix-index + comma, jq, tealdeer, dust, nh · Zen Browser (+ the Bitwarden extension, without the desktop app — see `docs/decisions.md`), VS Code, Vesktop, Nautilus, Loupe, Papers, Celluloid, Decibels, Document Scanner, Feishin, Obsidian · Steam (Millennium-patched), proton-cachyos (x86-64-v3) + GE-Proton, Heroic, umu-launcher, Prism Launcher, protontricks, xone/xpadneo, NTSync, GPU Screen Recorder, OBS Studio · Moonshine (Moonlight-compatible streaming, desktop only) · Moonlight (the streaming client, theseus only) · KDE Connect, FreeCAD, KiCad, Orca Slicer, darktable, IntelliJ IDEA, Claude Code, GitHub CLI (on `features.kdeconnect`/`cad`/`photography`/`development`) · GNOME + GDM with Chrome, MusicBrainz Picard and Rhythmbox on the shared iMac (system-wide, not Home Manager) · Tailscale · Docker Engine + Compose · PipeWire, Bluetooth, Printing (CUPS + Avahi), NetworkManager, Snapper, smartd, btrfs scrub, fwupd · nixd, nil, nixfmt, statix, deadnix, just, sops, age (all in the dev shell).

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
gamescope, gamemode, MangoHud, Lutris, Bottles, goverlay, ludusavi,
steamtinkerlaunch and vkbasalt were each proposed and declined, and Proton
GE was replaced by CachyOS's fork — then brought back on 2026-10-10 as a
declared fallback (`proton-ge-bin`) beside it, replacing a copy Heroic had
downloaded by hand. protontricks was declined with them and
later asked for anyway (2026-08-31); it is in, via
`programs.steam.protontricks.enable` in `modules/programs/steam.nix` — see
the gotcha below for why that flag and not a `home.packages` entry. The GUI Proton installers
(protonup-qt, protonplus) are also absent on purpose — they write Proton
builds into `~/.steam` by hand, which is the app-owned-mutable-state problem
above; `programs.steam.extraCompatPackages` does it declaratively instead.
Read `docs/decisions.md`'s Phase 7 section before re-proposing any of them.

Millennium is **not** in nixpkgs (open packaging request, nixpkgs#382086) and
neither is CachyOS's Proton or kernel — all three come from third-party
flakes, which is why `flake.nix` has two inputs that don't follow this repo's
nixpkgs.
