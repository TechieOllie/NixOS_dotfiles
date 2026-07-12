# modules/desktop/

**Phase:** 3 (Desktop environment). New directory, introduced with `niri.nix`.

System-level halves of the desktop stack, each gated behind its own
`config.features.x` flag (see `modules/options.nix`). Where a program has both
a system half and a user half — Niri is the clearest example — only the
package, session entry, and (eventually) greetd wiring live here; keybindings,
layout, and appearance live in `home/` instead. Currently just `niri.nix`
(`config.features.niri`). Future additions: `greetd.nix`, `portals.nix`,
`stylix.nix`.

Full rationale: [`ARCHITECTURE.md`](../../ARCHITECTURE.md).
