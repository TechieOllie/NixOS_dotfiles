# wallpapers/

**Phase:** 3 (Desktop environment). New directory, introduced alongside
Noctalia Shell's wallpaper-driven theming (`home/noctalia.nix`).

Wallpaper images for Noctalia's wallpaper picker (`home/noctalia.nix`). Read
live from this repo's own clone at `~/.dotfiles/wallpapers` on each host —
not copied into the Nix store like every other Home-Manager-owned file — so
adding a wallpaper here needs no rebuild to show up. See
[`docs/wallpapers.md`](../docs/wallpapers.md) for the day-to-day commands and
[`ARCHITECTURE.md`](../ARCHITECTURE.md)'s "Deployment Model" section for why.

Verify actual file format before adding more — a misleading extension (an
early file here was originally `.jpg` despite being real WebP data) doesn't
break anything functionally, but is worth fixing on the way in rather than
propagating.
