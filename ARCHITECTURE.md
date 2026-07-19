# Architecture

## Purpose

This repository contains a complete, declarative NixOS configuration designed to be understandable, modular, reproducible, and suitable as a long-term personal configuration — one that can grow from a single machine into a small personal infrastructure.

Primary goals:

- A single Git repository containing the entire configuration.
- Flakes as the entry point.
- Home Manager integrated into NixOS.
- Clear separation of responsibilities.
- Modular organization.
- Easy expansion to multiple machines.
- Reproducible installations.
- Thorough documentation, kept as a single source of truth.

When making changes or suggesting improvements, prefer solutions that preserve these goals over short-term convenience or premature abstraction.

---

# Part 1 — Design Philosophy

## Core Design Principles

The architecture separates responsibilities along one simple line:

```
Configuration lives in modules.
Wiring lives in flake.nix.
Machine identity lives in variables.nix.
Machine capability lives in features.nix.
```

Each part of the repository has exactly one job:

- **flake.nix** decides how everything connects together.
- **Hosts** describe which physical machine is being built.
- **Profiles** describe what role that machine has, and select a default set of modules and features.
- **Modules** contain the actual system configuration.
- **Home Manager** manages the user's personal environment.
- **Variables** store identity data that differs per machine (hostname, timezone, user).
- **Features** store capability toggles that differ per machine (Docker on/off, Steam on/off).

Keeping variables and features as two distinct files (rather than one growing `variables.nix`) matters as the repo scales: identity data changes rarely and only makes sense once per machine, while feature flags change often and are meant to be overridden per-host, per-profile, or both. Mixing them turns one file into a second `configuration.nix`.

## The Overall Architecture

```
                 flake.nix
                     │
                     ▼
                    Host
                     │
                     ▼
                  Profile
                     │
                     ▼
                 Modules
                     │
                     ▼
                  Options
                     │
                     ▼
              Generated System
```

Higher layers decide **what should be built**. Lower layers decide **how that works**. Each layer should only need to understand the layer directly below it:

- A host knows which profile(s) it uses.
- A profile knows which modules it imports and which features it defaults to on.
- A module knows how to configure one feature.
- A module does not need to know which machine or profile uses it.

## Why We Avoid Over-Engineering

A common mistake in Nix configurations is building abstractions before understanding the problem they solve — a repository arriving on day one with `mkHost`, `mkSystem`, `mkDesktop`, `mkProfile`, `mkFeature`, etc., before a single machine has been built with plain modules.

This project follows the opposite order:

1. Learn how the system works with plain modules.
2. Identify patterns that are genuinely repeated across two or more real hosts.
3. Introduce a helper abstraction only once a pattern is proven to repeat.

Every abstraction in `lib/` should be traceable to a specific, already-repeated need — not a hypothetical future one.

---

# Part 2 — Repository Structure

## flake.nix

`flake.nix` is the composition root and entry point. It is the **project coordinator**: it does not contain system configuration, it answers "which inputs, which hosts, which modules, which package set, which Home Manager wiring."

Responsibilities:

- Declare flake inputs (nixpkgs, home-manager, and any others).
- Define flake outputs (`nixosConfigurations`).
- Define the list of available hosts.
- Create the package set (`pkgs`) per host, including overlays.
- Wire Home Manager into each host's NixOS configuration.
- Pass shared data (variables, features, `lib` helpers) into modules.

**Two different mechanisms for two different kinds of data — chosen deliberately, not interchangeably:**

- **`vars` (identity data)** is plain, non-optional data with no notion of "default vs. override" — a hostname either is or isn't "laptop." It's passed as `specialArgs`, a plain function argument available to every module:

  ```nix
  lib.nixosSystem {
    specialArgs = { inherit vars; };
    modules = [
      ./hosts/${hostName}
      home-manager.nixosModules.home-manager
      { home-manager.extraSpecialArgs = { inherit vars; }; }
    ];
  };
  ```

  Any module can declare `{ vars, ... }:` to read it.

- **`features` (capability toggles)** deliberately is *not* passed via `specialArgs`. Toggles need real "profile sets a default, host overrides it" semantics, and `specialArgs` values are just function arguments — the module system's priority mechanism (`lib.mkDefault`, `lib.mkForce`, `lib.mkOverride`) only resolves *declared options*, not plain data handed in this way. So `features` is declared once as a real NixOS option (see **Declaring the `features` Option** below) and every host/profile sets it through normal module config (`features.docker = true;` or `features.docker = lib.mkDefault true;`), which the module system merges by priority as usual. Modules read it as `config.features.x`, not as a function argument.

  Home Manager modules don't get `config` for the *NixOS* configuration directly — they read it via the `osConfig` special arg that Home Manager automatically provides when integrated into a NixOS module: `{ osConfig, ... }: osConfig.features.x`.

