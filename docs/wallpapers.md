# Wallpapers

How Noctalia's wallpaper picker finds this repo's `wallpapers/` directory.
For why this is read live instead of going through the Nix store like every
other Home-Manager-owned file, see `ARCHITECTURE.md`'s "Deployment Model"
section.

## The convention

`home/noctalia.nix` sets `wallpaper.directory` to the plain path
`/home/<user>/.dotfiles/wallpapers` — not a Nix path into this repo. For
that to resolve, this repo must be cloned to `~/.dotfiles` on every host
that imports `home/noctalia.nix` (i.e. every host with `features.niri =
true`).

## Onboarding a new host

Clone the repo to the expected path:

```bash
git clone git@github.com:TechieOllie/NixOS_dotfiles.git ~/.dotfiles
```

This is a manual, one-time step per host — not run by Nix or by
`nixos-anywhere` — deliberately, since automating a git clone of the same
repo that's building the host would be circular. Do it once during or
right after bootstrapping.

## Adding a wallpaper

```bash
cp ~/Pictures/some-new-wallpaper.jpg ~/.dotfiles/wallpapers/
```

Shows up immediately in Noctalia's wallpaper picker — no `nixos-rebuild
switch` needed, since the directory is read live rather than copied into
the Nix store at build time. Commit and push the new file from
`~/.dotfiles` (or from wherever else you normally work on this repo) the
same as any other change, so it's backed up and available when cloning
onto future hosts.

## Keeping a host's clone up to date

```bash
cd ~/.dotfiles && git pull
```

Not automated — if a host's `~/.dotfiles/wallpapers` falls behind
`origin/main`, Noctalia just shows a shorter/stale list until the next
manual pull. This has no effect on system configuration itself, since
`nixos-rebuild` always evaluates whatever `flake.nix` is invoked from
directly, not this clone.
