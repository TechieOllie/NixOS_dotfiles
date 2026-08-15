# modules/

**Phase:** 1 (Foundation) onward — this directory grows through every later
phase as new features are added.

Each module configures exactly **one** feature and gates itself on
`config.features.x` via `lib.mkIf`. A module never knows which host or
profile is using it — it only reads the merged `config.features.*` value
declared in `modules/options.nix`.

Subdirectories, split by category rather than by host:

- `system/` — modules every host needs regardless of role (see its own
  README).
- `services/` — optional background services (see its own README).
- `desktop/` — system-level halves of the desktop stack (see its own README).
- `hardware/` — classes of hardware a machine may or may not have; created in
  Phase 7 for Xbox controller drivers (see its own README).
- `programs/` — system-level program modules; created in Phase 7 for Steam
  (see its own README).

For anything split between system and user config (Niri is the canonical
example), the system half lives here; the user half lives in `home/`.

Full rationale: [`ARCHITECTURE.md`](../ARCHITECTURE.md).
