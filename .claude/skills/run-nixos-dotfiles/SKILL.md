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

Nix itself, multi-user daemon install (already the case on the dev machine
this was authored on — `nix (Nix) 2.34.8`, `/nix/var/nix/profiles/default/bin/nix`
on the PATH). Nothing else — no dependency install step, no separate build
tool. Confirmed working on plain CachyOS (not NixOS) with just Nix installed;
the flake itself pulls in `nixpkgs`, `home-manager`, `disko`, `sops-nix`,
`noctalia-greeter`, `noctalia` as flake inputs, fetched automatically.

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

Identical commands, without the wrapper — this repo has no human-only path
that differs:

```bash
nix flake check --no-build
nix build .#nixosConfigurations.the-entertaining-nios-vm.config.system.build.toplevel
nix build .#installer-iso
```

To actually deploy (only ever do this against a real target you intend to
wipe/reinstall, never in an agent session without explicit instruction):

```bash
nixos-anywhere --flake .#the-entertaining-nios-vm root@<installer-ip>
```

## Test

There is no separate test suite — `nix flake check` (above) *is* the test
suite for this repo (it evaluates every `nixosConfigurations` attribute and
every `packages` derivation). `CLAUDE.md` notes that formatting/statix/
deadnix checks aren't wired into a `checks` attribute yet (Phase 8, not
done) — `nix flake check` still works today and already catches real eval
errors, it's just not yet the single CI gate the roadmap wants it to become.

## Gotchas

- **`warning: ignoring untrusted substituter 'https://noctalia.cachix.org',
  you are not a trusted user`** — expected, harmless noise on a
  multi-user Nix daemon install where your user isn't in `trusted-users`
  (only `root` is, by default — confirmed via `nix show-config | grep
  trusted-users`). The driver passes `--extra-substituters`/
  `--extra-trusted-public-keys` for Noctalia's Cachix cache (the exact
  values live in `modules/desktop/noctalia.nix`), but the Nix daemon
  silently ignores client-supplied substituters from non-trusted users. On
  a machine that already has these paths built/cached (true for the dev
  machine this was authored on — everything built in 1-14 seconds, nothing
  needed re-building), this is a no-op warning. On a genuinely cold
  machine it means Nix will build Noctalia from source instead of pulling
  the binary (`flake.nix`'s own comment estimates ~20 minutes) rather than
  failing outright — still correct, just slow. Real fix for a fresh CI/dev
  box: add `noctalia.cachix.org` to `trusted-substituters` (or add your
  user to `trusted-users`) in `/etc/nix/nix.conf` (needs root), or accept
  the one-time from-source build.
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
  finishes in ~1s**: not a bug — it means that exact ISO derivation is
  already in the local store from a previous build (there's already a
  top-level `result` symlink in this repo from prior work). Delete
  `./result-iso` and rerun if you specifically need to confirm a *fresh*
  build path works, or just trust the cached result — content-addressed
  store paths mean a cache hit is byte-identical to a fresh build of the
  same inputs.
