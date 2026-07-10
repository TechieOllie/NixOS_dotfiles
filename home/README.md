# home/

**Phase:** 1 (Foundation) for the wiring, Phase 3 (Desktop Environment)
onward for actual content.

Home Manager configuration — the user's personal environment, as opposed to
`modules/`, which is the machine's. `default.nix` is a single,
machine-agnostic entry point imported by every host through `lib/mkHost.nix`
— there's no per-host Home Manager entry point, since every host shares the
same user today.

Reads NixOS's `config.features.*` via the `osConfig` special arg (Home
Manager doesn't see NixOS `config` directly). For anything split between a
system half and a user half (Niri is the canonical example), the user half —
keybindings, layout, appearance — belongs here; the system half belongs in
`modules/desktop/`.

Full rationale: [`ARCHITECTURE.md`](../ARCHITECTURE.md).