This is the one and only path each kind of data takes into modules — avoid a second mechanism (e.g. `import` statements reaching into `hosts/`, or passing `features` through `specialArgs` as well "just to be safe") appearing later, since two paths for the same data is how configs drift and silently stop merging the way the diagrams below claim.

`flake.nix` should stay a few hundred lines of *relationships*, never system settings.

## Declaring the `features` Option

Before any host or profile can set `features.docker = true;` or `lib.mkDefault`, `features` must exist as a declared option — otherwise there's nothing for the module system to merge by priority. This is declared once, in a small module every host imports:

```nix
# modules/options.nix
{ lib, ... }:
{
  options.features = lib.mkOption {
    type = lib.types.submodule {
      options = {
        docker = lib.mkOption {
          type = lib.types.bool;
          default = false;
          description = "Enable Docker Engine + Compose.";
        };
        steam = lib.mkOption {
          type = lib.types.bool;
          default = false;
          description = "Enable Steam + gaming stack.";
        };
        gamemode = lib.mkOption {
          type = lib.types.bool;
          default = false;
          description = "Enable Feral GameMode.";
        };
      };
    };
    default = { };
    description = "Feature flags controlling optional functionality. Every toggle a host or profile can set must be declared here.";
  };
}
```

**Why a submodule instead of `attrsOf bool`:** `attrsOf bool` accepts any key, which means a typo like `features.dcoker = true;` merges into a new, unused attribute — nothing errors, the feature just silently never turns on. Declaring each toggle as its own option costs one extra block here per feature, but turns that typo into an eval-time "unknown option" error instead of a machine that quietly doesn't have Docker. Add the option in this file in the same commit that first references it in a profile or host.

Every host imports this module (typically via a shared list in `flake.nix` rather than repeating the import per host). With the option declared, `features.x = true;`, `lib.mkDefault`, and `lib.mkForce` all behave exactly as the standard NixOS module system merging rules describe — a profile's `mkDefault` (low priority) is cleanly overridden by a host's plain assignment (normal priority), and any module can read the merged result at `config.features.x`.

## Hosts

Each physical machine has its own directory:

```
hosts/
    laptop/
    desktop/
    server/
    vm/
```

Example:

```
hosts/laptop/
    default.nix
    hardware-configuration.nix
    variables.nix
    features.nix
    disko.nix
    secrets.nix
    secrets/
        secrets.yaml
```

A host defines:

- Hardware configuration (generated, not hand-edited).
- Machine identity (`variables.nix`).
- Feature overrides for this specific machine (`features.nix`).
- Disk layout (`disko.nix`).
- This host's encrypted secrets (`secrets/secrets.yaml`) and the sops-nix wiring that decrypts them (`secrets.nix`) — see **Secrets Management** below for why secrets live here rather than in a shared top-level directory.
- Which profile(s) it imports.

Hosts should stay small — a few imports and two small data files. A host describes **what machine is being built**, not how any feature works internally.

## Profiles

Profiles describe the *role* a machine plays. A host is the physical machine; a profile is what it's for.

```
profiles/
    laptop.nix
    desktop.nix
    gaming.nix
    server.nix
    workstation.nix
```

**What a profile actually contains**: a profile is a plain module that does two things — nothing more:

1. Imports the set of modules that role always needs.
2. Sets the *default* value of relevant feature flags for that role, using `mkDefault` so a host can still override them.

```nix
# profiles/gaming.nix
{ lib, ... }:
{
  imports = [
    ../modules/programs/steam.nix
    ../modules/programs/gaming.nix
    ../modules/hardware/graphics.nix
  ];

  features = {
    steam = lib.mkDefault true;
    gamemode = lib.mkDefault true;
  };
}
```

Because `features` is a declared option (see **Declaring the `features` Option** above), `lib.mkDefault` here genuinely sets a low-priority default that the module system will merge — it isn't just data sitting in an attrset.

**Rule governing profiles vs. feature flags:** profiles set *defaults* for a role, at `mkDefault` priority; a host's `features.nix` sets plain, normal-priority values, which the module system's standard merging always resolves in the host's favor for any key both define. A module never checks "which profile am I in" — it only ever reads `config.features.x`. This keeps exactly one mechanism (`config.features.*`) controlling whether a module is active, and profiles become nothing more than a convenient bundle of sensible defaults plus module imports. There is never a case where a feature is "on because of a profile" in a way that a plain `features.nix` flag couldn't express directly — profiles are a convenience layer, not a second source of truth, and the module system (not hand-written logic) is what makes host overrides win.

**Pitfall to watch for:** a profile that imports a module but forgets to set that module's `mkDefault` will import inert code — the module is present in the build closure but stays off (via the module's own `lib.mkIf config.features.x`) until some host explicitly sets `features.x = true;`. Treat "add the import" and "set its `mkDefault`" as one atomic edit whenever a profile is touched; a profile with imports but no matching defaults is usually a mistake, not a deliberate choice.

