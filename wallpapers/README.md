# wallpapers/

**Phase:** 3 (Desktop environment). New directory, introduced alongside
Noctalia Shell's wallpaper-driven theming (`home/noctalia.nix`).

Wallpaper images referenced by Home Manager configuration, kept in the repo
rather than pointing at a path outside it so a host is reproducible from Git
alone. Currently just `SPACE.webp`. Verify actual file format before adding
more — a misleading extension (this one was originally `.jpg` despite being
real WebP data) doesn't break anything functionally, but is worth fixing on
the way in rather than propagating.

Full rationale: [`ARCHITECTURE.md`](../ARCHITECTURE.md).
