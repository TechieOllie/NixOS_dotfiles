# docs/

Project-specific runbooks: how *this repo* uses a given tool, step by step —
not general tutorials. sops-nix, nixos-anywhere, and disko each have their own
upstream documentation for that; duplicating it here would just go stale.
Rationale (why a tool was chosen, why a convention exists) lives in
[`ARCHITECTURE.md`](../ARCHITECTURE.md); current build/host status lives in
[`CLAUDE.md`](../CLAUDE.md). This directory answers "what do I actually type,"
nothing more.

- [`bootstrapping-a-host.md`](./bootstrapping-a-host.md) — disko + nixos-anywhere, start to finish for a brand-new machine.
- [`secrets.md`](./secrets.md) — sops-nix day to day: adding secrets, adding a recipient, rotating a key.
- [`wallpapers.md`](./wallpapers.md) — cloning this repo to `~/.dotfiles` on a host, adding a wallpaper.