```
Host
 │  imports one or more profiles, sets features.nix at normal priority
 ▼
Profile
 │  imports modules, sets features at mkDefault (low) priority
 ▼
Modules
 │  read config.features.* via mkIf, know nothing about hosts or profiles
 ▼
System
```

## Modules

Modules contain the actual NixOS configuration. Each module has a single responsibility and should describe **how a feature works**, never **which machine uses it**.

```
modules/
    system/
        boot.nix
        networking.nix
        users.nix

    hardware/
        audio.nix
        graphics.nix

    desktop/
        niri.nix          # compositor package + session, system-level only
        greetd.nix
        noctalia.nix      # Noctalia Shell — native theming, replaces Stylix (see Phase 3)
        portals.nix

    services/
        docker.nix
        tailscale.nix
        printing.nix

    programs/
        steam.nix
        vscode.nix
        gaming.nix
```

**System vs. Home Manager split for desktop modules (previously blurred):** where a program has both a system half and a user half — Niri is the clearest example — the split is:

- `modules/desktop/niri.nix` (NixOS): installs the compositor package and enables the Wayland session entry. Nothing about the user's keybindings or layout lives here. greetd itself — configured to launch that session — is a separate `modules/desktop/greetd.nix`, gated on the same feature flag rather than folded into `niri.nix`, since it's a distinct systemd service with its own concerns (greeter package, PAM).
- `home/niri.nix` (Home Manager): the user's actual Niri configuration — keybindings, workspaces, window rules, appearance.

The same split applies to anything else that's "system package + user config": Noctalia Shell (`modules/desktop/noctalia.nix` for the package/services/Cachix substituter, `home/noctalia.nix` for theming/wallpaper settings), GTK theming (portal + package at system level, `dconf`/settings at Home Manager level), and shell tools where a system package is needed system-wide versus a user's personal shell config.

## Home Manager

Home Manager manages the user's personal environment; NixOS manages the machine.

```
NixOS                       Home Manager
 ├── Hardware                ├── Shell
 ├── Drivers                 ├── Applications
 ├── Services                ├── Themes
 ├── System packages         ├── Editor settings
 └── Security                └── Desktop preferences (user-level)
```

Examples of what Home Manager owns: Ghostty, Zsh, Starship, Git configuration, VS Code, Zen Browser, Niri's user configuration, GTK settings, themes, wallpapers.

**Home Manager rollback:** because Home Manager is integrated into the NixOS module (`home-manager.nixosModules.home-manager`), its generations are created and rolled back together with the system generation via `nixos-rebuild switch --rollback` — there is no separate Home Manager generation to manage. This is a deliberate reason to prefer NixOS-integrated Home Manager over standalone Home Manager for this repository: one rollback command covers both.

**Autostarting applications: systemd user services, not niri's `spawn-sh-at-startup`.** niri's own docs support a `spawn-sh-at-startup` directive for launching things at compositor start, but this repo prefers `systemd.user.services.<name>` instead, bound to the standard `graphical-session.target` (`Unit.PartOf`/`Unit.After = "graphical-session.target"`, `Install.WantedBy = [ "graphical-session.target" ]`) — the same target niri's own packaged systemd integration (`niri.service`) already binds to and pulls in automatically. This gets proper start/stop lifecycle (services stop when the session ends, rather than leaking a process), `Restart=on-failure`, `journalctl --user` logging, and ordering handled by systemd instead of a hardcoded `sleep N` guessing how long niri takes to be ready. Noctalia Shell already follows this (`programs.noctalia.systemd.enable = true`, paired with `shell.launch_apps_as_systemd_services = true`); apply the same pattern to any future autostarted application (Vesktop, Zen Browser, ...) as its own Home Manager module is written, rather than a shared `cfg/autostart.kdl`.

## Variables

`variables.nix` holds only machine **identity** — values that are set once per machine and rarely change:

```nix
# hosts/laptop/variables.nix
{
  system = {
    hostName = "laptop";
    timeZone = "Europe/Paris";
    keyMap = "fr-pc";
  };

  user = {
    name = "myuser";
    fullName = "My Name";
  };
}
```

## Features

`features.nix` holds only **capability toggles** — set as the `features` option (declared once in `modules/options.nix`, see above), expected to be overridden per host, and read via `config.features.x` with `lib.mkIf` inside modules. Being a module itself (not plain data), it sets `features` directly at normal priority, which overrides any `mkDefault` a profile set:

```nix
# hosts/laptop/features.nix
{ ... }:
{
  features = {
    docker = true;
    steam = false;
  };
}
```

**Not every capability needs its own flag.** Bluetooth was originally planned as one (`features.bluetooth`, `modules/hardware/bluetooth.nix`), but was dropped once it became clear no host in this repo, real or planned, would ever want a desktop environment (Niri + Noctalia Shell) *without* Bluetooth — the only thing that would have driven a per-host difference. Noctalia's own `programs.noctalia.recommendedServices.enable` now turns Bluetooth on directly (`modules/desktop/noctalia.nix`), rather than through a flag that could never actually differ between hosts. The lesson generalizes: a flag earns its place by expressing a *real* axis of variation between hosts, not just because a capability is optional in the abstract — reserve `features.*` for toggles a host or profile might genuinely set differently.

