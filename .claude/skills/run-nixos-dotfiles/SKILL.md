---
name: run-nixos-dotfiles
description: Build, evaluate, and smoke-test this NixOS flake config — the way to verify a change works before touching real/virtual hardware. Use when asked to run, build, check, evaluate, or test this repo's NixOS configs, build the installer ISO, or confirm a config change is valid.
---

This repo has no in-container app to launch: it's a Nix flake that produces
whole-machine NixOS system closures (`nixosConfigurations.the-entertaining-nios-vm`,
`...-laptop`) deployed elsewhere via `nixos-anywhere`, plus a bootstrap
installer ISO (`packages.x86_64-linux.installer-iso`). "Running" it means
evaluating and building those outputs — the same thing `nixos-rebuild
switch`/`build` and `nix flake check` do, minus actually switching a real
machine (destructive, and out of scope for anything but the real hosts).
Drive it via `.claude/skills/run-nixos-dotfiles/driver.sh`, run from the
repo root (the directory with `flake.nix`).

## Prerequisites

Nix itself, multi-user daemon install, with flakes enabled. Nothing else — no
dependency install step, no separate build tool, no globally installed
toolchain (`nix develop` provides just/nixfmt/statix/deadnix/nixd/nil/sops/age).
The flake pulls `nixpkgs`, `home-manager`, `disko`, `sops-nix`,
`noctalia-greeter`, `noctalia`, `zen-browser`, `chaotic` and `millennium` in as
flake inputs, fetched automatically.

**Do not assume Nix is present.** This repo is developed on CachyOS machines
that are *not* NixOS, so Nix is an ordinary package that may or may not be
installed on whichever machine you're on. Check before doing anything else:

```bash
command -v nix || echo "Nix is not installed — see below"
```

Installing the package is not enough. Arch's `nix` package (verified against
2.35.2-1.1 on CachyOS) ships `/nix/var` and nothing else — **it does not
create the store**, and every Nix command fails with `error: opening file
"/nix/store": No such file or directory` until someone does. Three of the four
steps below need root, so they are the operator's to run, not an agent's:

```bash
sudo pacman -S nix                          # 'nix' is in extra/ (and cachyos-extra-v3/)
sudo nix-store --init                       # creates /nix/store + /nix/var/nix/db — REQUIRED
sudo systemctl enable --now nix-daemon.socket
```

Note what is *not* here. There is no `nix-users` group on current Arch — the
package's `sysusers.d` file creates only the `nixbld` build-user group and
`nixbld01`–`nixbld10`, and the daemon socket is mode `0666`, so an ordinary
user needs no group membership and no re-login. (Older Arch packaging did use
a `nix-users` group with a `0660` socket; instructions saying to `usermod -aG
nix-users` are stale and will fail with "group does not exist".) Run
`nix-store --init` as non-root and it silently succeeds while creating
nothing, because the client just hands the request to the daemon — so verify
with `ls -d /nix/store`, not with the exit code.

Flakes are off by default and are a **client-side** setting, so enabling them
needs no root at all — write `~/.config/nix/nix.conf`:

```
experimental-features = nix-command flakes
```

The two third-party binary caches do need root, because `trusted-users` is
`root` alone by default (`nix config show | grep trusted-users`) and the
daemon discards substituters supplied by anyone else. In `/etc/nix/nix.conf`:

```
extra-substituters = https://noctalia.cachix.org https://nyx-cache.chaotic.cx
extra-trusted-public-keys = noctalia.cachix.org-1:pCOR47nnMEo5thcxNDtzWpOxNFQsBRglJzxWPp3dkU4= nyx-cache.chaotic.cx:dJxTrgMC3V3cFfyIiBQDQorG6k1LsqurH/srpMSq7qk=
```

Those lines are not optional-in-practice: a NixOS host running this flake gets
them from its own config (`modules/desktop/noctalia.nix`, chaotic's own NixOS
module), but a plain CachyOS dev box has no such config. Without them, Nix
silently falls back to building a native Wayland/OpenGL shell — and, once the
desktop is wired, a kernel — from source. Setting them at the daemon level is
the real fix; the `--extra-substituters` flags the driver passes are ignored
for non-trusted users (see Gotchas). `.github/workflows/check.yml` configures
exactly these same two lines for CI, for exactly this reason.

## Run (agent path)

