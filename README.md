# NixOS Dotfiles

A single-repository, flake-based NixOS configuration — modular and reproducible, built to grow from one machine into several without turning into an unmanageable pile of one-off config. Home Manager is integrated into the system closure, so one `nixos-rebuild switch` applies both halves and one rollback undoes them together.

## Quick start

There is a `justfile` wrapping all of these — run `just` to list the recipes,
and `nix develop` for the toolchain (just, nixfmt, statix, deadnix, nixd, nil,
sops, age) without installing anything globally.

```bash
# Validate everything: formatting, lints, every host's evaluation *and* its
# closure build. This is exactly what CI runs.
nix flake check
# The fast subset — same checks, no closure builds.
nix flake check --no-build

# Format every hand-written .nix file in place (RFC 166)
nix fmt

# Build a host without switching (safe way to test)
nix build .#nixosConfigurations.<host>.config.system.build.toplevel
# Build the installer ISO
nix build .#installer-iso

# Build and switch to a host's configuration
nixos-rebuild switch --flake .#<host>

# Roll back (covers NixOS and integrated Home Manager together)
nixos-rebuild switch --rollback

# Bootstrap a brand-new host over SSH (an encrypted host also needs its
# LUKS passphrase — see docs/bootstrapping-a-host.md, "Encrypted host")
nixos-anywhere --flake .#<host> root@<installer-ip>
```

## Hosts

| Host | State | Notes |
| --- | --- | --- |
| `the-entertaining-nios-vm` | bootstrapped, verified live | ext4. Noctalia desktop on niri. The verification target — disposable, driven entirely over SSH ([`docs/testing-on-the-vm.md`](./docs/testing-on-the-vm.md)). |
| `the-entertaining-nios-desktop` | bootstrapped, verified live | btrfs + swap. AMD Ryzen 5 5600X / RX 6600. The daily driver: Noctalia desktop on niri, gaming, Moonshine streaming. |
| `inotmac` | bootstrapped, verified live | ext4. Mid-2011 iMac shared by four people — the only GNOME host and the only multi-user one. Rebuilt from the public flake, no clone. |
| `theseus` | scaffolded, not installed, no flake entry yet | LUKS2 (TPM unlock) → LVM → btrfs + swap. Framework 13 Pro, Intel Core Ultra 5 325. Gaming and the Noctalia desktop on Umbriel; touchscreen; fingerprint for the lock screen, `sudo` and polkit. |

`hosts/installer/` is not a machine — it holds only the operator identity the
installer ISO needs. `CLAUDE.md`'s "Hosts" section is the kept-current,
authoritative version of this table; each host directory also has its own
`README.md` with what's left to do before it can be installed.

## Layout

| Path | What it is |
| --- | --- |
| `flake.nix` | composition root — inputs, hosts, wiring |
| `hosts/` | one directory per machine — identity, feature overrides, disk layout |
| `profiles/` | machine roles — module bundles + default features |
| `modules/` | machine-agnostic NixOS configuration, one feature per file. Each module turns on from a `features.*` flag a host sets — for example `features.desktop` for the Noctalia desktop, with `features.niri` or `features.umbriel` choosing its compositor |
| `home/` | Home Manager (user) configuration |
| `lib/` | helper functions, introduced only once proven necessary |
| `docs/` | runbooks and the decision log |
| `wallpapers/` | wallpaper collection, read live from a host's clone rather than the Nix store |
| `justfile` | named recipes for the commands above — thin wrappers, no logic |
| `statix.toml` | lint configuration for the `statix` flake check |

Each of these has its own short `README.md` with more detail.

## Documentation

- **[ARCHITECTURE.md](./ARCHITECTURE.md)** — the design doc: why the repo is shaped this way, every convention, the full roadmap.
- **[CLAUDE.md](./CLAUDE.md)** — condensed, kept-current state for AI-assisted work: what's actually built today versus still scaffolded, plus the gotchas that keep recurring.
- **[docs/](./docs/)** — project-specific runbooks: how to actually bootstrap a host, manage secrets, or test against the VM in this repo, step by step.
- **[docs/decisions.md](./docs/decisions.md)** — the investigation log: every non-obvious choice, what was tried first, and what was ruled out.

## Status

Personal infrastructure in daily use. The VM, the desktop and the iMac are
installed and verified live; the VM is where changes are tried first.
`theseus`, the Framework laptop, is scaffolded and waiting on its hardware. See
`CLAUDE.md` for the current detail.
