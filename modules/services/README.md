# modules/services/

**Phase:** 6 (Extra Features) on the roadmap, but `snapper.nix` landed early —
pulled forward once the desktop and laptop hosts were scaffolded with btrfs
and needed snapshot support alongside them.

Optional background services, each gated behind its own `config.features.x`
flag (see `modules/options.nix`). Currently just `snapper.nix`
(`config.features.snapshots`) — file-level recovery via the `snapper` CLI,
deliberately not wired into the bootloader. Future additions: `tailscale.nix`,
`docker.nix`, `printing.nix`.

Full rationale: [`NixOS-Configuration-Guide.md`](../../NixOS-Configuration-Guide.md).