Modules consume the merged value, never hardcode it:

```nix
{ config, lib, ... }:
lib.mkIf config.features.docker {
  virtualisation.docker.enable = true;
}
```

Splitting `features.nix` out of `variables.nix` keeps each file growing for a single reason — identity data almost never changes; feature flags change with every new machine or every experiment.

## Hardware Configuration

`hardware-configuration.nix` is generated by NixOS and should not be hand-edited. Machine choices belong in `variables.nix` / `features.nix`; hardware detection belongs in `hardware-configuration.nix`.

## Helper Library (`lib/`)

```
lib/
    mkHost.nix
    mkUser.nix
    utils.nix
```

Per the over-engineering principle above: a helper only belongs here once the same pattern has already been written by hand at least twice across real hosts. `lib/` holds tools that help build the system; `modules/` holds what the system does. Keeping them separate prevents `flake.nix` from becoming a dumping ground for one-off functions.

## Specialisations

NixOS allows alternate versions of a configuration to exist alongside the main one — useful for experimental configurations, alternate kernels, gaming-specific tweaks, or debug environments, without touching the primary config.

**Cost worth noting:** each specialisation is built and kept in the system closure alongside the main configuration, which roughly multiplies build and switch time by the number of specialisations, and they are easy to silently bit-rot since they aren't boot into by default. Treat specialisations as a tool for short-lived experiments, not a permanent parallel configuration — if a specialisation is still in use after a few weeks, it's a sign it should become its own host or profile instead.

## Directory Philosophy

```
hosts/       -> machine definitions (identity + features + profile selection + this host's encrypted secrets)
profiles/    -> machine roles (module bundles + default features)
modules/     -> reusable, machine-agnostic system configuration
home/        -> Home Manager configuration
lib/         -> helper functions, introduced only when proven necessary
overlays/    -> package overlays
pkgs/        -> custom packages
scripts/     -> helper scripts
wallpapers/  -> wallpapers
assets/      -> static assets
docs/        -> project-specific runbooks (how to bootstrap a host, manage
                secrets) — distinct from this file (why) and per-directory
                READMEs (what belongs where); see docs/README.md
```

---

# Part 3 — Operational Concerns

## Secrets Management

Secrets are never stored in plaintext in the repository — no passwords, API keys, private tokens, or SSH private keys committed as-is.

**Tool decision:** use **sops-nix** from the start, rather than deciding this in a later phase. Reasoning: secrets are referenced from almost every module eventually (Git identity, Wi-Fi credentials, API tokens, and — see below — the SSH/GPG key material itself), so retrofitting a secrets tool after several hosts already exist means touching every one of them. agenix remains a reasonable alternative if age keys are preferred over PGP/age-via-sops, but pick one now rather than leaving it open.

Each host owns its own encrypted file at `hosts/<name>/secrets/secrets.yaml`, colocated with that host's other identity/data files (`variables.nix`, `disko.nix`) rather than in a shared top-level `secrets/` directory — a host directory is meant to hold everything about that one machine, and a top-level `secrets/` would split that across two places for no benefit once each host's secrets are already scoped to that host alone.

```
Configuration is public.
Secrets remain encrypted at rest, decrypted only at activation.
```

**Decryption key: a standalone per-host age key, not the host's SSH key.** The obvious default — deriving the sops recipient from the host's own SSH host key (`ssh-to-age`) — has a real cost: NixOS regenerates a fresh SSH host key on every reinstall unless you go out of your way to preserve the old one, so decryption capability would silently break on every reinstall too. A dedicated age keypair per host, generated once by the operator and independent of the host's SSH identity, decouples the two lifecycles — reinstalling (or rotating the SSH host key for any other reason) doesn't touch secrets decryption at all. The cost is one more key file to track per host; worth it for how often hosts get reinstalled during setup and testing.

**Onboarding a new host's secrets:**

1. Generate a standalone age keypair for the host: `age-keygen -o ~/.config/sops/age/<host>.txt` (kept locally by the operator, never committed).
2. Add its public key as a recipient in `.sops.yaml`, scoped to `hosts/<host>/secrets/.*\.yaml$`.
3. Write and encrypt `hosts/<host>/secrets/secrets.yaml` against that recipient (`sops --encrypt --in-place hosts/<host>/secrets/secrets.yaml`).
4. Provision the *private* key onto the target during install via `nixos-anywhere --extra-files <dir>`, where `<dir>/var/lib/sops-nix/key.txt` holds the key — this is the same install run that applies the rest of the host's config, so the machine boots already able to decrypt its own secrets. `hosts/<host>/secrets.nix` points `sops.age.keyFile` at that path.

Re-encrypting after adding a new secret or rotating a key: `sops updatekeys hosts/<host>/secrets/secrets.yaml`.

