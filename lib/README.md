# lib/

**Phase:** 1 (Foundation), though the guiding rule is to introduce a helper
only once the same pattern has already been hand-written at least twice
across real hosts — not preemptively.

`mkHost.nix` is a deliberate, explicitly-requested exception to that rule:
it was extracted while only one host had a `nixosConfigurations` entry,
because the desktop and laptop hosts' imminent bootstrap made the
duplication a near-certainty rather than a hypothetical. Treat that as a
one-off, not a precedent — future helpers here (`mkUser.nix`, ...) should
still wait for the pattern to actually repeat.

Full rationale: [`NixOS-Configuration-Guide.md`](../NixOS-Configuration-Guide.md).
