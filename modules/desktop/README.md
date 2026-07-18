# modules/desktop/

**Phase:** 3 (Desktop environment). New directory, introduced with `niri.nix`.

System-level halves of the desktop stack, each gated behind its own
`config.features.x` flag (see `modules/options.nix`). Where a program has both
a system half and a user half — Niri is the clearest example — only the
package, session entry, and greetd wiring live here; keybindings, layout, and
appearance live in `home/` instead. Currently `niri.nix` and `greetd.nix`
(both `config.features.niri` — greetd only exists to launch a graphical
session, and niri is the only one this repo offers so far; see `greetd.nix`'s
own comment if a second compositor/DE is ever added). `greetd.nix` wires
[noctalia-greeter](https://github.com/noctalia-dev/noctalia-greeter) (a flake
input) rather than hand-configuring `services.greetd` directly — its NixOS
module does that itself. `greetd.nix` imports that module directly (`lib/mkHost.nix`
only threads the flake input through `specialArgs`), so only hosts that
actually import `greetd.nix` carry it — unlike disko/sops-nix, which every
host needs and which `mkHost` does import unconditionally. Future additions:
`portals.nix`, `stylix.nix`.

Full rationale: [`ARCHITECTURE.md`](../../ARCHITECTURE.md).
