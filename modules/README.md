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
- `hardware/`, `desktop/`, `programs/` — not created yet; added as Phase 3+
  brings in graphics/Bluetooth, the desktop environment, and applications.

For anything split between system and user config (Niri is the canonical
example), the system half lives here; the user half lives in `home/`.

Full rationale: [`NixOS-Configuration-Guide.md`](../NixOS-Configuration-Guide.md).