This is a manual step outside Nix evaluation — nothing in `nix flake check` catches a host that's missing from the recipient list, since the host will simply fail to decrypt secrets at activation time on real hardware, not at build time. Add the new recipient in the same commit as the host directory itself so the two never drift apart.

## SSH Agent Unlock at greetd Login

Goal: SSH keys are unlocked automatically as part of logging in through greetd, instead of requiring a separate `ssh-add` and passphrase prompt later.

**Revised from an earlier gpg-agent + pam_gnupg design (see git history) once it turned out this repo already has everything needed, for free.** `programs.niri`'s upstream NixOS module sets `services.gnome.gnome-keyring.enable = lib.mkDefault true;` (for portal support), which in turn makes greetd's own module set `security.pam.services.greetd.enableGnomeKeyring = true;` — so gnome-keyring is *already* unlocked automatically at every greetd login, with a GCR-provided ssh-agent (`gcr-ssh-agent`, run as a per-session systemd user unit) already exporting `SSH_AUTH_SOCK` session-wide. Confirmed live: `systemctl --user show-environment` already shows `SSH_AUTH_SOCK=/run/user/<uid>/gcr/ssh` with no configuration from this repo beyond enabling Niri. Layering gpg-agent + pam_gnupg on top would have meant a second identity system (GPG capability subkeys) solving a problem that's already solved.

What's actually needed, then, is much smaller than originally planned — no new system or Home Manager module at all:

1. **Provision the private key via sops-nix**, decrypted straight to `~/.ssh/id_ed25519` rather than the usual `/run/secrets/` location:

   ```nix
   # hosts/<name>/secrets.nix
   { vars, ... }:
   {
     sops.secrets."ssh-private-key" = {
       path = "/home/${vars.user.name}/.ssh/id_ed25519";
       owner = vars.user.name;
       mode = "0400";
     };
   }
   ```

   `sops-install-secrets` creates missing parent directories itself, so `~/.ssh/` doesn't need to already exist.

2. **One manual, interactive step, done once per host**: log in graphically and run `ssh-add ~/.ssh/id_ed25519`, entering the passphrase. Whether gnome-keyring's login-keyring caching means this never needs repeating across reboots, or only lasts the one session, needs live verification per host — don't assume either way without checking.

**No `config.features.sshAgentUnlock` flag.** Whether a host wants this is expressed entirely by whether its `secrets.nix` declares the `ssh-private-key` secret — there's nothing else in the system that needs to react to a separate boolean, so one would just be a second, redundant way to say the same thing (the same lesson as dropping `features.bluetooth`, see **Features** above).

## Bootstrapping a New Host

**Gap previously left implicit:** "reproducible installations" is a stated goal, but everything above assumes a host already exists and is running — nothing describes going from bare metal (or a fresh VM) to a booted, disk-partitioned NixOS system declaratively. As written, that first step is an unstated manual process: boot the installer ISO, partition and format by hand, run `nixos-generate-config`, copy the result into the repo. That's the one place a fresh install can diverge from the repository before the repository even has a chance to describe the machine.

Two tools close this gap without adding a new mechanism to the repo's data model:

