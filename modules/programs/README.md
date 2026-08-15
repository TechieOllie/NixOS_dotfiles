# modules/programs/

**Phase:** 7 (Extra Features). New directory, introduced with `steam.nix`.

System-level program modules: applications that need real NixOS-level
configuration rather than a package in `home.packages`. Most applications in
this repo need no module at all — they live in `home/` — so the bar for a
file landing here is that NixOS itself has to configure something (a
`programs.*` module, a firewall hole, a driver).

Currently just `steam.nix` (`config.features.gaming`): Steam patched by
Millennium, running games under `proton-cachyos`, plus 32-bit graphics
support and Steam's own firewall ports. It's here rather than in `home/`
because all of that is NixOS-side; the user-level half of the same feature —
Heroic and umu-launcher — lives in `home/heroic.nix`, the same split
`modules/desktop/niri.nix` draws against `home/niri.nix`.

`steam.nix` imports two flake inputs itself (`chaotic` for `proton-cachyos`,
`millennium` for the patched Steam), rather than having them imported
unconditionally in `lib/mkHost.nix` — a host that isn't a gaming host carries
neither. Both are pinned *without* `inputs.nixpkgs.follows`, deliberately: see
the comments on those inputs in `flake.nix`.

Full rationale: [`ARCHITECTURE.md`](../../ARCHITECTURE.md).
