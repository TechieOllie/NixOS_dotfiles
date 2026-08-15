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
foundation (boot/nix/networking/users/ssh/shell/fonts/nix-ld/unfree) every
host needs regardless of role, not a role itself.

**Every host imports `base.nix` directly, and role profiles never import it.**
A role profile describes only what sits *on top of* the baseline. This keeps
every host's `default.nix` reading the same way — you can see that a machine
has a bootloader without opening a profile to find out — and stops future
profiles from each having to decide whether they include base. It is not in
tension with "don't duplicate `base.nix`": the rule there is that a profile
must never restate base's module list, and declining to mention base is not
restating it.

`gaming.nix` is the first actual role profile, added in Phase 7 for the
desktop: it pulls in
`modules/programs/steam.nix` and `modules/hardware/controllers.nix`, and sets
`features.gaming = lib.mkDefault true`. Note what it deliberately does *not*
contain — the desktop's CachyOS kernel and `lact` GPU control sit in that
host's own `default.nix`, since they describe one machine's hardware rather
than the role. Further role profiles (`desktop.nix`, `server.nix`, ...) should
follow the same shape, and only get introduced once an actual role diverges
enough to need one, not preemptively.

Full rationale: [`ARCHITECTURE.md`](../ARCHITECTURE.md).