- **[disko](https://github.com/nix-community/disko)** — declares disk partitioning, formatting, and mounting as a Nix module, the same way everything else in this repo is declared. A host's disk layout becomes `hosts/<name>/disko.nix`, imported alongside `hardware-configuration.nix`, instead of a one-time manual `fdisk`/`mkfs` session that's never written down anywhere.
- **[nixos-anywhere](https://github.com/nix-community/nixos-anywhere)** — installs a flake-defined host over SSH from the installer ISO (or any Linux with SSH access), running disko's partitioning and the NixOS install in one step: `nixos-anywhere --flake .#<host> root@<installer-ip>`. No manual partitioning, no manual `nixos-generate-config` copy-paste.

**The installer ISO itself is a flake output**, not an ad hoc image built by hand each time: `packages.<system>.installer-iso`, a minimal installer with the *operator's* own SSH key (not any host's key) pre-authorized for root, so `nixos-anywhere` can reach it non-interactively. This is one key, reused to bootstrap every host — building it is `nix build .#installer-iso`.

Three distinct keys are in play during a bootstrap, worth keeping straight rather than conflating into "the" key:

1. **The operator's SSH key**, baked into the installer ISO — how `nixos-anywhere` reaches the target while it's still running the installer. Same key for every host.
2. **The host's own SSH host key** — generated fresh by NixOS during install, used afterward for that host's own sshd. Unrelated to secrets.
3. **The host's sops age key** — generated once by the operator (see **Secrets Management** above), provisioned onto the target via `nixos-anywhere --extra-files` during the same install run. Used only for decrypting that host's secrets, nothing else.

Onboarding a host is therefore: generate its age key → add it to `.sops.yaml` and encrypt its secrets → write `hosts/<name>/disko.nix` → run `nixos-anywhere` with `--extra-files` staging the age key onto the target → the machine boots already holding its secrets, with its own freshly-generated SSH host key for day-to-day access.

Recommended placement: **Phase 1 (Foundation)**, alongside sops-nix — both are "decide once, use for every host after" tooling, and retrofitting disko/nixos-anywhere after several hosts have been manually partitioned means those existing hosts stay undocumented exceptions to the "declarative disk layout" rule.

## Filesystem Choice and Snapshots

Filesystem is a per-host decision made in that host's `disko.nix`, not a repo-wide policy — a disposable test VM has no reason to carry the extra complexity of subvolumes and snapshot tooling, while a primary desktop benefits from being able to recover from a bad `rm` or browse file history. `the-entertaining-nios-vm` stays on plain ext4; hosts that want snapshotting use btrfs instead.

**Why btrfs, not ext4, for a snapshot-capable host:** ext4 has no native snapshot mechanism — the only way to get point-in-time recovery is a separate volume manager (LVM) layered underneath, one more moving part. btrfs bakes subvolumes and copy-on-write snapshots into the filesystem itself, and NixOS's `services.snapper` module manages them directly with no extra layer.

**On NVMe specifically**, btrfs's usual downsides (CoW/checksum overhead, compression CPU cost) are negligible — that overhead mattered more on spinning disks or slow SATA SSDs, where it was a meaningful fraction of total I/O time. On NVMe it's effectively free: `compress=zstd` doesn't measurably cost speed, since zstd's default level is cheap CPU, most already-compressed assets (game/media files) are detected and stored raw by btrfs's own heuristic, and reading fewer physical bytes off an already-fast drive costs nothing.

**Subvolume layout** (see `hosts/desktop/disko.nix` for the reference implementation):

```
@               -> /             (root)
@home           -> /home
@nix            -> /nix          (excluded from root's snapshot scope — the
                                   Nix store churns constantly and NixOS
                                   generations already give rollback for it;
                                   snapshotting it too would just bloat every
                                   snapshot for no benefit)
@snapshots      -> /.snapshots        snapper's own subvolumes, per its own
@home_snapshots -> /home/.snapshots   convention: nested under the subvolume
                                       each one snapshots
```

Mount options on every data subvolume: `compress=zstd` (see above) and `noatime` — btrfs is copy-on-write, so even a read-triggered atime update becomes a real write elsewhere on disk; skipping atime avoids that write amplification, at the cost of the handful of atime-dependent tools (some mail servers, `tmpreaper`-style cleaners) this repo doesn't use anyway.

**Swap** is a plain (non-btrfs) partition, sized to match the host's RAM, with disko's `resumeDevice = true` wiring NixOS's hibernation (suspend-to-disk) support automatically. Swap-on-a-btrfs-file is possible but needs extra no-CoW/subvolume ceremony that a dedicated partition avoids entirely — not worth it when a whole partition is cheap on a modern disk.

**Snapshot service, not a bootloader change:** automatic snapshots are handled by `modules/services/snapper.nix`, gated behind `config.features.snapshots` like any other capability toggle (declared in `modules/options.nix` alongside `docker`, `steam`, etc.). This deliberately does *not* involve switching away from `systemd-boot` to GRUB + `grub-btrfs` for per-snapshot boot menu entries — NixOS's own generation rollback (`nixos-rebuild switch --rollback`) already covers "boot into a previous system state," so a second, overlapping mechanism for that isn't worth the extra bootloader complexity. Snapper's snapshots are for file-level recovery (an accidentally deleted file, browsing `/home` history), used via the `snapper` CLI after a normal boot — not a boot-time concern at all.

## Deployment Model

```bash
# Build and switch to the current configuration
nixos-rebuild switch --flake .

# Update dependencies
nix flake update

# Validate before committing
nix flake check

# Roll back (covers NixOS and integrated Home Manager together)
nixos-rebuild switch --rollback
```

A machine should always be fully recoverable from the Git repository alone — this covers *system configuration and Home Manager–managed dotfiles*, not personal data. Documents, photos, and anything not declared as a Home Manager file are outside the scope of this repository and need their own backup strategy; "recoverable from Git" describes the OS and environment, not the whole disk. Note that this requirement is about the *source*, not the mechanism — both of the two ways Home Manager can own a file (below) satisfy it equally, since both ultimately resolve to something this same Git repository controls.

**Two mechanisms for Home-Manager-owned files, not one.** The default — `source = ./some/path;` or `.text = "..."` — copies content into the Nix store as part of the build: fully reproducible from a single Git commit, but any edit needs a `nixos-rebuild switch` before it takes effect, and the store ends up holding its own copy of the data (kept until old generations are garbage-collected). For static text config this cost is negligible. It stops being negligible for large or frequently-edited content, which is why this repo also uses **`config.lib.file.mkOutOfStoreSymlink`** — a real, ordinary Home Manager API, not a special-cased hack — to symlink a small set of files directly to this repo's own live clone at `~/.dotfiles` instead. Editing one of these then takes effect immediately (the relevant program just needs to reload/restart), no rebuild required. The tradeoff: it requires `~/.dotfiles` to actually be a clone of this repo, kept manually up to date (`git pull`) on every host that uses one of these files — a real manual step Nix doesn't automate, accepted deliberately for the files where it's worth it. See `docs/live-dotfiles.md` for the day-to-day commands and the current list of which files use which mechanism.

Choosing between the two is a per-file judgment call, not a rule: store-copy by default (it's simpler, and correct for anything that needs Nix-side logic — e.g. `home/niri/cfg/input.kdl`'s per-host XKB layout lookup can't be a static file at all); reach for an out-of-store symlink once a file is edited often enough, or is large enough, that "rebuild just to test one change" becomes real friction. Wallpapers (`home/noctalia.nix`'s `wallpaper.directory`) and Niri's static KDL config (`home/niri.nix`'s `mkLiveFile`) both made that call already.

