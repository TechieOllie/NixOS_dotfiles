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

### That SSH URL does not work yet on a freshly bootstrapped host

The command above assumes the host's key is already registered on GitHub,
and on a brand-new host it is not. `secrets.nix` provisions the private half
(`~/.ssh/id_ed25519` → `/run/secrets/ssh-private-key`) during the install,
but putting the *public* half on the GitHub account is a manual, GitHub-side
step that nothing in this repo performs. Until it's done, the clone fails
with:

```
git@github.com: Permission denied (publickey).
```

which is easy to misread as a broken sops deployment. It isn't — check
`ssh -T git@github.com` before suspecting the key itself.

Register the key, then clone as documented above:

```bash
ssh-keygen -y -f ~/.ssh/id_ed25519    # on the host; paste into GitHub → Settings → SSH keys
```

Note `gh ssh-key add` needs the `admin:public_key` scope, which a default
`gh auth login` token does not carry — so this is usually a browser step,
not a CLI one.

If you'd rather have the host usable before dealing with GitHub, the repo is
public, so HTTPS clones and pulls work with no credentials at all:

```bash
git clone https://github.com/TechieOllie/NixOS_dotfiles.git ~/.dotfiles
```

That is enough for everything `~/.dotfiles` is actually read for — wallpapers
and niri's KDL are read-only from the host's point of view. Switch the remote
once the key is registered, so the host can push too:

```bash
git -C ~/.dotfiles remote set-url origin git@github.com:TechieOllie/NixOS_dotfiles.git
```

The same gap applies to the `neovim_dotfiles` clone at the bottom of this
document; it uses an SSH URL for the same reason and fails the same way.

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
    niri's config (`home/niri.nix`). niri watches its config file and
    reloads on save, so a change takes effect immediately — no keybind and
    no `nixos-rebuild switch`. (`niri msg action load-config-file` forces
    it, which is useful when editing the clone over SSH.) There is no `cfg/autostart.kdl` — this repo autostarts
    applications as systemd user services bound to
    `graphical-session.target` (see `home/niri.nix`'s comment on the
    convention) rather than niri's `spawn-sh-at-startup`.
- **Still store-copied** (needs a rebuild to take effect): everything else,
  which is the default — including static assets like
  `home/noctalia-templates/*.tmpl` and `home/vesktop-{config,assets}/*`.
  The only file that *couldn't* be live even if wanted is
  `home/niri/cfg/input.kdl`, which is generated with Nix-side logic (the
  per-host XKB layout lookup) rather than being a static file at all.

## Checking whether a file is actually live

**`ls -l` will tell you it isn't, and `ls -l` is wrong.** A live file's
symlink goes through the store on its way out of it, in three hops:

```
~/.config/niri/cfg/keybinds.kdl
  → /nix/store/…-home-manager-files/.config/niri/cfg/keybinds.kdl
    → /nix/store/…-hm_keybinds.kdl        # itself a symlink, not a copy
      → /home/ol/.dotfiles/home/niri/cfg/keybinds.kdl
```

`mkOutOfStoreSymlink` puts a *symlink* in the store rather than the file's
contents, so the first hop of a live file and the first hop of a
store-copied one look identical. Follow the whole chain instead:

```bash
readlink -f ~/.config/niri/cfg/keybinds.kdl   # ends in ~/.dotfiles → live
```

The end-to-end check, when the link chain still isn't convincing, is to
write through it:

```bash
echo "// probe" >> ~/.dotfiles/home/niri/cfg/keybinds.kdl
tail -1 ~/.config/niri/cfg/keybinds.kdl       # shows the probe → live
git -C ~/.dotfiles checkout -- home/niri/cfg/keybinds.kdl
```

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

## A different case: Neovim's config isn't part of this mechanism at all

`~/.config/nvim` is an ordinary git checkout of a separate repo,
`github:TechieOllie/neovim_dotfiles` (its own lazy.nvim + Mason setup,
not this flake) — not an out-of-store symlink, not Nix-managed in any
way. `home/neovim.nix` only installs the base toolchain that config
needs but can't provide for itself: the `neovim` binary, plus
`gnumake`/`gcc`/`tree-sitter` (plugin native builds and parser
compilation), `ripgrep` (Telescope), and Mason's own installer
prerequisites (`python3`, `unzip`, `nodejs`, `go`, `php`). `git` and
`yazi` are needed too (lazy.nvim's bootstrap clone, `yazi.nvim`) but are
deliberately *not* listed there — both already come from their own
dedicated modules (`home/git.nix`, `home/yazi.nix`), so they're not
duplicated in `home/neovim.nix`. Clone the config repo directly on any
host that wants Neovim configured:

```bash
git clone git@github.com:TechieOllie/neovim_dotfiles.git ~/.config/nvim
```

Same "manual, one-time, per host" shape as the `~/.dotfiles` clone above,
but a genuinely different mechanism — there's no "repo A managing repo
B's content" relationship here, just a second, unrelated repo living at
its own path. Keeping it up to date is `git pull` inside `~/.config/nvim`
itself, same as any other git-cloned dotfiles setup, whether on this
NixOS host or anywhere else.

Two practical notes, both hit when the desktop was onboarded:

- It needs the host's GitHub key registered, exactly like the `~/.dotfiles`
  clone — see "That SSH URL does not work yet on a freshly bootstrapped
  host" above. `neovim_dotfiles` is public too, so the same HTTPS fallback
  applies.
- **`~/.config/nvim` is usually not empty by the time you get there, and
  `git clone` refuses a non-empty target.** Noctalia's template engine
  writes `lua/matugen.lua` (the base16 palette the config reads) as soon as
  a wallpaper is set, which can easily happen before you clone. That file is
  *supposed* to be there — `neovim_dotfiles`' own `.gitignore` lists
  `lua/matugen.lua`, since it's regenerated on every wallpaper change — so
  preserve it rather than deleting it:

  ```bash
  git clone git@github.com:TechieOllie/neovim_dotfiles.git ~/.config/nvim.new
  cp -p ~/.config/nvim/lua/matugen.lua ~/.config/nvim.new/lua/   # if present
  mv ~/.config/nvim ~/.config/nvim.old && mv ~/.config/nvim.new ~/.config/nvim
  ```

  Then `nvim --headless "+Lazy! sync" +qa` to bootstrap lazy.nvim before
  first interactive use, and remove `~/.config/nvim.old` once satisfied.
