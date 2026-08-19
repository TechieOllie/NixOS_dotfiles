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

# Bootstrap a brand-new host over SSH
nixos-anywhere --flake .#<host> root@<installer-ip>
```

## Hosts

| Host | State | Notes |
| --- | --- | --- |
| `the-entertaining-nios-vm` | bootstrapped, verified live | ext4. The development and verification target — disposable, driven entirely over SSH ([`docs/testing-on-the-vm.md`](./docs/testing-on-the-vm.md)). |
| `the-entertaining-nios-desktop` | wired and eval-clean, not installed | btrfs + swap. The machine this repo is developed on, still running CachyOS. The only gaming host, and carries the full niri desktop stack. |
| `the-entertaining-nios-laptop` | wired and eval-clean, not installed | btrfs + swap. Intel. No desktop stack yet, by choice. |

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
| `modules/` | machine-agnostic NixOS configuration, one feature per file |
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

Early-stage personal infrastructure. The VM is bootstrapped and is where every
change is verified; both real machines are fully wired and evaluate clean but
have not been installed yet. See `CLAUDE.md` for the current detail.