```bash
cd /path/to/NixOS_dotfiles   # the repo root, next to flake.nix

# Fastest, run this first after any change: evaluates BOTH
# nixosConfigurations (vm + laptop) and the installer-iso package, no
# building. Catches option typos, missing imports, assertion failures.
.claude/skills/run-nixos-dotfiles/driver.sh check

# Eval-only for a single host (very fast: a few seconds; resolves
# .drvPath, which still evaluates the full NixOS module graph and runs
# assertions for that host, but doesn't evaluate other flake checks):
.claude/skills/run-nixos-dotfiles/driver.sh eval the-entertaining-nios-vm

# Build the bootstrap installer ISO — the one thing this repo actually
# ships as a build artifact. Opt-in, not part of `all` (see below):
.claude/skills/run-nixos-dotfiles/driver.sh iso

# check + eval (both hosts covered via `check`) — the routine, default,
# eval-only path. Deliberately does NOT build the ISO or either host's
# closure; run `iso`/`build` separately when you actually need a realized
# build, not as part of every-change verification:
.claude/skills/run-nixos-dotfiles/driver.sh all the-entertaining-nios-vm
```

Valid hosts (see `flake.nix`): `the-entertaining-nios-vm` (bootstrapped,
the actual dev/verification host) and `the-entertaining-nios-laptop`
(wired and eval-clean, not yet installed on real hardware). `the-entertaining-nios-desktop`
is scaffold-only and has no `nixosConfigurations` entry yet — don't pass it.

**Realized builds (`build`, `iso`) are opt-in, not part of `all`.** `driver.sh
build <host>` (verified for both hosts — each realizes a full
`nixos-system-<host>-*` closure, symlinked to `./result-<host>`) and
`driver.sh iso` (verified — realizes the installer ISO, symlinked to
`./result-iso`) both work, but neither runs as part of `all`: a system
closure and an ISO are both heavy to actually realize, and this repo's own
build artifacts only get built for real on an actual bootstrap
(`nixos-anywhere`) or a CI/release step, not as a routine agent smoke test.
`all` is deliberately eval-only (`check` + `eval`) — enough to catch broken
Nix (option typos, missing imports, assertion failures) for almost every
change. Reach for `build`/`iso` individually only when you specifically
need to confirm a change produces a real, realized artifact.

All subcommands exit non-zero on failure — check the exit code, the
`nix build`/`nix eval` error output is the thing to read on failure, not the
driver's own wrapper text.

**`driver.sh check` does not lint.** It runs `nix flake check --no-build`,
and the `format`/`statix`/`deadnix` checks are derivations — `--no-build`
evaluates them without realizing them, so a misformatted or dead-code'd file
sails through green here and fails in CI, which runs the full `nix flake
check`. (Confirmed empirically: a passing `check` run prints `checking
derivation checks.x86_64-linux.format... derivation evaluated to
/nix/store/…-check-format.drv` and never builds it.) Run `just fmt` before committing, and `just check` (or `nix flake
check`) when you want the same verdict CI will give. Treat `driver.sh check`
as "does the Nix still evaluate", not "is this commit-ready".

**What this does NOT do**: it never runs `nixos-rebuild switch` or
`nixos-anywhere` against any real machine — those are genuinely destructive
(they partition disks / replace the running system) and this repo's own
docs (`docs/bootstrapping-a-host.md`) already cover that path deliberately.
It also doesn't boot a VM to click around niri/Noctalia — that GUI only
renders meaningfully with real GPU accel (see `docs/decisions.md`'s notes on the
`virtio-vga-gl` libvirt setup already used for this), which nested/headless
Nix building in an arbitrary container doesn't give you. `check`/`eval` are
the correct-altitude smoke test for a config repo: they catch broken Nix
without the cost (or the false confidence — no GPU here anyway) of a full
closure build or a throwaway nested VM.

## Run (human path)

The same commands, via the repo's `justfile` (Phase 8) — `just` alone lists
every recipe. `nix develop` puts `just` on PATH; there is no `.envrc`, so
direnv does not enter the dev shell for you.

```bash
just check-fast   # nix flake check --no-build — what driver.sh check runs
just check        # the FULL gate: lints + eval + a real closure build per host
just eval <host>  # nix eval ...toplevel.drvPath
just build <host> # nix build ...toplevel
just iso          # nix build .#installer-iso
just fmt          # nix fmt
```

Note the gap between `just check-fast` and `just check`: plain `nix flake
check` builds `build-<host>` closures for both hosts as checks, so it is
genuinely expensive, while `--no-build` is lints + evaluation only. CI runs
the full one. Run the full one yourself after any `nix flake update`, since
`--no-build` never fetches and so cannot see a rotted input source.

To actually deploy (only ever do this against a real target you intend to
wipe/reinstall, never in an agent session without explicit instruction):

```bash
nixos-anywhere --flake .#the-entertaining-nios-vm root@<installer-ip>
```

## Test

