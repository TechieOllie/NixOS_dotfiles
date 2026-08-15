# modules/hardware/

**Phase:** 7 (Extra Features). New directory, introduced with
`controllers.nix`.

Modules for *classes* of hardware a machine may or may not have — always
gated on a feature flag, never on a hostname. Hardware that is specific to
one machine does **not** belong here: the VM's `spice-vdagentd`, the
desktop's CachyOS kernel and its `lact` GPU control all live directly in
that host's own `default.nix`, because they describe one particular machine
rather than a capability another host could opt into.

Currently just `controllers.nix` (`config.features.gaming`): the `xone` and
`xpadneo` out-of-tree kernel modules for wired/dongle and Bluetooth Xbox
controllers respectively. Being out-of-tree kernel modules is exactly why
they're here and not in `home/` — they build against the running kernel, and
are the part of the gaming stack most likely to break on a kernel bump.

`audio.nix` and `graphics.nix` were once planned for this directory and are
not needed: PipeWire arrives with
`programs.noctalia.recommendedServices.enable`, and AMD graphics need
nothing declared beyond `hardware.graphics.enable32Bit` (set by
`modules/programs/steam.nix`, since it's the gaming stack that needs it).

Full rationale: [`ARCHITECTURE.md`](../../ARCHITECTURE.md).
