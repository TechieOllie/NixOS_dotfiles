# modules/desktop/

**Phase:** 3 (Desktop environment). New directory, introduced with `niri.nix`.

System-level halves of the desktop stack, each gated behind its own
`config.features.x` flag (see `modules/options.nix`). Where a program has both
a system half and a user half — Niri is the clearest example — only the
package, session entry, and greetd wiring live here; keybindings, layout, and
appearance live in `home/` instead. Currently `niri.nix`, `greetd.nix`, and
`noctalia.nix` (all `config.features.niri` — greetd and Noctalia Shell only
exist to support a graphical niri session, and niri is the only compositor
this repo offers so far; see `greetd.nix`'s own comment if a second
compositor/DE is ever added). `greetd.nix` wires
[noctalia-greeter](https://github.com/noctalia-dev/noctalia-greeter), and
`noctalia.nix` wires [noctalia](https://github.com/noctalia-dev/noctalia)
(Noctalia Shell v5 — a *different* flake input from noctalia-greeter, despite
the similar name) — both flake inputs, both imported by the module that
actually uses them rather than unconditionally in `lib/mkHost.nix` (which only
threads the inputs through `specialArgs`), unlike disko/sops-nix which every
host needs. `noctalia.nix` sets `programs.noctalia.recommendedServices.enable = true`
(NetworkManager, Bluetooth, UPower, power-profile) rather than wiring each
service by hand — no host in this repo has ever wanted Niri/Noctalia without
also wanting Bluetooth, so a separate `config.features.bluetooth` flag was
removed as unused complexity rather than kept "just in case." Stylix was considered and dropped —
Noctalia Shell already covers GTK/Qt/terminal/app theming natively (see
`CLAUDE.md`'s Phase 3 note); `stylix.nix` will not be created. Future
additions: `portals.nix`.

Full rationale: [`ARCHITECTURE.md`](../../ARCHITECTURE.md).