## Command Runner (`just`)

**Introduced in Phase 7, once the command surface has actually grown (previously listed in Part 4 but never used):** the raw commands above are fine for a single host, but they grow — building a *specific* host without switching to it, re-encrypting secrets after adding a recipient, running the full check suite — and typing exact `nix`/`nixos-rebuild` invocations from memory gets error-prone as the repo scales to multiple machines. A thin `justfile` at the repo root wraps these as named recipes without introducing a second source of truth: each recipe calls the same underlying command verbatim, so there's nothing to drift.

```just
# justfile
default:
    @just --list

# Build and switch to the current host's configuration
switch host=`hostname`:
    nixos-rebuild switch --flake .#{{host}}

# Build without switching — the safe way to test a host
build host=`hostname`:
    nix build .#nixosConfigurations.{{host}}.config.system.build.toplevel

# Roll back to the previous generation
rollback:
    nixos-rebuild switch --rollback

# Update flake inputs
update:
    nix flake update

# Run all checks (formatting, static analysis, dead code, per-host builds)
check:
    nix flake check

# Re-encrypt a host's secrets after adding a recipient
secrets-rekey host=`hostname`:
    sops updatekeys hosts/{{host}}/secrets/secrets.yaml
```

This is deliberately last in the roadmap, not first — wrapping commands before the repo has more than one host and a handful of recurring operations would be exactly the kind of premature abstraction this project avoids elsewhere (see **Why We Avoid Over-Engineering**). By Phase 7 the recipes reflect commands that have actually been typed by hand repeatedly, not ones guessed at up front. `direnv` (already part of the terminal stack) puts `just` on `PATH` automatically on entering the repo, so `just` alone is enough to see available recipes.

## Validation and CI

**Decision (previously left open):** run formatting and static analysis as `nix flake check` checks, not as a separate ad hoc script, so `nix flake check` is the single command that gates a commit both locally and in CI. Recommended tools, wired in as flake checks:

- `alejandra` — formatting
- `statix` — static analysis / anti-pattern detection
- `deadnix` — dead code detection

**Gap to close (previously missing):** formatting and static analysis catch style issues, not evaluation or build failures. `nix flake check` already evaluates every attribute under `nixosConfigurations` by default, which surfaces most eval errors, but a check that goes one step further and builds each host's system closure (`nix build .#nixosConfigurations.<host>.config.system.build.toplevel` for every host in the flake) catches breakage that only shows up once a derivation actually builds — a bad package reference, a broken overlay, a module that evaluates fine but fails to build. Wire this in as its own flake check so a host that can't build is caught in CI, not on the machine mid-`switch`.

GitHub Actions (Phase 6 of the roadmap) then only needs to run `nix flake check`, rather than reimplementing a separate validation pipeline — CI and local validation stay identical by construction.

## Naming Conventions

Files use lowercase names describing responsibility, not implementation:

```
Good:  networking.nix, greetd.nix, docker.nix
Avoid: NetworkStuff.nix, DockerSupport.nix
```

Note that `hosts/*/features.nix` and a profile's default-setting file don't share a naming pattern — a profile (e.g. `gaming.nix`) sets `features.*` defaults too, it's just named after its role rather than after "features". When auditing every place a feature gets set, grep for `features =` and `config.features` rather than for files literally named `features.nix`.

---

# Part 4 — Software Stack

## Desktop

Niri, greetd, Noctalia Greeter, Noctalia Shell v5 (native theming, GTK/Qt theming templates), fonts, icons, wallpapers, Wayland portals.

## Terminal

Ghostty, Zsh, Starship, Git, Lazygit, Fastfetch, eza, bat, fd, ripgrep, fzf, zoxide, yazi, btop.

## Applications

Zen Browser, Visual Studio Code (official build), Vesktop, Nautilus.

## Gaming

Steam, Proton GE, Gamescope, MangoHud, Gamemode, Millennium.

## Networking

Tailscale.

## Containers

Docker Engine, Docker Compose.

## Core Services

