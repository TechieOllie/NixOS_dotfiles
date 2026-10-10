# modules/system/

**Phase:** 1 (Foundation).

Modules every host needs regardless of role or feature flags: `boot.nix`,
`networking.nix`, `nix.nix`, `ssh.nix`, `users.nix`, `shell.nix`, `fonts.nix`,
`nix-ld.nix`, `unfree.nix`, `firmware.nix` (fwupd), `disk-health.nix` (smartd,
plus a monthly btrfs scrub of `/` on any host whose root is btrfs). Bundled together by `profiles/base.nix` rather
than imported individually by each host.

Unlike most of `modules/`, these aren't gated behind `config.features.x` —
they're the baseline every machine boots with. The one host-level opt-out is
the VM's `services.smartd.enable = false`: smartd fails its unit when it
finds no SMART-capable disk, and a virtio disk has none.

`unfree.nix` (the `nixpkgs.config.allowUnfreePredicate` allow-list) moved
here from `modules/desktop/` in Phase 7. It had been gated on
`config.features.niri` on the reasoning that every unfree package in the
repo was a GUI app, which stopped being true the moment a gaming host wanted
Steam without a compositor — and the failure mode was an eval error pointing
at nixpkgs rather than at the gate. An allow-list entry costs nothing on a
host that never evaluates the package it names, so it's ungated now.

Full rationale: [`ARCHITECTURE.md`](../../ARCHITECTURE.md).
