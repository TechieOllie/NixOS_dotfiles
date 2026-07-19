# Live dotfiles (`~/.dotfiles`)

Some Home-Manager-owned files are symlinked directly to this repo's own
clone at `~/.dotfiles` instead of being copied into the Nix store — see
`ARCHITECTURE.md`'s "Deployment Model" section for why. This is the
day-to-day guide for hosts and files that use that mechanism.

## Onboarding a new host

Clone the repo to the expected path — required on every host that imports
`home/niri.nix` or `home/noctalia.nix`:

```bash
git clone git@github.com:TechieOllie/NixOS_dotfiles.git ~/.dotfiles
```

Manual, one-time, not run by Nix or `nixos-anywhere` — automating a git
clone of the same repo that's building the host would be circular. Do it
once during or right after bootstrapping.

## Keeping a host's clone up to date

```bash
cd ~/.dotfiles && git pull
```

Not automated. If a host's clone falls behind `origin/main`, whatever
reads from it (Noctalia's wallpaper picker, niri's config on next reload)
just sees stale content until the next manual pull. This has no effect on
system configuration itself — `nixos-rebuild` always evaluates whatever
flake checkout it's invoked from, never this clone.

## What's currently live vs. store-copied

- **Live** (edit `~/.dotfiles/...` directly, no rebuild needed):
  - `wallpapers/` — Noctalia's wallpaper picker (`home/noctalia.nix`).
  - `home/niri/config.kdl` and the static `home/niri/cfg/*.kdl` files
    (`animation`, `display`, `keybinds`, `layout`, `misc`, `rules`) —
    niri's config (`home/niri.nix`). Reload niri (`Mod+Shift+/` or
    restart the compositor) to pick up a change; no `nixos-rebuild
    switch`. There is no `cfg/autostart.kdl` — this repo autostarts
    applications as systemd user services bound to
    `graphical-session.target` (see `home/niri.nix`'s comment on the
    convention) rather than niri's `spawn-sh-at-startup`.
- **Still store-copied** (needs a rebuild to take effect): anything
  generated with Nix-side logic that can't be a static file —
  `home/niri/cfg/input.kdl` (per-host XKB layout lookup) is the one
  example today.

## Adding a new live file

1. Add the file under this repo (e.g. `home/niri/cfg/whatever.kdl`).
2. Point Home Manager at it via `config.lib.file.mkOutOfStoreSymlink` to
   the file's path under `~/.dotfiles`, following the `mkLiveFile` helper
   already defined in `home/niri.nix` — add a matching helper in whatever
   module owns the new file rather than reusing niri's directly.
3. Commit and push as normal. Existing hosts pick up the new file on
   their next `git pull` in `~/.dotfiles`; no rebuild needed for the
   file's *content*, though the Home Manager generation that wires up the
   symlink itself still needs one `nixos-rebuild switch` the first time.

Only do this for files that are genuinely static (no per-host Nix
templating) and either large or edited often — see `ARCHITECTURE.md` for
the full reasoning on when this is worth it versus the simpler default.
