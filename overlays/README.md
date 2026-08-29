# overlays/

Package fixes this repo needs and nixpkgs doesn't (yet) have.

An overlay belongs here only when the packaged program is **wrong**, not
when this repo merely wants it configured differently — configuration is
what `modules/` and `home/` are for. Each file is a bare
`final: prev: { ... }` and is imported by the one module that consumes the
package, via `nixpkgs.overlays`, rather than being applied globally in
`flake.nix`: an overlay that only reaches the hosts that need it can't
silently change a closure somewhere else.

Every overlay here should say, in its own header, what the *symptom* was.
These fix bugs that eval and a full `nix build` both report as success —
that is generally why they need an overlay rather than an option — so the
next person's only route back to the cause is the write-up.

`nix flake check` builds each host's closure, so an overlay that fails to
apply is caught. An overlay that applies and does nothing useful is not;
verify against the built package by hand.
