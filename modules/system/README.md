# modules/system/

**Phase:** 1 (Foundation).

Modules every host needs regardless of role or feature flags: `boot.nix`,
`networking.nix`, `nix.nix`, `ssh.nix`, `users.nix`. Bundled together by
`profiles/base.nix` rather than imported individually by each host.

Unlike most of `modules/`, these aren't gated behind `config.features.x` —
they're the baseline every machine boots with.

Full rationale: [`ARCHITECTURE.md`](../../ARCHITECTURE.md).
