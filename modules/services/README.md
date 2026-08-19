# modules/services/

**Phase:** 7 (Extra Features), except `snapper.nix`, which landed early —
pulled forward once the desktop and laptop hosts were scaffolded with btrfs
and needed snapshot support alongside them.

Optional background services, each gated behind its own `config.features.x`
flag (see `modules/options.nix`):

- `snapper.nix` (`features.snapshots`) — file-level recovery via the
  `snapper` CLI, deliberately not wired into the bootloader.
- `docker.nix` (`features.docker`) — Docker Engine plus the Compose CLI
  plugin, socket-activated rather than started at boot. Note that the
  `docker` group it puts the operator in is root-equivalent by design; that
  is why this is a flag rather than something `base.nix` turns on.
- `tailscale.nix` (`features.tailscale`) — the daemon only. Joining a
  tailnet is an interactive step per machine and its state lives outside
  this repo, so a rebuilt host is *ready* to join, not joined.
- `printing.nix` (`features.printing`) — CUPS with driverless IPP plus
  Avahi/mDNS discovery. Vendor driver packages are deliberately not
  guessed at in advance.
- `moonshine.nix` (`features.moonshine`) — a headless Moonlight-compatible
  streaming server. Desktop only: it needs the GPU and the game library.
  Streams a full niri desktop, Steam Big Picture and a remote poweroff, each
  inside its own isolated compositor. Reachable over the tailnet only — the
  GameStream ports are deliberately not opened to the LAN.

The first four are enabled on the laptop and desktop; `moonshine.nix` is on
the desktop alone, and the VM deliberately runs none of them.

Full rationale: [`ARCHITECTURE.md`](../../ARCHITECTURE.md).
