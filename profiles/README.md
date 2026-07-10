# profiles/

**Phase:** 2 (Profiles).

A profile describes a machine **role**, not a specific machine. It does
exactly two things:

1. Imports the modules that role always needs.
2. Sets that role's default `features.*` values with `lib.mkDefault`, so a
   host can still override them.

A module never checks "which profile am I in" — it only ever reads
`config.features.x`. Profiles are a convenience bundle of imports + sensible
defaults, never a second source of truth.

`base.nix` is the one exception to "a profile is a role": it's the universal
foundation (boot/nix/networking/users/ssh) every host needs regardless of
role, not a role itself. Future role-specific profiles (`desktop.nix`,
`server.nix`, ...) should import `base.nix` rather than duplicate it — and
only get introduced once an actual role diverges enough to need one, not
preemptively.

Full rationale: [`ARCHITECTURE.md`](../ARCHITECTURE.md).