PipeWire, Bluetooth, Printing, NetworkManager, Snapper (btrfs snapshots).

## Development

nixd, nil, alejandra, statix, deadnix, direnv, just.

---

# Part 5 — Roadmap

## Phase 1 — Foundation

- Repository structure.
- Flake setup: `specialArgs` wiring for `vars`; `modules/options.nix` declaring the `features` option.
- `variables.nix` / `features.nix` split, each using its correct mechanism.
- sops-nix wired in from the start.
- disko + nixos-anywhere wired in from the start, so every host — including the first — is installed declaratively rather than via manual partitioning.
- Base system modules.
- First bootable configuration (no profiles yet — a host importing modules directly).

## Phase 2 — Profiles

- Introduce `profiles/` once at least two hosts exist and their module imports visibly overlap.
- Extract shared imports and default feature values into the first profile(s) (e.g. `desktop.nix`, `server.nix`).

## Phase 3 — Desktop Environment

- Niri (system module + Home Manager split as described above).
- greetd, Noctalia Greeter.
- Noctalia Shell (native theming — see note below on why this replaces Stylix).
- SSH agent auto-unlock at greetd login.
- Wayland session.

**Stylix was dropped, not implemented alongside the above (decision made mid-Phase 3, not anticipated when this roadmap was first written).** Noctalia Shell — the desktop bar/shell paired with Niri here — turned out to already generate a palette from the wallpaper and render it into external app configs (official templates for GTK and Qt, community templates for terminals/editors/browsers) — the same job Stylix would have done. Running both would mean two systems fighting over the same GTK/Qt/terminal config files. `modules/desktop/stylix.nix` will not be created; the module tree above reflects this.

## Phase 4 — Terminal Environment

- Ghostty, Zsh, Starship, Git, Lazygit.
- Shell migration into Home Manager.

## Phase 5 — Applications

- VS Code, Zen Browser, Vesktop, Nautilus.

## Phase 6 — Extra Features

- Docker, Steam, Proton GE, Tailscale.
- Gaming profile.
- Btrfs snapshots (snapper) — see **Filesystem Choice and Snapshots** above; the subvolume layout itself is decided per-host at install time (in that host's `disko.nix`), but the `snapper` service module and its `features.snapshots` toggle belong here with the rest of the optional capability modules.

## Phase 7 — Long-Term Improvements

- `nix flake check` as unified CI gate (GitHub Actions calling the same command used locally).
- Command runner (`justfile`) wrapping `switch`, `build`, `rollback`, `update`, `check`, `secrets-rekey` once these are being typed by hand often enough to be worth naming.
- Configuration polishing.
- Documentation upkeep.
- Multi-host support hardening.
- *Worth considering, not committing to yet:* NixOS's `nixosTest` framework can boot a host's config in a QEMU VM and assert on runtime behavior (does Docker actually start, does greetd actually produce a login) — a step beyond "does it build" that the current CI gate doesn't cover. Heavier to set up and run, so introduce it only if a build-only check has actually let a real regression through.
- *Worth considering, not committing to yet:* once `hosts/` has several entries, `flake.nix`'s per-host list in `nixosConfigurations` could be generated from `builtins.readDir ./hosts` instead of hand-maintained. Don't do this until adding a host to the list-by-hand has actually become repetitive — doing it earlier is exactly the kind of abstraction-before-the-pattern-repeats this project avoids.

---

# Design Principles Summary

When making changes, prefer:

- Readability over cleverness.
- One responsibility per module.
- Comments explaining *why* a setting exists, not just what it does.
- Declarative configuration over imperative steps.
- Minimal duplication — one source of truth per document, per value.
- Small, understandable commits.
- Reusable modules, reusable profiles.
- Abstractions introduced only once a pattern has already repeated.
- A single mechanism (`config.features.*`, a declared NixOS option) governing whether functionality is active — profiles set `mkDefault` values, hosts set normal-priority overrides, modules only ever read `config.features.*`.

Avoid premature abstraction, avoid duplicate sources of truth, and avoid a module needing to know which machine or profile is using it.

---

# Target Repository Structure

```
.
├── flake.nix
├── flake.lock
│
├── hosts/
│   ├── laptop/
│   │   ├── default.nix
│   │   ├── hardware-configuration.nix
│   │   ├── variables.nix
│   │   ├── features.nix
│   │   ├── disko.nix
│   │   ├── secrets.nix
│   │   └── secrets/
│   │       └── secrets.yaml
│   └── ...
│
├── profiles/
│   ├── laptop.nix
│   ├── desktop.nix
│   ├── gaming.nix
│   ├── server.nix
│   └── workstation.nix
│
├── modules/
│   ├── system/
│   ├── hardware/
│   ├── desktop/
│   ├── services/
│   └── programs/
│
├── home/
│
├── lib/
│
├── overlays/
│
├── pkgs/
│
├── scripts/
│
├── wallpapers/
│
├── assets/
│
└── docs/
```
