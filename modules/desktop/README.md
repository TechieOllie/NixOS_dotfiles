# modules/desktop/

**Phase:** 3 (Desktop environment). New directory, introduced with `niri.nix`.

System-level halves of the desktop stack, each gated behind its own
`config.features.x` flag (see `modules/options.nix`). Where a program has both
a system half and a user half — Niri is the clearest example — only the
package, session entry, and greetd wiring live here; keybindings, layout, and
appearance live in `home/` instead. Currently `niri.nix`, `greetd.nix`,
`noctalia.nix`, and `theming.nix` (all `config.features.niri` — greetd,
Noctalia Shell, and theming packages only exist to support a graphical niri
session, and niri is the only compositor this repo offers so far; see
`greetd.nix`'s own comment if a second compositor/DE is ever added).
`theming.nix` (Theming phase) only installs cursor/icon-theme packages
system-wide, for noctalia-greeter's benefit — everything else (icon theme
selection, GTK3/Qt wiring, the cursor theme itself) is Home Manager
config, living in `home/cursor.nix`/`home/gtk.nix`/`home/qt.nix` instead,
same split as Niri's own system/user halves. `greetd.nix` wires
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

`theming.nix` was added in the Theming phase — see `CLAUDE.md` for the full
rationale (icon theme, cursor theme, GTK modernization, and why Qt
deliberately stays color-only for now).

Full rationale: [`ARCHITECTURE.md`](../../ARCHITECTURE.md).
