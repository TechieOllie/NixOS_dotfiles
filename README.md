# NixOS Dotfiles

A single-repository, flake-based NixOS configuration — modular and reproducible, built to grow from one machine into several without turning into an unmanageable pile of one-off config.

## Quick start

```bash
# Build a host without switching (safe way to test)
nix build .#nixosConfigurations.<host>.config.system.build.toplevel

# Build and switch to a host's configuration
nixos-rebuild switch --flake .#<host>

# Roll back (covers NixOS and integrated Home Manager together)
nixos-rebuild switch --rollback

# Bootstrap a brand-new host over SSH
nixos-anywhere --flake .#<host> root@<installer-ip>
```

## Layout

| Path | What it is |
| --- | --- |
| `flake.nix` | composition root — inputs, hosts, wiring |
| `hosts/` | one directory per machine — identity, feature overrides, disk layout |
| `profiles/` | machine roles — module bundles + default features |
| `modules/` | machine-agnostic NixOS configuration, one feature per file |
| `home/` | Home Manager (user) configuration |
| `lib/` | helper functions, introduced only once proven necessary |

Each of these has its own short `README.md` with more detail.

## Documentation

- **[ARCHITECTURE.md](./ARCHITECTURE.md)** — the design doc: why the repo is shaped this way, every convention, the full roadmap.
- **[CLAUDE.md](./CLAUDE.md)** — condensed, kept-current state for AI-assisted work: what's actually built today versus still scaffolded.
- **[docs/](./docs/)** — project-specific runbooks: how to actually bootstrap a host or manage secrets in this repo, step by step.

## Status

Early-stage personal infrastructure. See `CLAUDE.md` for which hosts are currently bootstrapped.