There is no separate test suite — `nix flake check` (above) *is* the test
suite, and is the only command CI runs. Phase 8 wired the lints in as real
`checks` attributes, so it now covers, in one command:

- `format` — `nixfmt --check` over every hand-written `.nix` file
- `statix` — with the exclusions in `statix.toml`
- `deadnix --fail`
- evaluation of every `nixosConfigurations` attribute and `packages` derivation
- `build-<host>` — a real system closure build per host, derived from
  `self.nixosConfigurations` rather than a hand-written list, so a new host
  cannot be added without also being checked

Generated `hardware-configuration.nix` files are excluded from all three
lints (`handWrittenNix` in `flake.nix`). Add new validation as a flake check,
never as an extra CI step — and verify any new check against a deliberately
broken canary file first: a file-selection expression that silently matches
nothing passes just as green as one that works.

## Gotchas

- **`nix: command not found` is a real possibility, not a broken shell.**
  The machines this repo is developed on run CachyOS, not NixOS — Nix is
  just a package there, and at least one of them does not have it. Check
  `command -v nix` before concluding a driver failure means the config is
  wrong, and see Prerequisites. Nothing in this skill can run without it,
  and installing it needs root.
- **`error: opening file "/nix/store": No such file or directory` means Nix
  is installed but never initialized**, not that the repo is broken. Arch's
  package creates `/nix/var` only; the store and DB come from `sudo
  nix-store --init`. Equally, `experimental Nix feature 'nix-command' is
  disabled` is a missing `~/.config/nix/nix.conf`, not a flake error. Both
  are Prerequisites problems — don't debug the config until `nix flake
  metadata` succeeds.
- **`warning: ignoring the client-specified setting 'trusted-public-keys',
  because it is a restricted setting and you are not a trusted user`** (the
  wording Nix 2.35 emits; older versions said `ignoring untrusted
  substituter '<url>'`) — expected on a multi-user Nix daemon
  install where your user isn't in `trusted-users` (only `root` is, by
  default — check with `nix config show | grep trusted-users`). The driver
  passes `--extra-substituters`/`--extra-trusted-public-keys` for the
  Noctalia and chaotic-nyx caches, but the Nix daemon silently ignores
  client-supplied substituters from non-trusted users, so those flags are a
  best-effort courtesy, not the mechanism. On a machine that already has
  these paths cached it's no-op noise. On a cold machine it means Nix
  builds Noctalia from source (`flake.nix` estimates ~20 minutes) rather
  than failing outright — still correct, just slow. The real fix is
  daemon-level config, not a driver flag: put both substituters in
  `/etc/nix/nix.conf` as shown under Prerequisites (needs root).
- **chaotic-nyx's cache only becomes load-bearing once the desktop is
  wired.** `chaotic` and `millennium` reach only hosts importing
  `profiles/gaming.nix`, which today is `the-entertaining-nios-desktop`
  alone — and that host has no `nixosConfigurations` entry, so neither
  input is in anything `check`/`build` can currently reach. The driver and
  CI pass `nyx-cache.chaotic.cx` anyway, so that the day the desktop gets a
  flake entry, nobody discovers the omission by compiling a kernel.
- **`nix build .../toplevel` never touches real hardware or actually
  switches anything** — it only realizes the closure in the local Nix
  store and symlinks it to `./result-<host>`; nothing is activated. This
  is deliberate and exactly what you want for verifying a change — don't
  chain `nixos-rebuild switch` onto this without a real target host in
  mind.
- **`result*` is already gitignored** (`.gitignore`: `result`, `result-*`)
  — the driver's output symlinks (`result-<host>`, `result-iso`) never
  need manual cleanup before a commit.
- **Don't build `the-entertaining-nios-desktop`** — it has no
  `hardware-configuration.nix`/`secrets.nix`/`flake.nix` entry yet
  (scaffold-only per `CLAUDE.md`); there's no `nixosConfigurations.the-entertaining-nios-desktop`
  to build against at all yet.

## Troubleshooting

- **`nix build .#installer-iso` reports it needs to build 0 derivations and
  finishes in ~1s**: not a bug — that exact ISO derivation is already in
  the local store from a previous build. Trust it; a store-path hit is
  byte-identical to a fresh build of the same inputs. Delete `./result-iso`
  and rerun only if you specifically need to confirm the fresh build path.
- **A green `driver.sh check` is not verification of behaviour.** Every
  phase of this repo has produced bugs that only surfaced when an app was
  actually opened on the VM. Eval catches broken Nix — option typos,
  missing imports, failed assertions — and nothing about whether the
  resulting desktop works. Confirm live on the VM before calling a change
  done; `CLAUDE.md`'s "Standing gotchas" lists the traps that pass eval
  cleanly.
