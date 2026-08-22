# Decision and investigation log

The narrative trail behind this repo: what was tried, what broke, what was
ruled out and why. Extracted verbatim from `CLAUDE.md`, which had grown into
a session-by-session log — it now holds only current state, commands, and the
standing rules distilled from what follows here.

Three documents, three jobs:

- **`ARCHITECTURE.md`** — the design. Why the repo is shaped this way. Source of truth for architectural decisions.
- **`CLAUDE.md`** — current state, commands, and the gotchas that will bite again. Loaded into every AI session.
- **this file** — history. Read it when you need to know *why* something is the way it is, or before re-attempting something that was already tried and abandoned.

Nothing here is instruction. Where a historical finding produced a standing
rule, that rule lives in `CLAUDE.md`; this file explains how it was arrived at.

---

## Phase 1–2 — Foundation and profiles

### Why `lib/mkHost.nix` was extracted early, and how the hosts got wired

The state-of-the-repo prose as it stood when this log was split out of
`CLAUDE.md`. Kept for the reasoning it carries — notably that `mkHost` was
extracted ahead of the guide's usual trigger as a deliberate, explicitly
requested exception, not a precedent for pulling other `lib/` helpers
forward.

Phase 1 (Foundation) is done, Phase 2 (Profiles) is in progress, Phase 3 (Desktop environment) is done, Phase 4 (Terminal environment) is done (Zsh, Starship, Lazygit, Git, Ghostty, a bare Neovim package — all landed and verified live), Phase 5 (Theming) has landed and is mostly verified live on `the-entertaining-nios-vm` — cursor/icon theme/GTK3 modernization/Qt color-scheme all confirmed working (see the roadmap section below for the full writeup, the two accepted trade-offs, and two real bugs found and fixed during verification); the greeter's own cursor still needs its one-time `greeter.toml` reset (same gotcha as any other `greetd.nix` `settings` change) to actually show on an already-booted host. Phase 6 (Applications — VS Code, Zen Browser, Vesktop, Nautilus) has landed and is verified live on `the-entertaining-nios-vm` (see the dedicated Phase 6 writeup below); one small self-healing gap remains (Zen Browser's Noctalia theming needs the browser launched once to create a profile before it can apply). `flake.nix` now has two `nixosConfigurations` entries: `the-entertaining-nios-vm` (a VM, bootstrapped and verified via a full nixos-anywhere install) and `the-entertaining-nios-laptop` (fully wired and eval-clean, but **not yet installed** — see below). Both are built through `lib/mkHost.nix` (`{ system, hostPath }: nixosSystem`, wiring `disko`, `sops-nix`, `modules/options.nix`, the host itself, and `home-manager.nixosModules.home-manager`) rather than inline. `mkHost` was extracted ahead of the guide's usual "wait for a second *bootstrapped* host" trigger — bootstrapped meaning installed on real/virtual hardware via nixos-anywhere, which the laptop still isn't — because the desktop and laptop hosts' imminent bootstrap made the duplication a near-certainty rather than a hypothetical; treat this as a deliberate, explicitly-requested exception, not a precedent for extracting other `lib/` helpers early.

`the-entertaining-nios-laptop` is still running CachyOS, not NixOS yet. It now has everything nixos-anywhere needs except a resolved disk device: real `hardware-configuration.nix` (generated via `nixos-generate-config --dir`, run read-only alongside the live CachyOS install, with the scan's `fileSystems`/`swapDevices` entries dropped since `disko.nix` owns that instead), its own sops age key (`~/.config/sops/age/the-entertaining-nios-laptop.txt`, operator-held, not committed) added as a `.sops.yaml` recipient with its own `creation_rules` entry, an encrypted `secrets/secrets.yaml` (`password-hash`, hashed and encrypted by the user directly so the plaintext never touched the assistant), `secrets.nix` mirroring the VM's, and both wired into `default.nix`'s imports and into `flake.nix`'s `nixosConfigurations`. `nix eval` on its `system.build.toplevel` succeeds. The **only** thing left before an actual install is resolving the placeholder `/dev/CHANGEME` disk device in `disko.nix` (only knowable from an installer environment via `lsblk`) — and then actually running `nixos-anywhere`, which is deliberately deferred since that step wipes the target disk and the user wants to keep CachyOS bootable until the dotfiles are fully functional. `the-entertaining-nios-desktop` is still scaffold-only: no `hardware-configuration.nix`, `secrets.nix`, or `flake.nix` entry yet, since it hasn't been bootstrapped against real hardware either.

`home/` and `lib/` now exist (`overlays/`, `pkgs/` still don't — that's Phase 3+ and later). `home/default.nix` is a machine-agnostic Home Manager entry point (username/homeDirectory from `vars`, a pinned `home.stateVersion`, `programs.home-manager.enable`) imported by every host via `mkHost` — there's no per-host Home Manager entry point. It has no actual program configuration yet.

### Two fixes made incidentally while wiring in the laptop host

Fixed incidentally while wiring the laptop in: `modules/services/snapper.nix` was still using a pre-rename nixpkgs `services.snapper` option API (`subvolume`, `extraConfig` with shell-quoted strings) that current nixos-unstable rejects via assertion (`SUBVOLUME`, and per-key typed options like `ALLOW_USERS`/`TIMELINE_CREATE`/`TIMELINE_CLEANUP` instead of freeform `extraConfig`). This had gone unnoticed because no host with `features.snapshots = true` had ever actually been eval'd before — the VM (the only host with a `nixosConfigurations` entry until now) has snapshots disabled. Fixed to use the current option names/types; worth double-checking again against upstream if `nix flake update` bumps nixpkgs before the desktop host is bootstrapped too.
Fixed incidentally while attempting a remote `nixos-rebuild switch --target-host ol@<vm-ip>` against the VM: `modules/system/nix.nix` never set `nix.settings.trusted-users`, so it defaulted to `["root"]` only — a remote deploy pushing unsigned store paths in as `ol` (a non-root user) was rejected with "lacks a signature by a trusted key". Fixed by adding `trusted-users = [ vars.user.name ];` there (NixOS's own `["root"]` default merges in alongside it, so root doesn't need repeating). Lives in `profiles/base.nix`'s import chain, so it applies to all three hosts.

---

## Phase 3 — Desktop environment

### How the niri and greetd modules came about

Phase 3 (Desktop environment) has started: `modules/desktop/` now has `niri.nix` (`programs.niri.enable`, package + Wayland session entry only) and `greetd.nix`, both gated on `config.features.niri` — greetd is coupled to that same flag rather than getting its own, since it only exists to launch a graphical session and niri is the only one this repo offers so far (see `greetd.nix`'s comment on generalizing this if a second compositor/DE ever lands). `greetd.nix` enables [noctalia-greeter](https://github.com/noctalia-dev/noctalia-greeter) (`programs.noctalia-greeter.enable = true; greeter-args = "--session niri";`) rather than hand-writing `services.greetd.settings` — noctalia-greeter's own NixOS module enables and configures greetd itself, verified via `nix eval` that `config.services.greetd.enable` does end up `true` on the VM once this is set. Note: "Noctalia Greeter" is a real, separately-maintained project (`noctalia-dev/noctalia-greeter`, added as a flake input) — it is *not* the same thing as `noctalia-shell` (a Quickshell desktop-shell toolkit) that turns up first in a nixpkgs package search; don't conflate the two. Its `nixosModules.default` is *not* imported in `lib/mkHost.nix` (unlike disko/sops-nix, which every host needs) — `mkHost` only threads the flake input itself through `specialArgs`, and `greetd.nix` imports the actual module itself, so only hosts that import `greetd.nix` carry it at all. Wired into `the-entertaining-nios-vm` only (`features.niri = true` there), matching the plan to develop the desktop stack against the VM rather than the not-yet-installed laptop/desktop hosts.
`home/niri.nix` (the user half — keybindings, layout, appearance) now exists too, ported from the operator's own working CachyOS niri config rather than invented from scratch: `home/niri/config.kdl` + `home/niri/cfg/{animation,display,keybinds,layout,misc,rules}.kdl` are wired in as literal `xdg.configFile` sources (unchanged from the live config, including the `misc.kdl` `cursor { xcursor-theme "Bibata-Modern-Classic"; }` block — niri's half of the earlier cursor-theme TODO is therefore already done; greeter/GTK/Qt aren't). `home/niri/noctalia.kdl` (the v4-generated colors file) no longer exists in this repo at all — see the Noctalia v5 section below for why. Two files are Nix-generated instead of literal, since they need host-conditional logic the static KDL can't express: `cfg/input.kdl` maps `vars.system.keyMap` ("fr-pc") to an XKB layout/variant pair via a small lookup table (only one entry exists, since only one keymap value exists across all hosts so far — extend `xkbLayouts` in `home/niri.nix` if a host ever needs a different one), and `cfg/autostart.kdl` appends a `spice-vdagent` spawn line only when `osConfig.services.spice-vdagentd.enable` is true (i.e., only on the VM) — the fix for the duplicate-cursor issue described below. `cfg/animation.kdl` existed on disk in the live config but wasn't actually wired into its `config.kdl`'s includes (dead file there); wired in here since the operator confirmed it should be active. `autostart.kdl`'s spawns for `vesktop`/`zen-browser`/`obsidian`/`nautilus`/`ghostty` reference apps not yet packaged by this flake (Phase 4/5) — copied as-is per the operator's choice; they'll just no-op until those phases land. `home/niri.nix` self-gates on `osConfig.features.niri` (mirroring how system modules gate on `config.features.niri`) and is unconditionally imported from `home/default.nix`, so it's inert on hosts without Niri (verified: laptop's toplevel derivation hash is unchanged from before this file existed). Not yet verified on a live boot — the `spice-vdagent` autostart fix in particular still needs a real re-deploy + login to confirm the duplicate cursor is actually gone. **Verified on a live boot**: the VM was re-bootstrapped from scratch via `nixos-anywhere` (targeting `ol@<ip>`, since `PermitRootLogin = "no"` on the installed system — the kexec/installer environment itself only has `root`, which is expected and unrelated) to pick up this config cleanly, and the full chain — `greetd.service` active, `noctalia-greeter sessions` lists `Niri`, login actually launches `niri --session` with no crash-loop — works end to end, with an actually-rendering display confirmed (see below). A missing `xwayland-satellite` warning in niri's log is expected, not a bug — `programs.niri`'s upstream module sets `enableXWayland = false` here, no XWayland configured yet.

### SSH agent auto-unlock, the Noctalia v5 migration, and the live-dotfiles turn

**SSH agent auto-unlock** turned out to need almost nothing new. `programs.niri`'s upstream module already enables `services.gnome.gnome-keyring.enable` (for portal support), which already makes greetd's own module enable `enableGnomeKeyring` on its PAM service, and a GCR-provided `gcr-ssh-agent` systemd user unit already exports `SSH_AUTH_SOCK` session-wide — all confirmed already active on the VM before this feature was even started, with zero repo config beyond enabling Niri. The original plan (`ARCHITECTURE.md`, git history) was gpg-agent + pam_gnupg; dropped once this was discovered, since it would've been a second identity system solving an already-solved problem. What actually got added: `hosts/the-entertaining-nios-vm/secrets.nix` now provisions a **throwaway test SSH key** (not the operator's real key, which is also this repo's bootstrap key — deliberately kept off the disposable VM) via sops-nix, decrypted straight to `~/.ssh/id_ed25519` (owner `ol`, mode `0400`) rather than the usual `/run/secrets/` path. No new system or Home Manager module was needed at all. `config.features.sshAgentUnlock` was removed (from `modules/options.nix` and all three hosts) alongside `config.features.bluetooth` in the same sitting — same lesson: nothing else in the system needs to react to a separate boolean when "does this host's `secrets.nix` declare the `ssh-private-key` secret" is already the complete, sufficient signal.

Fixed and verified live: `sops-install-secrets` creates a missing parent directory itself (confirmed via its own source), but as `root:root 0755` — fine for the key file (which gets its own correct owner/mode), but leaves `~/.ssh` not owned by the user, unable to add anything else there without `sudo`. Fixed by declaring `systemd.tmpfiles.rules = [ "d /home/${vars.user.name}/.ssh 0700 ${vars.user.name} users - -" ]` in the same `secrets.nix`, so the directory already exists correctly by the time sops-install-secrets runs. Confirmed after redeploy: `~/.ssh` is `drwx------ ol users`, the secret symlinks in correctly (`id_ed25519 -> /run/secrets/ssh-private-key`, target file itself `-r-------- ol users`).

**Confirmed working across reboots, live.** One manual one-time step is needed (an ad-hoc SSH session can't reach `gcr-ssh-agent` for this — `SSH_AUTH_SOCK` is scoped to the graphical login session's own systemd user manager instance — so this genuinely requires the key to actually be used once from within, or via a socket pointed at, that session): `ssh-add ~/.ssh/id_ed25519`, entering the passphrase. After that, gnome-keyring's persistent passphrase cache survives reboots — verified by rebooting the VM, confirming `ssh-add -l` reports no *loaded* identities (that list is transient and clears on reboot, which is expected and not the relevant signal), then actually using the key for a real connection attempt, which succeeded silently with no re-prompt. The mechanism: `gcr-ssh-agent` auto-discovers keys from `~/.ssh/*` and, on an actual sign request, retrieves the passphrase from gnome-keyring (already unlocked via PAM at that boot's login) via its own internal `gcr4-ssh-askpass` helper — confirmed present in the already-installed `gcr` package, no extra package needed. `ssh-add -l` is the wrong thing to check for "did this survive reboot"; a real usage attempt is the correct test. The real laptop/desktop hosts will get the operator's actual key provisioned the same way once they're bootstrapped — not before.

**Stylix was dropped from the plan, replaced with Noctalia Shell's own native theming.** Noctalia Shell (the desktop bar/shell the operator already runs, distinct from Noctalia *Greeter*) turned out to already do everything Stylix would have: it generates a palette from the wallpaper and "renders resolved theme colors into external app config files whenever the palette changes," with official templates for GTK and Qt and community templates for VS Code/Discord/Firefox/Neovim/Steam/Zen Browser/Obsidian/Spotify/terminals. Adding Stylix on top would have meant two systems fighting over the same GTK/Qt/terminal config files. `modules/desktop/stylix.nix` (planned in `ARCHITECTURE.md`'s module tree) will not be created; treat that line in the guide as superseded.

**Noctalia v5 migration**: the operator's real config (and the `home/niri.nix` port done earlier this session) was written for **Noctalia v4**, which is Quickshell-based. **v5 is a from-scratch rewrite — not Quickshell, native Wayland+OpenGL ES, no Qt/GTK dependency, invoked as `noctalia` (not `qs -c noctalia-shell`), completely different IPC surface (`noctalia msg <command>` instead of `qs -c noctalia-shell ipc call <target> <action>`)** — and the operator chose to migrate to v5 now rather than keep the already-working v4 config. Currently v5.0.0-beta.3 (beta software) and **not yet in nixpkgs** — added as its own flake input (`noctalia`, deliberately *not* following this repo's nixpkgs, since following would disable Noctalia's Cachix binary cache and force building this native Wayland/OpenGL project from source on every host; the tradeoff accepted is a second nixpkgs copy in the closure).
- `modules/desktop/noctalia.nix` (new, gated on `config.features.niri` like `greetd.nix`): `programs.noctalia.enable`, plus the Cachix substituter/trusted key. Services (NetworkManager, Bluetooth, UPower, power-profile) are enabled via `programs.noctalia.recommendedServices.enable = true` — an earlier version of this module wired them individually specifically to avoid forcing Bluetooth on regardless of a separate `config.features.bluetooth` flag, but that flag was removed shortly after (see below) once it became clear no real or planned host actually wanted to differ from what Noctalia recommends.
- `home/noctalia.nix` (new, self-gates on `osConfig.features.niri`): `programs.noctalia.settings` (TOML) sets `theme.source = "wallpaper"` (`wallpaper_scheme = "m3-content"`, dark mode) pointing at `wallpapers/SPACE.webp` (new top-level directory, per `ARCHITECTURE.md`'s target layout — a WebP file the operator provided, originally misnamed `SPACE.jpg`). Noctalia runs as a supervised Home Manager `systemd.enable` user service (paired with `shell.launch_apps_as_systemd_services = true`) rather than a niri `spawn-sh-at-startup` line, since upstream presents the systemd route as the NixOS-idiomatic option and it gets proper restart/logging behavior.
- `lib/mkHost.nix` threads the `noctalia` flake input through both NixOS `specialArgs` and Home Manager `extraSpecialArgs` (not imported there itself — same treatment as `noctalia-greeter`: the two files that actually consume it import `noctalia.nixosModules.default`/`noctalia.homeModules.default` themselves).
- `home/niri/cfg/keybinds.kdl` and `cfg/autostart.kdl` rewritten for v5's command surface: `Mod+ALT+L` → `noctalia msg session lock`, `Mod+Shift+Q` → `noctalia msg panel-toggle session`, `Mod+V` → `noctalia msg panel-toggle clipboard`, `Mod+Shift+S` (screenshot) → `noctalia msg screenshot-region` (upgraded from a mystery standalone `screenshot` script under v4), media/volume/brightness keys → their `noctalia msg` equivalents, and two new binds the v5 niri-integration doc recommends (`Mod+S` → control-center, `Mod+Comma` → settings-toggle). Three v4 keybinds were **dropped, not ported**, because no v5 equivalent exists (confirmed via upstream docs, not guessed): the keybind-cheatsheet plugin (`Mod+F1`), the mirror-mirror screen-mirroring plugin (`Mod+P` — no screen-mirroring plugin exists among v5's official plugins at all), and the standalone calculator popup (`Mod+Shift+C` — calculator is now a launcher *provider* in v5, used by typing a math expression straight into the launcher rather than a separate toggle). `autostart.kdl` no longer spawns `qs -c noctalia-shell` (replaced by the systemd service above). `home/niri/cfg/rules.kdl` gained a new window-rule for Noctalia's own settings window (`app-id="dev.noctalia.Noctalia"`, floating); the existing wallpaper-backdrop `layer-rule` and `layout.kdl`'s `background-color "transparent"` already matched v5's recommended "stationary wallpaper" pattern exactly, so neither needed changing.
- **One gap remains, deliberately left as a TODO rather than guessed at:** `theme.templates.builtin_ids` (the actual GTK/Qt template ID strings) are genuinely undocumented anywhere upstream — discovering them requires running `noctalia theme --list-templates` on a machine with Noctalia actually built (noted in `home/noctalia.nix`).
- **Resolved and verified via live deploy**: `home/niri/noctalia.kdl` (the v4-generated niri border/focus colors) turned out to be exactly what the TODO suspected — Noctalia v5's own template engine tries to own that file at runtime, confirmed via its log: `[WRN] [template_engine] failed to open template output .../niri/noctalia.kdl`, since it was still a Nix-managed read-only store symlink at the time. Fixed by no longer managing that file in `home/niri.nix`, then deleting `home/niri/noctalia.kdl` from the repo entirely — it was v4-generated colors with no further purpose once Noctalia owns the runtime file itself. After redeploying, the warning stopped appearing and the file now contains genuinely different, wallpaper-derived colors (`#73d1ff` vs. the old v4 `#53d7f1`) written by Noctalia itself — the wallpaper-driven theming pipeline is confirmed working end to end. `home/niri/config.kdl`'s `include "./noctalia.kdl"` is unchanged — it includes whatever Noctalia writes to `~/.config/niri/noctalia.kdl` at runtime, unrelated to the now-deleted repo file of the same name.
- **Separately discovered while testing the greeter's keyboard layout**: `programs.noctalia-greeter.settings` (`greetd.nix`) only ever seeds `/var/lib/noctalia-greeter/greeter.toml` — noctalia-greeter's own NixOS module uses a systemd-tmpfiles `C`-type rule for this (`"/var/lib/noctalia-greeter/greeter.toml".C = { argument = ...; }`), which creates the file *only if it doesn't already exist* and deliberately never overwrites it afterward (so the greeter's own runtime-learned state — `[session].last`, `[appearance].scheme` — survives reboots). Practical consequence: **changing `programs.noctalia-greeter.settings` and redeploying has no effect on an already-booted host** until the stale file is removed (`sudo rm /var/lib/noctalia-greeter/greeter.toml && sudo systemd-tmpfiles --create && sudo systemctl restart greetd`) — much like the earlier `niri creates its own config.kdl` gotcha, but this one can't be fixed with a Nix-side `force = true`, since it's plain systemd-tmpfiles semantics on the greeter's own state file, not a Home Manager conflict.
- **Not yet touched**: noctalia-greeter's documented "optional sync with Noctalia Shell v5 for wallpaper, palette, and multi-monitor layout" — the greeter integration landed before this migration and hasn't been revisited to actually enable that sync.

**Wallpaper directory: live clone, not Nix-store-managed (resolved after the config-layering discovery above).** Once `wallpaper.default.path`/`last.path` were confirmed unreadable from `config.toml` (see above), the fix was to stop setting a default entirely and instead point Noctalia's wallpaper-*picker* at a directory (`wallpaper.directory`, confirmed via source to be a genuinely different, normally-read code path). The first version of this fix set `wallpaper.directory = ../wallpapers;` — a Nix path, which gets copied into the store as its own derivation the moment it's stringified into the TOML settings file (confirmed live: `config.toml` resolved to `/nix/store/...-wallpapers`). This worked, but the operator raised a real concern: with ~30 wallpaper images now in the repo, that's a second full copy of the same binary data on every host that builds this config, and adding one new wallpaper would require a full `nixos-rebuild switch` just to make it selectable. Discussed alternatives; the operator chose to drop the Nix-store approach entirely rather than accept that tradeoff, given wallpapers are large, mutable, frequently-added binary assets rather than code. Final design: `wallpaper.directory` is now a **plain string**, `/home/${vars.user.name}/.dotfiles/wallpapers`, requiring this repo to be cloned to `~/.dotfiles` on every host that imports `home/noctalia.nix` — a manual, undocumented-by-Nix step (see `docs/live-dotfiles.md`). `home/noctalia.nix` now takes `vars` as an argument (previously didn't need it). `wallpapers/SPACE.jpg` (a byte-identical duplicate of the already-committed `SPACE.webp`, both md5-verified identical, from a second copy-in of the same source image) was deleted rather than kept. **Verified live**: repo cloned onto the VM at `~/.dotfiles` (`git clone` over SSH, via `nix run nixpkgs#git` since git isn't a system package here), redeployed, and confirmed — `config.toml`'s `wallpaper.directory` resolves to `/home/ol/.dotfiles/wallpapers`, listing all 35 files, and the redeploy's `nixos-rebuild` copy step touched only 8 small config/service derivations, no wallpaper data at all (unlike the first, Nix-path version, which had copied the whole directory into the store).

**Correction to how this was framed in `ARCHITECTURE.md`**: the first version of this section described the live-clone approach as "a deliberate exception" to an "everything flows through the Nix store" rule — but no such rule actually exists anywhere in `ARCHITECTURE.md`; the only real requirement (its "Deployment Model" section) is "recoverable from Git alone," which a live symlink into this same repo's clone satisfies exactly as well as a store copy does. That framing was the assistant's own unstated assumption, called out and corrected by the operator. `ARCHITECTURE.md`'s "Deployment Model" section now describes store-copying and `config.lib.file.mkOutOfStoreSymlink` as two ordinary, equally-legitimate mechanisms for Home-Manager-owned files, chosen per file based on size/edit-frequency, not one being a rule and the other an exception to it.

**Generalized to niri's static KDL config, same session.** Once the wallpaper precedent existed (every `features.niri` host already needs `~/.dotfiles` cloned), the same `config.lib.file.mkOutOfStoreSymlink` mechanism was extended to `home/niri.nix`'s static (non-templated) files — `config.kdl` and `cfg/{animation,display,keybinds,layout,misc,rules}.kdl` — via a `mkLiveFile` helper, so editing a keybind only needs niri to reload, not `nixos-rebuild switch`. `cfg/input.kdl` (per-host XKB layout lookup) stays Nix-generated `.text`, since that logic can't live in a static file. `home/niri.nix` now takes `config` as an argument (needed for `config.lib.file.mkOutOfStoreSymlink`).

`cfg/autostart.kdl` was converted to a live file too, and lost two lines in the process, both confirmed dead via live investigation rather than assumption:
- The VM-only conditional `spice-vdagent` spawn line (gated on `osConfig.services.spice-vdagentd.enable`) — dropped at the operator's request, since converting this file to a static live-symlinked file meant it could no longer carry Nix-side conditional logic anyway, and the underlying SPICE cursor-duplication issue this was working around was already deprioritized as an unresolved VM-only cosmetic quirk (see above) — the fix never reliably worked (the spice-vdagent client's connection kept resetting).
- An unconditional `systemctl --user start niri-session.target` line, ported as-is from the operator's old CachyOS config. Investigated live rather than assumed correct, prompted by the operator asking why niri isn't launched via its own `niri-session` wrapper script — turns out it already is: niri's packaged `niri.desktop` session entry has `Exec=niri-session` (confirmed by reading the niri package's `share/wayland-sessions/niri.desktop` directly), and greetd's post-login session command is built from that `.desktop` entry, the same convention every greetd greeter follows. The real `niri-session` script already does everything needed (imports the login environment, runs `dbus-update-activation-environment`, starts `niri.service`, which itself declares `BindsTo=graphical-session.target`/`Before=graphical-session.target`) with no help required. Worse, `niri-session.target` **never existed as a real unit at all** — confirmed via `systemctl --user list-unit-files "niri*"` on the live VM, which lists only `niri.service` and `niri-shutdown.target`. Noctalia's own systemd unit (which needs `launch_apps_as_systemd_services = true` to actually start) is ordered against `graphical-session.target` directly (confirmed via `systemctl --user cat noctalia.service`), not "niri-session.target" — so the line was harmless dead code from day one, not load-bearing for anything. Dropped initially so `cfg/autostart.kdl` was left spawning only `vesktop` — then, prompted by the operator asking whether autostarted apps should instead be systemd user services bound to `graphical-session.target` (matching niri's own docs and the Noctalia precedent already in this repo), `cfg/autostart.kdl` was removed entirely (along with its `include` line in `config.kdl`), since its one remaining line (`vesktop`) was already inert — Vesktop isn't packaged by this flake yet (Phase 6) — so there was nothing left worth keeping a `spawn-sh-at-startup` mechanism around for. Recorded as a standing convention in `ARCHITECTURE.md`'s "Home Manager" section: future autostarted apps get their own `systemd.user.services.<name>` (`PartOf`/`After = "graphical-session.target"`, `WantedBy = [ "graphical-session.target" ]`) in their own Home Manager module when written, not a shared autostart file.

**`config.features.bluetooth` was removed** (from `modules/options.nix` and every host's `features.nix`) shortly after `noctalia.nix` landed, following a design discussion: the flag was declared since Phase 1 but never implemented or consumed anywhere, and `modules/desktop/noctalia.nix` initially wired Bluetooth/UPower/power-profiles individually specifically to keep it meaningful. The VM was originally cited as a reason to keep host-level control (a disposable test VM has no real use for Bluetooth), but that doesn't hold up as a real divergence case — the VM is explicitly non-representative, and both real planned hosts (laptop, desktop) want Bluetooth whenever they have a desktop environment at all. With no host, real or planned, ever wanting to decouple "has Niri/Noctalia" from "wants Bluetooth," keeping a separate flag was pure unused complexity, and hand-wiring the individual services instead of using `programs.noctalia.recommendedServices.enable` meant manually tracking what Noctalia itself considers necessary — a real, ongoing maintenance cost for no actual benefit. `modules/desktop/noctalia.nix` now just sets `programs.noctalia.recommendedServices.enable = true` (NetworkManager, Bluetooth, UPower, power-profile, all in one call). `ARCHITECTURE.md`'s module tree still lists `hardware/bluetooth.nix` as a planned module (a stale line from before this decision — nothing currently plans to create it).

Cursor-theme TODO (see comment in `modules/desktop/greetd.nix`) was partly done here: Niri's half landed as part of the ported `misc.kdl` (`xcursor-theme "Bibata-Modern-Classic"`); noctalia-greeter/GTK/Qt were still missing it. **Resolved in Phase 5 (Theming)** — see that section below for the full writeup (`home/cursor.nix`, `modules/desktop/theming.nix`, `greetd.nix`'s `settings.cursor`). Development happens against `the-entertaining-nios-vm` — kept around long-term for this purpose — rather than waiting on the desktop/laptop hosts' physical bootstrap. The GUI stack sits behind its own feature flag (`config.features.niri`, not hardcoded as the only option), so alternate WMs/DEs (e.g. GNOME) can be added later without restructuring.

**Noctalia v5's dedicated niri compositor-settings doc, cross-checked against this repo's actual config rather than assumed unimplemented.** Fetched
[docs.noctalia.dev/v5/compositor-settings/niri](https://docs.noctalia.dev/v5/compositor-settings/niri)
twice — the first fetch paraphrased code blocks, the second explicitly
asked for verbatim KDL, since this work involves exact syntax going into
a live config file. Most of the doc's recommendations were **already
correctly implemented** from the earlier v5 migration: rounded corners
(`geometry-corner-radius 20`/`clip-to-geometry true`), the
`dev.noctalia.Noctalia` settings-window floating rule, the wallpaper
"stationary" backdrop pattern (`layer-rule` + `layout { background-color
"transparent" }`), and `honor-xdg-activation-with-invalid-serial`. The
doc's `spawn-at-startup "noctalia"` autostart recommendation is
deliberately **not** followed — this repo runs Noctalia as a supervised
Home Manager systemd service instead (documented in Phase 3/4 above),
a correct divergence, not a gap.

Genuine gaps found and fixed, all in `home/niri/cfg/`:
- `keybinds.kdl`: added the missing `Alt+Tab` window-switcher bind
  (`noctalia msg window-switcher`).
- `rules.kdl`: added blur — a `window-rule` enabling `background-effect
  { blur true; xray false; }` broadly, a `layer-rule` disabling xray
  specifically on Noctalia's own surfaces (bar/notification/dock/panel/
  attached-panel/osd, matched via a regex) so they don't look
  see-through, and a third `layer-rule` enabling blur on Noctalia's
  window switcher. Confirmed this repo's pinned nixpkgs ships niri
  `26.04` exactly, meeting blur's `26.04+` requirement. The Noctalia
  surfaces regex uses this repo's existing `r#"..."#` raw-string
  convention (already used elsewhere in the same file) to embed a
  literal `"` inside `[^"]+` — the doc's own copy had a stray
  backslash-escape that isn't valid KDL, so this wasn't copied verbatim.
  Also fixed the existing wallpaper `layer-rule`'s regex
  (`"^noctalia-wallpaper*"` → `"^noctalia-wallpaper"`, dropping a stray
  trailing `*` that was harmless — `p*` still matches the real string —
  but not what upstream's own doc shows).
- `misc.kdl`: added the global `blur { passes 2; offset 3.0; noise 0.03;
  saturation 1.0; }` tuning block. Also updated the *comment* on the
  already-existing, already-commented-out lid-close `switch-events`
  block to Noctalia's current recommended command (`noctalia msg
  session lock-and-suspend`, replacing the old plain `systemctl
  suspend-then-hibernate`) — deliberately left commented out and without
  any system-level `logind.conf` change, since no bootstrapped host has
  a lid switch yet (VM only; the laptop isn't installed) — revisit once
  the laptop is actually bootstrapped with real hardware.
- **Explicitly not applied**: `niri_overview_type_to_launch_enabled` —
  despite appearing on the niri doc page, a second fetch asking for
  surrounding context confirmed this is actually a **Noctalia TOML**
  `[shell]` setting (`home/noctalia.nix`), not niri KDL at all — the
  operator asked not to activate this one, so `home/noctalia.nix` is
  untouched.

**Verified before and after deploying**: assembled the real config tree
(`config.kdl` + its `include`s) in a scratch dir, stubbing the two
includes that only exist at build/runtime (`cfg/input.kdl`, Nix-generated;
`noctalia.kdl`, Noctalia's own runtime output) and ran `niri validate`
against it — passed cleanly, including the new raw-string regex. Synced
the three changed files directly to `the-entertaining-nios-vm`'s
`~/.dotfiles` clone, confirmed the live `~/.config/niri/cfg/*.kdl`
symlinks resolve to the updated content, ran `niri validate` again
against the actual live config (also clean), then reloaded it live via
`niri msg action load-config-file` (found the running session's IPC
socket manually at `/run/user/1000/niri.wayland-1.<pid>.sock` and
exported `NIRI_SOCKET`, since an ad-hoc SSH shell has no session context
for `niri msg` to find it automatically — the same class of issue as
`gcr-ssh-agent`'s `SSH_AUTH_SOCK` scoping, Phase 3) — reloaded with zero
errors in niri's log.

### VM-only gotchas (libvirt/QEMU/virt-manager, not repo bugs)

**VM-only gotchas, not repo bugs** (libvirt/QEMU/virt-manager config, outside this repo — none of these touched Nix config beyond `services.spice-vdagentd.enable` on the VM host):
- The VM's initial libvirt domain config used the `virtio-vga` video model, which on this host's QEMU (11.0.2) has no `virgl` device property at all — niri's `backend::tty` renderer fell back to a software/display-less path (`no allocator available for device`) with a genuinely blank display, even though niri itself started cleanly with no crash. Guest-kernel `dmesg` confirmed it (`[drm] features: -virgl`, `number of cap sets: 0`). Fixed by changing the video model's `device=` attribute to `virtio-vga-gl` (checked against `/usr/share/libvirt/schemas/domaincommon.rng`'s enum: `virtio-vga`, `virtio-vga-gl`, `virtio-gpu`, `virtio-gpu-gl` are all distinct values, and only the `-gl` ones are accelerated) — `virtio-vga-gl` specifically, not plain `virtio-gpu-gl`, since the latter drops legacy VGA compatibility that OVMF's early firmware text (systemd-boot menu) needs. After the fix, guest `dmesg` showed `+virgl`, `cap sets: 2`, and niri's log showed a real connector (`Virtual-1`, `1280x800`) and successful renderer init.
- Garbled text (bootloader menu *and* niri's own UI) looked at first like a deeper virglrenderer Y-flip/compositing bug, but the actual cause was much simpler: virt-manager's **View → Scale Display was set to "Always"**, doing non-integer viewer-side scaling of the guest's framebuffer — not a guest-, QEMU-, or driver-side rendering bug at all. Setting it to **Never** resolved it completely.
- The duplicate cursor (one upside-down, one right-side-up) and the upside-down orientation are now understood to be two separate, still-open issues, **deliberately deprioritized as VM-only cosmetic quirks** — not repo bugs, and not expected to occur on real hardware (no QEMU/SPICE/virtio layer there at all):
  - Upside-down: present even at the noctalia-greeter login screen (single cursor there, no duplication), i.e. before any per-session code runs at all — points to a virtio-gpu-gl hardware-cursor-plane rendering quirk at the QEMU/virglrenderer level, unrelated to anything in this repo.
  - Duplication: only appears after logging into niri (never at the greeter). `services.spice-vdagentd.enable = true` (`hosts/the-entertaining-nios-vm/default.nix`) only starts the system daemon; a per-session `spice-vdagent` client was tried too (autostarted via a since-removed `cfg/autostart.kdl` line, gated on `osConfig.services.spice-vdagentd.enable`) — confirmed via live testing that the client did launch, but its connection to `spice-vdagentd` reset almost immediately (`Error receiving data: Connection reset by peer`), so it never stayed up long enough to take over cursor rendering. This looks like a SPICE virtio-serial channel issue at the QEMU/libvirt level, not a repo bug.
  - The `cfg/autostart.kdl` spawn line for this was later dropped entirely (Phase 4 session, see the niri live-dotfiles section below) once `autostart.kdl` itself was removed for unrelated reasons — the fix never reliably worked anyway, so nothing of value was lost. `services.spice-vdagentd.enable` itself is kept as-is (correct, reasonable system-level config either way).
  - **A third, related symptom investigated and resolved**: setting a fixed `<resolution x='1366' y='768'/>` hint on the `virtio-vga-gl` video model's libvirt XML (requested to fix the VM's display size) caused noticeable keyboard-input lag after a restart — confirmed by reverting the XML change and restarting clean, which fixed the input lag while leaving the (unrelated, pre-existing) cursor quirk exactly as before. This confirms the two are independent issues: the resolution hint specifically triggers some kind of negotiation/rendering slowdown on this QEMU/virtio-gpu-gl setup, worth avoiding — the VM's resolution is better left to niri's own output negotiation (`home/niri/cfg/display.kdl`) than a libvirt-level hint.

---

## Phase 4 — Terminal environment

**Git and Ghostty, planned via Plan mode before implementation, same as the Zsh/Starship/Lazygit work above.** Research found real existing config for both, ported rather than invented: `~/.gitconfig` (`user.name = TechieOllie`, `user.email = oliverwest06@outlook.com`, `init.defaultBranch = main`; no aliases/editor/excludesfile/color settings to port) → `home/git.nix` (`programs.git`, plus `lfs.enable = true` to auto-manage the `[filter "lfs"]` block already present rather than hand-copying it, plus `ignores` for the one-line global gitignore at `~/.config/git/ignore`). A `[safe] directory` entry scoped to a specific non-repo path was deliberately not ported (not portable/relevant). Ghostty's config was confusingly split across `~/.config/ghostty/config` (actually loaded: `font-family`, `theme = noctalia`) and `~/.config/ghostty/config.ghostty` (NOT loaded under that filename: `background-opacity = 0.90`, `shell-integration-features = ssh-env,ssh-terminfo`) — merged into the one real config in `home/ghostty.nix`, per the operator's confirmation. An old, unrelated prior NixOS repo (`TechieOllie/NixOS-Config`, superseded, last pushed 2025-04-20) had a materially different Ghostty config (different theme/font/extensive leader-key keybindings) — explicitly treated as historical only, not ported.

**Bigger discovery that changed the Ghostty design, found by reading Noctalia v5's own source (`assets/templates/builtin.toml` + per-template `apply.sh` scripts in the `noctalia` flake input) rather than assumed**: `~/.config/ghostty/themes/noctalia` — the exact theme file found during research — turned out to be Noctalia's own runtime-generated output (its `"ghostty"` template, regenerated whenever the wallpaper/palette changes), the same mechanism already handling `niri/noctalia.kdl` since Phase 3. `home/ghostty.nix` therefore manages Ghostty's real `config` file only and deliberately never touches `themes/noctalia` at all (no `programs.ghostty.themes.noctalia`); `home/noctalia.nix` gained `"ghostty"` in `theme.templates.builtin_ids` instead, so Noctalia keeps that file in sync automatically. **Verified live**: after redeploy, `~/.config/ghostty/themes/noctalia` is a plain regular file (not a Home-Manager-managed symlink, confirmed via `ls -la`) and Noctalia's log shows zero `[WRN] [template_engine] failed to open template output ...` conflicts — the exact conflict class already seen once for niri was successfully avoided here by design, not luck.

**⚠️ Known (harmless, unfixed) issue: Ghostty's first launch after a fresh boot is slow (~1.7s on the VM), every launch after that is near-instant (~30-40ms).** Investigated when the operator asked whether this was oh-my-zsh's fault — measured directly (`time zsh -i -c exit`, ~0.15-0.2s consistently), ruling that out. Root cause: `~/.cache/mesa_shader_cache` exists, and the timing signature (slow once, then consistently fast) exactly matches one-time Mesa GPU shader compilation on first use of Ghostty's OpenGL rendering path, cached to disk afterward. Confirmed happening only once per boot, not on every launch. **Deliberately left as-is, per the operator's choice** — the only real fix (autostarting Ghostty invisibly at login to pre-warm the cache before it's needed) trades this for a likely visible window-flash at login, not obviously a better trade for a one-time sub-2-second cost. Also not yet confirmed whether this reproduces on real hardware at all — the VM's GPU is virtualized (`virtio-gpu-gl`), and this repo already has a track record of VM-only rendering quirks (see the Phase 3 VM-gotchas section) that don't show up on real hardware. Revisit once the laptop/desktop are actually bootstrapped and this can be tested for real; if it turns out to matter there too, the autostart pre-warm approach above is the fix to reach for.

**Same investigation finally resolved the long-open Phase 3 TODO for GTK/Qt `builtin_ids`** — reading `builtin.toml`'s `[catalog.*]` entries directly gave the real, previously-"undocumented anywhere upstream" IDs: `gtk3`, `gtk4`, `qt`. Added to `home/noctalia.nix`'s `theme.templates.builtin_ids` alongside `"ghostty"`, confirmed with the operator. **Verified live**: `~/.config/gtk-3.0/noctalia.css`, `~/.config/gtk-4.0/noctalia.css`, `~/.config/qt5ct/colors/noctalia.conf`, and `~/.config/qt6ct/colors/noctalia.conf` all exist and were generated by Noctalia with no conflicts.

**A related conflict was found but deliberately NOT fixed this session — a latent gap, not an active bug.** The same investigation found Noctalia also has a `"starship"` template — but unlike ghostty's separate-output-file approach, it directly `sed`-edits `~/.config/starship.toml` itself (inserting a `palette = "noctalia"` line and a marked block), which would conflict with last session's Nix-managed `programs.starship.settings` symlink the same way niri's `noctalia.kdl` once did. Confirmed with the operator: **`"starship"` was deliberately left out of `builtin_ids`** — nothing currently enables this template, so `starship.toml` is not actually at risk today, but wallpaper-driven Starship theming would need `home/starship.nix`'s output converted to an out-of-store symlink first, as its own separate future session.

**JetBrains Mono Nerd Font packaged, prompted by the operator noticing `home/ghostty.nix`'s `font-family` setting had no corresponding package anywhere in this repo.** New `modules/system/fonts.nix` (`fonts.packages = [ pkgs.nerd-fonts.jetbrains-mono ];`, the current nixpkgs post-restructure attrset form, not the old monolithic `nerdfonts` package), imported from `profiles/base.nix` alongside `shell.nix`. Unconditional, no `features.*` flag — same reasoning as every other Phase 4 module: every real host that gets a terminal environment needs this, so there's no per-host axis of variation for a flag to express.

**One transient deploy hiccup, not a config problem**: the first `nixos-rebuild switch --ask-elevate-password` attempt for this change failed with `home-manager-ol.service` reporting "Existing file '/home/ol/.config/starship.toml' would be clobbered." Investigated live rather than assumed broken — the *second* immediate retry (no config changes in between) succeeded cleanly with no clobber error, and the resulting `starship.toml` was confirmed to still be the correct Home-Manager-managed symlink with the exact expected content (no Noctalia palette injection, confirming the `"starship"`-excluded-from-`builtin_ids` decision above held). Treated as a one-off home-manager-as-systemd-service activation-ordering race (concurrent `dbus-broker`/`accounts-daemon`/`polkit` restarts during the same activation), not a recurring issue — worth knowing about if a similar "would be clobbered" error appears on a future redeploy: retry once before assuming the config itself is wrong.

**Zsh/Starship/Lazygit port, planned via Plan mode before implementation** (per the operator's standing instruction to plan before anything substantial — see the two feedback memories on this). The operator has a real, actively-maintained Zsh setup: Antidote (plugin manager) + Oh-My-Zsh's `lib/` + several plugins, a Starship config, and a Lazygit config, all tracked both locally under `~/.config` and in a separate GitHub repo (`TechieOllie/shell_dotfiles`, confirmed byte-identical to the local checkout at the time of porting — that repo's existence implies it's also used on non-NixOS machines, a real trade-off discussed below). Ported rather than invented from scratch, mirroring how `home/niri.nix` was ported from the operator's live CachyOS config.
- **Antidote dropped entirely, migrated to native Home Manager mechanisms** — a real decision discussed explicitly, not a default: Antidote clones plugins from GitHub *at shell-start time*, caching to `~/.cache/antidote/`, which sits entirely outside `nixos-rebuild switch --rollback`'s "one command rolls back NixOS + Home Manager together" guarantee (a plugin update pulled by a fresh `antidote load` wouldn't be undone by a system rollback). Native Home Manager plugin management is fetched at build time instead, pinned by `flake.lock`, with no such gap. **Trade-off accepted knowingly**: `shell_dotfiles` and this repo's `home/zsh.nix` are now two independently-edited sources rather than one — a tweak in `shell_dotfiles` (for other machines) no longer automatically applies here, and vice versa. The alternative (keep Antidote, live-symlink `shell_dotfiles`' own files the same way `home/niri.nix` symlinks `~/.dotfiles`) was raised and explicitly rejected in favor of full reproducibility.
- **Two of Antidote's three "kind:defer" plugins turned out to already be built-in Home Manager options** — not previously known, discovered by reading the locked `home-manager` module source directly (rev `1aac8895`): `programs.zsh.autosuggestion.enable` (wires to `pkgs.zsh-autosuggestions`) and `programs.zsh.fastSyntaxHighlighting.enable` (wires to `pkgs.zsh-fast-syntax-highlighting`) both exist natively. Only `zsh-users/zsh-history-substring-search` and `zsh-users/zsh-completions` needed manual `programs.zsh.plugins` entries — both are plain nixpkgs packages (`pname`s confirmed via `nix eval`), no `fetchFromGitHub` needed for either. `getantidote/use-omz` + `ohmyzsh/ohmyzsh path:lib` + the three `path:plugins/*` entries map onto `programs.zsh.oh-my-zsh.enable` with `plugins = [ "colored-man-pages" "command-not-found" "extract" ]`.
- **`mattmc3/ez-compinit` was not ported** — nixpkgs doesn't package it at all (confirmed via `nix eval`, errors), and once `oh-my-zsh.enable = true`, Home Manager's own `enableCompletion`-triggered `compinit` call is skipped in favor of oh-my-zsh's own (avoiding running it twice) — which already only rebuilds `$ZSH_COMPDUMP` when its own fpath/revision metadata changes, the same goal `ez-compinit` served. Confirmed by reading the module source, not assumed.
- **`rupa/z` replaced with `programs.zoxide.enable`** (operator's explicit choice) — modern, Nix-packaged, already on this repo's planned software stack.
- **Dropped, not ported, all confirmed decisions**: the explicit `SSH_AUTH_SOCK="$XDG_RUNTIME_DIR/gcr/ssh"` override (redundant — Phase 3 already confirmed `gcr-ssh-agent` exports this automatically), `nvm` sourcing and the unguarded `eval "$(register-python-argcomplete pipx)"` (neither `nvm` nor `pipx` are packaged anywhere in this repo yet, and the pipx line would have errored at shell start without it — both out of Phase 4's scope), the WSL-only `here="explorer.exe ."` alias and WSL detection branch, and a hardcoded `/home/ol/.opencode/bin` `PATH` line (operator-machine-specific, not portable). `QT_QPA_PLATFORMTHEME=qt6ct` was *kept* as a session variable (harmless, matches the operator's real desktop expectations) but the `qt6ct` package itself was deliberately not added this phase — Qt/GTK theming is already a separate, tracked Phase 3/Noctalia TODO (`theme.templates.builtin_ids`).
- **A real gap found and fixed during implementation, not assumed correct from the plan**: `zsh-users/zsh-history-substring-search` does nothing by itself — reading its actual plugin source confirmed it contains no `bindkey` calls at all, so `home/zsh.nix` adds `bindkey "$terminfo[kcuu1]" history-substring-search-up` / `kcud1` explicitly. This wasn't in the operator's original `.zshrc` either, so the plugin may have been silently inert there too.
- **A real plan error caught by the build, not by review**: the plan's `home/zsh.nix` draft used `programs.zsh.sessionPath`, which doesn't exist (`nix build` failed with "did you mean ... sessionVariables ... setOptions"). Fixed to `home.sessionPath` (the correct, general Home Manager mechanism, confirmed by reading `modules/home-environment.nix`) — a reminder that even a plan verified against actual module source can still have a wrong option name, and the build is what actually catches it.
- **Neovim added as a bare, unconfigured package** (`home/neovim.nix`, just `home.packages = [ pkgs.neovim ];`) — not on this repo's roadmap/software-stack list anywhere, but the ported zsh config sets `EDITOR`/`VISUAL=nvim` and an `nv` alias, which need the binary to exist at all. Confirmed with the operator: package it now, defer the full Neovim config (plugins, LSP, etc.) to its own later planning session — same treatment as Git identity and Ghostty below.
- **Git identity/config and Ghostty are explicitly out of scope for this pass** — no existing Ghostty config was found (unlike zsh/starship/lazygit, which all had one), and Git needs the operator's name/email, so both remain open items in the existing task list.
- File layout: `modules/system/shell.nix` (new, system-level `programs.zsh.enable`) + `modules/system/users.nix` (adds `pkgs` arg, sets `shell = pkgs.zsh`) for the system half, mirroring the niri system/home split; `home/zsh.nix`, `home/starship.nix`, `home/lazygit.nix`, `home/neovim.nix` each their own file (one responsibility per module, matching the `niri.nix`/`noctalia.nix` precedent) rather than bundled — none of them gated on any `osConfig.features.*` flag, since (per the already-established bluetooth/sshAgentUnlock precedent) every real host wants a terminal environment, so there's no per-host axis of variation for a flag to express.
- **Verified live on `the-entertaining-nios-vm`**: both hosts' `system.build.toplevel` build cleanly; `config.programs.zsh.enable`, `config.users.users.ol.shell.pname` ("zsh"), and the Home Manager `programs.{zsh,zoxide,starship,lazygit}.enable` all evaluate `true`. After redeploy: login shell is zsh, all seven aliases (`l`/`ll`/`la`/`grep`/`lg`/`q`/`cl`/`nv`) work, `EDITOR`/`VISUAL`/`PATH` (`~/.local/bin`, `~/go/bin`) are correct, `starship.toml` and `lazygit/config.yml` match the ported originals exactly, `oh-my-zsh`/autosuggestions/fast-syntax-highlighting are all sourced in the generated `.zshrc`, and the history-substring-search bindkeys resolve correctly. One test artifact worth noting for future debugging: testing via `ssh ... zsh -i -c` initially showed `bindkey: cannot bind to an empty key sequence` — this was **not a real bug**, just `$TERM` being unset in a bare non-interactive SSH command (so the `zsh/terminfo` module had nothing to look up); setting `TERM=xterm-256color` for the test reproduced a real terminal's environment and resolved cleanly (`kcuu1`/`kcud1` → real escape codes). A real terminal session (Ghostty, or anything inside niri) always has `TERM` set, so this was never an issue for actual use.

---

## Phase 5 — Theming


Folds in theming work already landed in earlier phases rather than leaving it
scattered across their sections: Noctalia v5's wallpaper-driven Material-You
palette, the `ghostty`/`gtk3`/`gtk4`/`qt` official color templates, the
`neovim`/`yazi` community color templates, the custom `starship`/`lazygit`
user templates, and niri's own cursor line (all `home/noctalia.nix` /
`home/niri/cfg/misc.kdl`, documented in Phases 3/4 above). What's actually
new this phase:

- **Cursor** — `home/cursor.nix` (new): `home.pointerCursor` (`pkgs.bibata-cursors`,
  `"Bibata-Modern-Classic"`, size 22, `gtk.enable = true`) is now the single
  Home Manager source of truth for GTK/Qt/Wayland toolkit apps.
  `x11.enable` deliberately omitted — XWayland is disabled repo-wide.
  `home/niri/cfg/misc.kdl`'s own `cursor { ... }` block (niri renders its own
  compositor cursor independently) is untouched, so the same value is
  intentionally duplicated in two places — keep them in sync by hand if
  either ever changes. `modules/desktop/greetd.nix`'s standing cursor TODO is
  resolved: `programs.noctalia-greeter.settings.cursor = { theme =
  "Bibata-Modern-Classic"; size = 22; }` (schema confirmed real by reading
  the `noctalia-greeter` flake input's own `nix/nixos-module.nix` example).
  New `modules/desktop/theming.nix` installs `bibata-cursors` +
  `papirus-icon-theme` via `environment.systemPackages`, since
  noctalia-greeter runs outside any user's Home Manager profile and can't
  see packages Home Manager installs for the user session. Remember the
  existing `greeter.toml` gotcha (Phase 3): it's only ever seeded once, so
  an already-booted host needs `sudo rm
  /var/lib/noctalia-greeter/greeter.toml && sudo systemd-tmpfiles --create
  && sudo systemctl restart greetd` for this to take effect.
- **Icons** — `home/gtk.nix` (new): `gtk.enable = true`, `gtk.iconTheme` =
  `pkgs.papirus-icon-theme` / `"Papirus-Dark"`. Folder recoloring uses
  Noctalia's own **official `papirus-icons` community template** (added to
  `home/noctalia.nix`'s `community_ids`) — found by checking the live
  community-template catalog (`https://api.noctalia.dev/templates`) rather
  than assumed unavailable; it maps the live wallpaper accent to the closest
  `papirus-folders` preset color via HSV distance and recolors in place, the
  same mechanism already used for `neovim`/`yazi`. Its `apply.sh` falls back
  to `cp -r /usr/share/icons/Papirus` (a path that doesn't exist on NixOS) if
  `~/.local/share/icons/Papirus` isn't already present — worked around by
  `home/gtk.nix`'s own `home.activation.seedPapirusIcons`, which seeds a
  *writable* copy from the Nix-store package so the template's own check
  always finds the directory already there and never hits that fallback.
  A mutable copy is required (`papirus-folders` rewrites the SVGs in place —
  a store symlink wouldn't work), so the seed re-copies on every Home Manager
  activation. That used to be recorded here as an accepted trade-off ("folder
  colors go back to default blue until Noctalia's next re-theme pass"); it
  was not acceptable in practice and has since been fixed — see *Papirus
  folders reverted to default blue on every activation* below.
- **GTK modernization** — `home/gtk.nix` also sets `gtk.gtk3.theme` to
  `pkgs.adw-gtk3` / `"adw-gtk3-dark"` (both folder names confirmed via a live
  build) for a modern, libadwaita-like rounded look on GTK3 apps. GTK4 gets
  no theme override — GTK4 apps already render rounded via libadwaita
  itself, and Home Manager's own `gtk.gtk4.theme` option is an unofficial,
  being-deprecated `@import` workaround with nothing to gain here. Noctalia's
  existing `gtk3`/`gtk4` color templates are untouched and layer their
  palette on top exactly as before. **Only verified config-side so far**
  (dconf keys, `gtk-3.0/settings.ini`) — unlike Qt, which was verified by
  actually opening qt5ct/qt6ct, this VM has no real GTK3/GTK4 application
  installed yet to open and visually confirm against. **TODO: re-check GTK
  theming (rounded corners, icon theme, colors) once a real GTK app lands**
  — Nautilus is the first one on the roadmap (Phase 6, Applications).
- **Qt — deliberately still color-only, gap closed, no rounding.** Real
  research, not assumed: `kvmarwaita` (KvMarwaita) is a genuine nixpkgs
  package — the closest available libadwaita/Materia-styled, rounded Kvantum
  theme — but reading Kvantum's own source (`Kvantum.cpp`) and KvMarwaita's
  `.kvconfig` directly confirmed Kvantum themes hardcode their own palette in
  `[GeneralColors]`, and `respect_DE` (the only DE-integration setting) only
  affects icon visibility, never color — Kvantum never reads qt5ct/qt6ct's
  palette. Separately, reading Noctalia v5's own source
  (`assets/templates/qt/qtct.conf`, `builtin.toml`) confirmed its `qt`
  template specifically targets qt5ct/qt6ct's native `[ColorScheme]`
  mechanism (the one Fusion reads), with zero Kvantum awareness anywhere in
  Noctalia. **Decided against Kvantum this phase** — switching would mean
  losing Noctalia's live wallpaper-color tracking for Qt apps in exchange for
  rounded corners; revisit Kvantum + KvMarwaita later as its own research
  task if wanted. What *did* land: new `home/qt.nix` finally installs the
  actual `qt5ct`/`qt6ct` packages via Home Manager's `qt.enable` +
  `qt.platformTheme.name = "qtct"` + `qt.style.name = "fusion"` (plus
  `qt5ctSettings`/`qt6ctSettings.Appearance.icon_theme = "Papirus-Dark"`) —
  closing a gap left open since Phase 4, where `QT_QPA_PLATFORMTHEME=qt6ct`
  was set as a bare env var (`home/zsh.nix`, `home/niri/cfg/misc.kdl`) but
  the package itself was explicitly never installed. Those env vars are now
  redundant but harmless (same value) — left as-is, not worth touching. This
  also means Phase 4's `~/.config/qt5ct/colors/noctalia.conf` /
  `qt6ct/colors/noctalia.conf` verification (files existed and were
  generated) can finally be re-verified as actually *taking effect* at
  runtime, now that `qt6ct` itself is genuinely present as a package.
- All exact package/attribute names and option shapes above (`bibata-cursors`
  containing a real `Bibata-Modern-Classic` folder, `adw-gtk3`/`adw-gtk3-dark`,
  `Papirus-Dark`, `home.pointerCursor`'s/`gtk.*`'s/`qt.*`'s option shapes)
  were verified directly against this repo's pinned `nixpkgs` and
  `home-manager` revisions — built and inspected live, not recalled from
  general knowledge.
- **Three real bugs found and fixed during live verification, all in
  `home/qt.nix`, each caught by actually opening qt5ct/qt6ct on the VM
  rather than trusting that the config files merely existed:**
  1. Originally set `qt5ctSettings`/`qt6ctSettings.Appearance.icon_theme`
     but never `color_scheme_path` — the actual key (confirmed by reading
     qt5ct's/qt6ct's own `appearancepage.cpp` source) that makes either app
     *use* Noctalia's live-generated
     `~/.config/qt5ct|qt6ct/colors/noctalia.conf` file; merely having that
     file exist did nothing on its own. Fixed via
     `color_scheme_path = "${config.xdg.configHome}/qt5ct|qt6ct/colors/noctalia.conf"`
     — the Nix-resolved absolute path, not a literal `"$XDG_CONFIG_HOME"`
     string, the same class of bug already caught once for
     `home/lazygit.nix`'s `LG_CONFIG_FILE` (Phase 4).
  2. Originally set `qt.style.name = "fusion"`, which sets
     `QT_STYLE_OVERRIDE` — qt5ct's own `mainwindow.cpp` explicitly checks
     `if (env.contains("QT_STYLE_OVERRIDE"))` and shows exactly the "not
     themed correctly" warning this surfaced as. Forcing a style this way
     also bypasses qt5ct/qt6ct's own style application entirely, defeating
     the point of using them. Removed outright — nothing lost, since
     qt5ct's own default `Appearance.style` is already `"Fusion"` (same
     source).
  3. **The actual remaining blocker after both of the above**: even with
     `color_scheme_path` correct and `QT_STYLE_OVERRIDE` gone, qt5ct/qt6ct
     still reported "not themed correctly." Root cause, found by reading
     `qt5ctplatformtheme.cpp`/`qt6ctplatformtheme.cpp`'s `readSettings()`
     directly: `color_scheme_path` is only actually used when
     `custom_palette = true` is *also* set — it defaults to `false`, so the
     path was being read but silently never applied. Fixed by adding
     `custom_palette = true` to both `qt5ctSettings.Appearance` and
     `qt6ctSettings.Appearance`.
  **Verified live end-to-end**: `qt5ct.conf`/`qt6ct.conf` both have the
  correct `color_scheme_path` + `custom_palette=true`; qt5ct's own 3-item
  self-check (`QT_STYLE_OVERRIDE` set, `QT_QPA_PLATFORMTHEME` unset/invalid,
  missing `libqt5ct-style.so`) shows no warnings; the referenced color file's
  `active_colors` has 22 entries (comfortably above `QPalette::NColorRoles`,
  so `loadColorScheme()` doesn't silently fall back to the default
  palette); and the operator confirmed both qt5ct and qt6ct show as
  correctly themed when actually opened in the live niri session.
- **A separate, real gotcha found on the live VM, not caused by this
  session's changes**: Noctalia Shell keeps its own persistent runtime
  overrides sidecar, `~/.local/state/noctalia/settings.toml`, which
  deep-merges *on top of* the Nix-managed `~/.config/noctalia/config.toml`
  (confirmed by reading `ConfigService::deepMerge` in Noctalia's own
  source — its own comment states "arrays: overlay replaces base wholesale").
  This sidecar had a stale `community_ids` (missing `"papirus-icons"`, still
  carrying `"lazygit"` from before the custom-template switch) and a stale
  `wallpaper_scheme` override (`"m3-tonal-spot"` instead of the Nix-declared
  `"m3-content"`) — almost certainly left over from earlier manual testing
  via Noctalia's own Settings UI at some point in this project's history.
  This silently overrode the Nix config with no conflict warning of any
  kind (a different failure mode than the already-known `[template_engine]`
  conflicts) — structurally the same class of "seed once, Nix change has no
  effect until manually reset" gotcha as `noctalia-greeter`'s `greeter.toml`,
  but for Noctalia Shell itself. Fixed on the VM by backing up
  `settings.toml` and correcting just its stale `[theme]`/`[theme.templates]`
  values to match `config.toml`, leaving its other genuine state (lockscreen
  widget layout, notification opacity, launcher settings) untouched. **Not
  yet automated or re-checked for the laptop/desktop hosts** — this is a
  per-host manual reset, same operational shape as the greeter's, worth
  checking again if either of those hosts is ever bootstrapped with a
  pre-existing Noctalia state directory (e.g. migrated from a different
  setup) rather than a truly fresh one.
- **Investigated and confirmed NOT a bug**: `QT_QPA_PLATFORMTHEME` resolves
  to `"qt5ct"` via Home Manager's own `qt.platformTheme.name = "qtct"`
  (its internal `styleNames` table only has one hardcoded mapping, with no
  Qt5/Qt6-version-aware distinction), while niri's `misc.kdl` (Phase 4)
  separately sets it to the literal `"qt6ct"` in its own spawn environment,
  which wins inside the actual graphical session. Confirmed by reading
  qt5ct's own plugin source (`qt5ct.json`: `"Keys": [ "qt5ct", "qt6ct" ]`;
  `main.cpp`: `if (key.toLower() == "qt5ct" || key.toLower() == "qt6ct")`)
  and empirically, by running `qt5ct --platform offscreen` with
  `QT_DEBUG_PLUGINS=1` and `QT_QPA_PLATFORMTHEME=qt6ct` set — the Qt5 build
  of qt5ct's platform-theme plugin deliberately answers to *both* key names,
  specifically so one shared env var value works for mixed Qt5/Qt6
  environments. Both values work correctly in practice; no fix needed.


---

## Neovim, Yazi, and the custom Noctalia user templates

Spans the Phase 4/5 boundary — the Neovim work began as a Phase 4 loose end
(a bare package) and finished during the Theming phase, which is also where
the custom `theme.templates.user.<id>` mechanism was discovered and applied
to Starship, Lazygit, and Neovim.

**Neovim: reduced-scope config, kept on lazy.nvim/Mason rather than going native — done.** A full native Nix port (`programs.neovim` + nixpkgs `vimPlugins`, dropping lazy.nvim/Mason for reproducibility, matching the zsh/Antidote precedent) was planned and drafted in complete, verified detail — then reversed. Every new finding added friction: `nvim-treesitter`'s breaking main-branch API rewrite needing manual translation, one plugin (`sqls.nvim`) needing vendoring via `fetchFromGitHub`, no native lazy-loading without hand-rolling `optional = true` + `packadd` triggers, and Noctalia's own official `neovim` community template needing a compatibility hack since it assumes lazy.nvim's directory layout. None of that bought anything once lazy.nvim/Mason were kept anyway (plugins still git-clone/download at runtime either way), so the decision was: **rewrite the operator's actual `neovim_dotfiles` GitHub repo** (a real, separate repo — `github:TechieOllie/neovim_dotfiles`, previously already checked out at `~/.config/nvim`) for the reduced scope, push it, and treat `~/.config/nvim` as an ordinary manually-cloned git checkout, not something Home Manager manages at all. `home/neovim.nix` only provides base toolchain prerequisites.

**Reduced scope, confirmed with the operator**: a nice UI, Lazygit + Yazi integration, Python/Markdown/C++/SQL/PHP language support, and Python debugging (added mid-session). Java/`jdtls` dropped entirely (needed a JDK≥17 on PATH and was the heaviest, most fragile part of the original config).

`neovim_dotfiles` changes (two separate pushes, both reviewed before pushing):
1. Removed `nvim-jdtls` and the Java-specific autocmd block; added `lua/plugins/dap.lua` (`nvim-dap` + `nvim-dap-ui` + `nvim-dap-python`, `debugpy` auto-installed via `mason-tool-installer.nvim` since `mason-lspconfig`'s own `ensure_installed` only covers LSP servers, not debug adapters); updated `README.md` accordingly.
2. **Three genuine, pre-existing bugs found via live testing on the VM** (not introduced by change 1): `treesitter.lua` used `nvim-treesitter`'s old classic API (`ensure_installed`/`auto_install`/`highlight.enable`/`indent.enable`), but the pinned plugin version is the new main-branch rewrite, whose `.setup()` only accepts `install_dir` — confirmed live that **zero parsers were actually installed**, silently, no errors at all. Rewritten for the new API (parser install via `require("nvim-treesitter").install()`, highlighting via `vim.treesitter.start()` in a `FileType` autocmd, indent via `indentexpr`, textobjects wired via individual keymaps instead of a nested config table — `nvim-treesitter-textobjects` had the same breaking rewrite). Separately: clangd 22+ requires `--function-arg-placeholders` to have an explicit value (`=1`, a bare flag now errors at startup), and `sqls.nvim`'s `on_attach` called `require("sqls").on_attach()`, an API the plugin no longer exposes (it's moved to Neovim's native `lsp/<name>.lua` auto-discovery — the plugin's own `lsp/sqls.lua` already provides a complete config; the manual call just errored "module 'sqls' not found").

`home/neovim.nix`'s final package list, every entry confirmed necessary via live failures, not guessed upfront: `neovim`, `gnumake` + `gcc` (plugin native builds, parser compilation), `tree-sitter` (the CLI itself — the new main-branch nvim-treesitter shells out to `tree-sitter build`, a C compiler alone isn't enough), `ripgrep` (Telescope), `python3` (Mason's `debugpy` installer needs it to build its own venv), `unzip`/`nodejs`/`go` (Mason's own installers for clangd/pyright/sqls shell out to these respectively), `php` (phpactor and php-cs-fixer are themselves PHP applications). New `modules/system/nix-ld.nix` (`programs.nix-ld.enable = true;`, imported from `profiles/base.nix`, unconditional) was also required — Mason's `ruff` install is a prebuilt manylinux Python wheel, which failed with "Could not start dynamically linked executable" on NixOS without it; this is the standard, officially-recommended NixOS fix for running any non-Nix-packaged dynamically-linked binary, useful well beyond just this one case. `git` and `yazi` were initially listed here too, then removed once the operator asked whether tools used outside Neovim should really be declared in its file: `git` was outright redundant (`home/git.nix`'s `programs.git.enable` already installs `pkgs.git` — confirmed by reading the home-manager module source); `yazi` got its own new `home/yazi.nix` instead, since it's already on this repo's planned general terminal-tool stack independent of `yazi.nvim`, and now also carries its own Noctalia theming. `ripgrep`/`python3`/`unzip`/`nodejs`/`go`/`php` stay in `home/neovim.nix` since their only reason for existing in this repo *is* Neovim/Mason's needs, not a general-purpose ask — move them to their own module later if a future phase adds general dev-language tooling on its own merits.

**Verified live on the VM**, end to end: `nvim` starts cleanly; `:Lazy` installed all plugins; Mason installed `pyright`/`ruff`/`clangd`/`sqls`/`phpactor`/`lua-language-server`/`debugpy` (no `jdtls`); treesitter parsers actually install and highlighting genuinely activates (confirmed via a populated highlighter tree, not just "no errors"); LSP clients attach correctly for Python/C++/SQL/PHP (PHP specifically needs an actual project root marker — `.git`/`composer.json` — to attach at all, which is normal LSP behavior, not a bug, confirmed by testing outside vs. inside a git-initialized directory); DAP + `debugpy` load without error. `~/.config/nvim` itself was synced onto the VM via `rsync` from a local clone rather than a direct `git clone`, since the VM deliberately only ever has a throwaway test SSH key (see Phase 3) and has no credentials for the operator's private GitHub repos — a real, host-specific workaround, not a Nix-side concern.

**Three more genuine, pre-existing bugs found via deeper live testing after the initial verification pass** (all pushed to `neovim_dotfiles`, not this repo): clangd 22+ requires `--function-arg-placeholders` to have an explicit value (`=1`); `sqls.nvim`'s `on_attach` called `require("sqls").on_attach()`, an API the plugin no longer exposes (it moved to Neovim's native `lsp/<name>.lua` auto-discovery, which already provides a complete config on its own — the manual call just errored "module 'sqls' not found"). Both found by testing each language's LSP actually attaching, not just checking Mason installed the binary.

**A real bug in this repo's own Nix code, not `neovim_dotfiles`**: `home/lazygit.nix`'s `LG_CONFIG_FILE` session variable used a literal `"$XDG_CONFIG_HOME/..."` string, assuming shell-side expansion — but `home.sessionVariables` values are written into a plain shell script as-is, and `$XDG_CONFIG_HOME` isn't actually guaranteed to be a set shell variable at the point that script runs. Confirmed live the value resolved to `/lazygit/config.yml` (empty expansion, missing the home directory entirely), breaking lazygit's config lookup both standalone and from Neovim's `lazygit.nvim` plugin — this had actually already been "confirmed working" once earlier by a test that printed the broken value without the mistake being noticed. Fixed by using `${config.xdg.configHome}` (resolved by Nix at eval time, embedding a real absolute path in the generated script) instead of relying on any shell-side expansion.

**Yazi theming added, plus a correction to how Noctalia's community `community_ids` list actually works.** Screenshots showed Yazi rendering with zero theming (confirmed: `~/.config/yazi` didn't exist at all) while Ghostty/Lazygit/GTK/Qt/Neovim all correctly reflected the wallpaper palette. Noctalia does have an official `yazi` community template — initially added as two `community_ids` entries, `"yazi"` and `"yazi-syntax"`, assuming each was independently fetchable, until the operator corrected this: reading `template_apply_service.cpp` directly confirmed `communityIds` entries key a *cached catalog directory* (matching `community-templates`' own top-level folder names, e.g. `yazi/template.toml`), and each cached file is processed as a whole once fetched — `[templates.yazi]` (flavor colors) and `[templates.yazi-syntax]` (tmTheme) both live in that *same* file, so only `"yazi"` needs listing; `"yazi-syntax"` isn't its own fetchable catalog entry and just produced a spurious "not cached yet" warning (the same class of warning seen earlier and correctly diagnosed for `"lazygit"` before that was dropped in favor of the custom template). Both outputs land in a clean, separate `~/.config/yazi/flavors/noctalia.yazi/` directory — no conflict, since `home/yazi.nix` doesn't manage any yazi config with Nix at all. **Verified live**: `flavor.toml`/`tmtheme.xml` both generated with real palette hex colors, `~/.config/yazi/theme.toml`'s `[flavor]` section correctly activated (`dark`/`light = "noctalia"`), self-recovered from an initial "not cached yet" warning once Noctalia finished fetching the catalog on its own. Separately, garbled Telescope rendering seen in the same screenshots was identified as the already-diagnosed VM-only SPICE display-scaling artifact from Phase 3 (virt-manager's View → Scale Display), not a theming/config issue.

**Custom Noctalia "user" templates for Starship and Lazygit, resolving the Starship theming gap left open in Phase 4.** Investigating the Neovim port (see below) turned up a third Noctalia template layer beyond the already-used `builtin_ids`/`community_ids`: `theme.templates.user.<id>`, a real, build-time-static field (confirmed by reading `src/config/config_types.h`'s `UserTemplateConfig` and `src/config/schema/config_schema.cpp` in the `noctalia` flake input directly) where **we** control `input_path`/`output_path`/`post_hook` completely, unlike the official builtin/community templates. This matters because Starship's official `builtin_ids` template and Lazygit's official `community_ids` template both mutate an *existing* file in place (`sed -i` for starship.toml, `mv` for lazygit's config.yml — confirmed both use the same temp-file-then-rename mechanism, which destroys a Home-Manager-managed symlink at that path exactly like each other) — a real conflict with the already-completed Phase 4 `home/starship.nix`/`home/lazygit.nix`. Considered and rejected first: dropping Noctalia's theming for Stylix entirely (already litigated in Phase 3 — Stylix is build-time-only, so wallpaper changes need a full rebuild instead of instant live re-theming, and Noctalia Shell's own UI isn't a Stylix target at all, so this would just relocate the "two systems fighting" problem somewhere more visible) and a "seed once, never re-enforce" activation script (matches the existing `noctalia-greeter`/`greeter.toml` precedent, but permanently loses declarative enforcement for these two files). The custom-template fix instead renders the **entire** output file fresh each time — same behavior as ghostty/gtk/qt/niri's own templates — sidestepping the conflict by construction rather than working around it:
- `home/noctalia-templates/starship.toml.tmpl` (new) — the operator's full starship config, ported verbatim from what used to live in `home/starship.nix`'s `settings`, with the two named colors (`green`/`blue`) replaced by real Noctalia Material-You color-role tokens (`{{colors.primary.default.hex}}`/`{{colors.secondary.default.hex}}` — confirmed real, not guessed, by cross-referencing the same tokens used in the reference implementation below). `home/starship.nix` now has no `settings` at all — `home/noctalia.nix`'s `templates.user.starship` (output `$XDG_CONFIG_HOME/starship.toml`, no `post_hook` needed since Starship just re-reads its config on every prompt) is the sole owner.
- `home/noctalia-templates/lazygit-theme.yml.tmpl` (new) — ported verbatim from `luxus/luxus-noctalia-templates`' own `lazygit/noctalia-theme.yml` (a real, working reference implementation found via `gh search repos`, confirming the exact token names). Output is a **separate** file (`$XDG_CONFIG_HOME/lazygit/themes/noctalia.yml`), keeping `home/lazygit.nix`'s Nix-managed `config.yml` completely untouched — merged at invocation time via lazygit's own native `LG_CONFIG_FILE` (comma-separated multi-file merge), set as a persistent `home.sessionVariables` entry in `home/lazygit.nix` rather than baked into the `lg` alias, so it applies regardless of what invokes lazygit (a direct terminal call, Neovim's own `lazygit.nvim` plugin, etc.), not just one alias.
- `home/noctalia.nix`'s `theme.templates` reorganized into `{ builtin_ids, community_ids, user }`; `builtin_ids` no longer includes `"starship"`, and `community_ids` gained `"neovim"` at the time (later removed — see the Theming-phase note below) but not `"lazygit"`.
- **Verified live on the VM**: both `~/.config/starship.toml` and `~/.config/lazygit/themes/noctalia.yml` are plain regular files (not Home-Manager symlinks, confirmed via `ls -la`) containing real rendered hex colors (e.g. `#a6c8ff`), `~/.config/lazygit/config.yml` remains a correct, untouched Home-Manager symlink, the `LG_CONFIG_FILE` session variable resolves correctly in a fresh zsh session, and the post-redeploy Noctalia log shows zero `[template_engine]` conflicts for either file (the pre-existing `niri/noctalia.kdl` warnings in the log are stale, from well before this change, and unrelated).

**"neovim" moved from `community_ids` to its own custom user template too, same Theming-phase session as the niri blur work above, prompted by an operator request to make Neovim's own background transparent so Ghostty/niri's blur shows through it.** Investigation found the Noctalia community `"neovim"` template caches its *own* `matugen-template.lua` from `github:noctalia-dev/community-templates` — a completely separate file from the operator's actual `neovim_dotfiles` repo, despite the same filename and output path, both racing to write `~/.config/nvim/lua/matugen.lua`. Also found, independently: `matugen.get_palette()` never existed on either file, so every highlight override in `neovim_dotfiles`' `lua/plugins/ui.lua` `set_extra_highlights()` (Telescope, Diffview, LSP diagnostics, WhichKey — not just the new transparency lines) had been silently dead code the whole time. Per the operator's explicit choice, resolved by giving this repo sole ownership: `"neovim"` removed from `community_ids`, `home/noctalia.nix` gained `templates.user.neovim` (new `home/noctalia-templates/neovim-matugen.lua.tmpl`, output `$XDG_CONFIG_HOME/nvim/lua/matugen.lua`, `post_hook = "pkill -SIGUSR1 nvim || true"` to hot-reload already-running instances) — same "render the whole file fresh" pattern as starship/lazygit above. The template itself now defines `get_palette()` properly (a named `palette` table shared by both `setup()` and `get_palette()`), and the same fix was pushed to `neovim_dotfiles` (`db82772..9d4d7fb`) so the operator's real machine benefits too, even though that copy is no longer what actually generates the live file under this repo's setup.

`neovim_dotfiles`' `lua/plugins/ui.lua` also gained the actual transparency highlights: `Normal`/`NormalNC`/`SignColumn`/`EndOfBuffer` → `bg = "none"`, with `fg` re-specified explicitly (`nvim_set_hl()` replaces a group's whole definition rather than merging with what base16 already set — confirmed live that omitting `fg` left `Normal` completely empty). Floating windows (`NormalFloat`, Telescope, etc.) deliberately keep their own solid background so they still read as "elevated" above the now-transparent main area.

**A real, host-specific gotcha found during live verification, not a repo bug**: even after all of the above, the VM's actual `nvim` kept reverting to a solid background. Root cause, found by hooking `vim.api.nvim_set_hl` with a stack-trace logger: a stale `~/.config/nvim/lua/plugins/base16.lua` — created earlier by Noctalia's *now-removed* official `"neovim"` community template's own `apply.sh` bootstrap logic (`if [ ! -f "$plugin_file" ] && ! grep -rl "base16-nvim" ...`) back when that template was still active — registers its own second, competing `RRethy/base16-nvim` plugin spec with a bare `matugen.setup()` call and no highlight overrides, and lazy.nvim loads it *after* `ui.lua`, silently reverting every highlight override on every start. Confirmed via `debug.traceback()` that this file's `config()` was the exact source of the reverting call. Not present in `neovim_dotfiles` at all (confirmed via `git ls-files`) — a plain untracked runtime artifact specific to this VM host, deleted directly (`rm ~/.config/nvim/lua/plugins/base16.lua`).

**That fix didn't hold — the file kept coming back — and the actual root cause was the `settings.toml` sidecar bug (see the papirus-icons/wallpaper_scheme section above) recurring for a new reason.** Earlier this same session, that sidecar's stale `community_ids` was manually patched to `["neovim", "yazi", "papirus-icons"]` to fix a *different* problem — but once `"neovim"` was later dropped from `home/noctalia.nix`'s real `community_ids` in favor of the custom user template, the sidecar was never updated to match, and since it deep-merges *over* config.toml with whole-array replacement, Noctalia kept treating `"neovim"` as still selected — re-running the official template's `apply.sh` on every restart, recreating `base16.lua` every time. Fixed by editing the sidecar's `community_ids` down to `["yazi", "papirus-icons"]`, confirmed via a full `systemctl --user restart noctalia` that `base16.lua` no longer reappears and the transparency highlights hold. **Standing lesson for this repo**: any time `home/noctalia.nix`'s `builtin_ids`/`community_ids`/other array-typed `theme.*` settings change on an already-provisioned host, check `~/.local/state/noctalia/settings.toml` for a stale override of the same key — a Nix-side change alone is not guaranteed to take effect if that sidecar already has an opinion.

---

## Phase 6 — Applications


VS Code, Zen Browser, Vesktop, Nautilus. Planned via Plan mode before
implementation (per the standing planning convention), with real research
into the operator's existing config on `the-entertaining-nios-laptop`
(CachyOS) before deciding what to port — same approach as every previous
phase.

**Zen Browser isn't in nixpkgs at all** (confirmed via `nix eval` against
this repo's pinned nixpkgs revision) — added as its own flake input,
`github:0xc000022070/zen-browser-flake` (`inputs.nixpkgs`/`home-manager`
both `.follows` this repo's, unlike `noctalia` — no separate binary cache to
lose by doing so), threaded through `lib/mkHost.nix`'s
`home-manager.extraSpecialArgs` only (it has no NixOS module).
`home/zen-browser.nix` originally imported `zen-browser.homeModules.beta` —
**beta** specifically, matching the AUR `zen-browser-bin` build the operator
actually ran at the time (confirmed via `pacman -Qi`: v1.21.9b). Investigated
and ruled out `twilight`/`twilight-official` (the flake's own "recommended
for reproducibility" channels) at that point: reading `package.nix`/
`sources.json` in the flake's own repo directly confirmed both are Zen's
**nightly** channel (`1.22t`), newer and less stable than what was running
then — `twilight` pulls from the flake maintainer's own re-hosted mirror,
`twilight-official` pulls the identical build straight from
`zen-browser/desktop`'s own release, at the time byte-identical (same
sha256) but one hop shorter. **Later bumped to `twilight-official` at the
operator's explicit request**, ahead of what `beta` tracks — the two
channels' builds may no longer be byte-identical to each other by the time
this lands, since each is refreshed independently upstream; `twilight-official`
was chosen over plain `twilight` for the same one-hop-shorter reasoning
already investigated (upstream's own release artifact, not a third-party
mirror). No extension/policy porting — the operator's real profile
(bookmarks, logins, manually-installed extensions like uBlock Origin/Dark
Reader/Obsidian Web Clipper) lives in mutable Firefox-style profile state
(`~/.config/zen/<profile>/...`), out of scope for Nix the same way browser
profile data always is in this repo.

**VS Code: a deliberately smaller scope than every other Phase 6 app, a
real discussed decision.** Investigating what to port turned up two facts
that changed the plan: the operator has **7 hand-built named VS Code
profiles** (Docker, ESP-IDF, Flutter, Java, Python, Web Dev, C/C++ —
confirmed via `~/.config/Code/User/globalStorage/storage.json`'s
`userDataProfiles`, not just the single Default profile a first pass had
assumed), and is already actively relying on VS Code's own built-in
Settings Sync day to day (confirmed via a live
`settingsSync.ignoredExtensions` key in the operator's real settings.json —
evidence of active use, not just availability). Discussed directly: keeping
Settings Sync as the sync mechanism and porting nothing
(settings/keybindings/extensions/profiles) into Nix was chosen over both
"port Default only" and "full 7-profile parity" — Settings Sync already
solves exactly this problem, and replicating profile-level parity across
all 7 in Nix would be a large lift for something already working, with the
real cost (Settings Sync living outside `nixos-rebuild switch
--rollback`'s coverage) accepted knowingly, the same shape of trade-off
already taken once for zsh's Antidote-to-native-plugins move (Phase 4) —
just resolved in the *opposite* direction here, since unlike Antidote,
Settings Sync isn't something this repo would otherwise have to reinvent.
`home/vscode.nix` therefore only has `home.packages = [ pkgs.vscode ]`, no
`programs.vscode.*` at all. This did surface one real, unavoidable
requirement: `pkgs.vscode` is unfree (MS branding/telemetry) and eval
rejects it without an explicit allow — new `modules/desktop/vscode.nix`
sets `nixpkgs.config.allowUnfreePredicate` scoped to just `"vscode"` (not a
blanket `allowUnfree = true`, since no other unfree package is used yet;
Phase 7's Steam/Proton GE will likely need to broaden this). Has to be a
NixOS-level module, not something `home/vscode.nix` itself could set —
`home-manager.useGlobalPkgs = true` (`lib/mkHost.nix`) means home-manager
shares the one `pkgs` instance already built from the host's own
`nixpkgs.config` by the time it evaluates.

**Vesktop: config ported, and a real correction to what was first assumed
about its theme files.** `home/vesktop.nix` ports both
`~/.config/vesktop/settings.json` and
`~/.config/vesktop/settings/settings.json` (the Vencord plugin config, ~180
plugin toggle entries) — copied as real JSON files
(`home/vesktop-config/{settings,vencord-settings}.json`, loaded via
`builtins.fromJSON (builtins.readFile ...)`) rather than hand-transcribed to
Nix attrs, a deliberate deviation from every other ported config in this
repo (git/starship/lazygit/ghostty are all literal Nix attrs) — justified
by scale: retyping ~180 plugin entries by hand is a real transcription-risk
surface a verified file copy avoids entirely. Confirmed via reading
home-manager's actual `modules/programs/vesktop/mkVesktopLikeModule.nix`
that `programs.vesktop.settings`/`vencord.settings` write to exactly those
two real paths, so this is a safe, literal port; the only edit made was
dropping `vencord-settings.json`'s `cloud.settingsSyncVersion` (a runtime
last-sync timestamp, not a real preference). **The two theme CSS files
already on the operator's real machine
(`~/.config/vesktop/themes/{noctalia,noctalia-material}.theme.css`) were
initially misread as hand-installed BetterDiscord community themes** (their
own headers credit `refact0r/midnight-discord` and
`CapnKitten/Material-Discord` respectively) — corrected after reading
`noctalia-dev/community-templates/discord/template.toml` directly: its
`discord_midnight_vesktop`/`discord_material_vesktop` template ids write
*exactly* those two paths, meaning they're Noctalia's own community
`"discord"` template output (Noctalia's template just wraps/forks those two
upstream themes), not manually curated files. `home/vesktop.nix`
deliberately never declares `programs.vesktop.vencord.themes` for either
name, leaving that directory owned by Noctalia's template engine — the same
"separate output file, no conflict" pattern already used for
ghostty/gtk/qt. `home/noctalia.nix` gains `"discord"` in `community_ids`.

**Vesktop's custom tray/splash assets, added at the operator's request
after the initial plan.** `~/.config/vesktop/userAssets/{splash,tray,
trayUnread}` are real, hand-customized binaries (confirmed via `file`: an
animated GIF splash screen, two 64x64 PNG tray icons) that Vesktop reads by
fixed filename convention — no settings.json key references them, and no
home-manager option exists for this at all (confirmed by reading
`mkVesktopLikeModule.nix`/`vesktop/default.nix` in full). Copied verbatim
into `home/vesktop-assets/{splash,tray,trayUnread}` (kept extensionless,
matching Vesktop's own convention) and wired via three individual
`xdg.configFile` entries. A plain Nix store copy, not `wallpapers/`'s
live-clone treatment — these are small (~10-107KB), static, rarely-changed
files, unlike the wallpaper collection's size/edit-frequency profile that
justified the live-clone approach there.

**Nautilus: new system/home split, mirroring niri's.** No Noctalia template
exists for Nautilus (confirmed — absent from the community-templates
catalog); it's a plain GTK4 app, so it already inherits this repo's
existing `adw-gtk3`/Papirus/cursor theming with nothing new needed there.
New `modules/desktop/nautilus.nix` (system half, gated on
`config.features.niri`) installs `pkgs.nautilus` plus three pieces of
infrastructure **nothing in this repo had enabled before** — niri alone
never pulled in a dconf-backed GTK app: `programs.dconf.enable` (the dconf
D-Bus service itself — without it, no GTK app's settings persist outside a
full GNOME session), `services.gvfs.enable` (trash, network mounts, MTP —
confirmed via reading `nixos/modules/services/desktops/gvfs.nix` that this
wires real D-Bus service files, `services.udisks2.enable`, and
`programs.fuse.enable`, not just a package), `services.tumbler.enable`
(thumbnails). New `home/nautilus.nix` (user half, self-gates on
`osConfig.features.niri`) ports the operator's real
`dconf dump /org/gnome/nautilus/` preferences 1:1 via `dconf.settings`
(icon-view captions/zoom, hidden-files/date-format/folder-viewer
preferences, window sizes via `lib.hm.gvariant.mkTuple`) — skips
`migrated-gtk-settings`, confirmed to be a runtime marker Nautilus itself
writes on first launch, not a real preference (also confirmed live: it
reappeared in `dconf dump` on the VM despite never being set by
`home/nautilus.nix`).

**Verified live on `the-entertaining-nios-vm`** (full deploy, not just
eval): `nix flake check` and a full `nixos-rebuild switch --target-host`
both succeeded (the operator ran the actual switch themselves via
`nix run nixpkgs#nixos-rebuild -- switch --flake .#the-entertaining-nios-vm
--target-host ol@<vm-ip> --elevate=sudo --ask-elevate-password` — sudo
elevation on the target is the operator's to run, not something handled by
the assistant). Confirmed over SSH afterward: `code`/`vesktop`/`nautilus`/
`zen-beta` all present and launch (`code --version` succeeds; `nautilus
--version` correctly fails only on "no display", i.e. reaches real GTK
init); Vesktop's ported `settings.json`/`settings/settings.json` match the
original exactly; the three custom `userAssets` resolve as real symlinks
into the Nix store; Nautilus's `dconf.settings` match the original dump
exactly; `services.gvfs`'s real D-Bus service files
(`org.gtk.vfs.{Daemon,UDisks2VolumeMonitor,...}.service`) and `programs.dconf`'s
`dconf.service` are both present/active; Zen Browser is already the system
default browser (`xdg-settings get default-web-browser` →
`zen-beta.desktop`). **Note**: this specific verification predates the later
`beta` → `twilight-official` channel bump above — the binary/desktop-entry
name is now `zen-twilight`, not `zen-beta`; not yet re-verified live under
the new channel.

**One real, expected recurrence of an already-documented gotcha, fixed
live**: after redeploy, `~/.config/vesktop/themes/` didn't yet contain the
new discord-theme output, and the VS Code/Zen community templates hadn't
run either — the exact `~/.local/state/noctalia/settings.toml` sidecar
issue already documented in the Theming-phase section above (it deep-merges
*over* `config.toml` with whole-array replacement, so its still-stale
`community_ids = ["yazi", "papirus-icons"]` silently overrode this phase's
new `"discord"`/`"vscode"`/`"zen-browser"` additions). Fixed the same
documented way: patched the sidecar's `community_ids` to match, restarted
`noctalia.service`. Confirmed fixed: all three Vesktop theme CSS variants
appeared, the VS Code theme extension's own bundled color-theme JSON
(`~/.vscode/extensions/noctalia.noctaliatheme-0.0.5/themes/...`) was
already present (extension already installed via Settings Sync) and
correctly themed with no conflict, and Zen's cache-dir theme files
(`~/.cache/noctalia/zen-browser/zen-{userChrome,userContent}.css`)
regenerated. **One remaining gap, self-healing, not a bug**: Zen's
`apply.sh` only edits an *existing* Firefox-style profile's
`userChrome.css`/`user.js` (it globs for `prefs.js` files and does nothing
if none exist yet) — no profile exists on this freshly-deployed VM since
Zen Browser has never actually been launched there. This will resolve
itself the first time the operator opens Zen Browser and Noctalia's next
template pass runs, the same self-recovering shape already seen once for
`yazi`'s "not cached yet" warning (Phase 5) — not chased further with a
forced headless launch over SSH, which proved unreliable for a real GUI
browser and isn't necessary to consider this phase verified.

**A separate, unrelated discovery made while looking for a way to verify
this phase**: a `run-nixos-dotfiles` Claude Code skill (an eval/build/check
driver for this flake, `.claude/skills/run-nixos-dotfiles/`) had already
been written and pushed on a separate branch/PR
(`worktree-purrfect-popping-owl`) but not yet merged to `main` — merged
externally (via GitHub) in the course of this session, independent of the
Phase 6 work itself. Used for this phase's own verification
(`driver.sh check`, `driver.sh build the-entertaining-nios-vm`) once
available.

**Three follow-up fixes, all found via the operator's own live testing after
the first Phase 6 deploy, not caught by the initial eval/build/SSH-only
verification pass above** — a reminder that config existing and eval passing
isn't the same as an app actually rendering/working correctly, the same
lesson this repo has hit before (Phase 5's qt5ct bugs, the niri/starship
template conflicts).

- **Nautilus's folder icons weren't themed at all**, reported by the
  operator after opening the real app. Root cause: `home/gtk.nix` sets
  `gtk.iconTheme.name = "Papirus-Dark"`, but Noctalia's official
  `"papirus-icons"` community template only ever recolors the *base*
  `"Papirus"` theme — confirmed by reading the template's own bundled
  `papirus-folders` script source: `-t/--theme` defaults to `"Papirus"`,
  and `apply.sh` never passes `-t`. `"Papirus-Dark"` turned out to be a
  genuinely separate theme tree (its own `index.theme`:
  `Inherits=breeze-dark,hicolor` — not `Papirus` at all, despite the name),
  with its own independent `folder.svg` symlink at every size, never
  touched by any of the above and permanently stuck at Papirus' default
  blue. Fixed in `home/gtk.nix`'s existing `seedPapirusIcons` activation
  script: after seeding the writable, recolorable `Papirus` copy, it now
  also walks every size Papirus-Dark has a `places/folder.svg` for and
  symlinks that file at the recolored copy under `Papirus` instead of its
  own original — GTK's icon lookup checks `$HOME/.local/share/icons`
  *before* the Nix-store-installed theme, so this partial override is
  enough; every other Papirus-Dark icon still resolves from the Nix store
  exactly as before. Considered and rejected first: switching
  `gtk.iconTheme.name` to plain `"Papirus"` (the simpler fix, but a real,
  broader visual regression from the "-Dark" variant deliberately chosen in
  Phase 5, affecting more than just folder icons). **Verified live** (VM,
  before *and* after the redeploy): `readlink -f` on
  `~/.local/share/icons/Papirus-Dark/48x48/places/folder.svg` resolves
  through to the exact same `folder-deeporange.svg` (the wallpaper's
  current recolor) that `~/.local/share/icons/Papirus/48x48/places/folder.svg`
  itself resolves to.
- **Vesktop renamed to "Discord" in Noctalia's launcher/bar, using the
  operator's own custom launcher icon** — an explicit operator request, not
  a bug. Checking the operator's real, currently-live AUR `vesktop.desktop`
  (`/usr/share/applications/vesktop.desktop` on
  `the-entertaining-nios-laptop`) turned up the exact answer needed: it
  already has `Name=Discord` and `Icon=` pointing at a `tray.png` that
  turned out to be byte-identical to the tray icon already ported this
  phase (`home/vesktop-assets/tray`) — no new asset to source, just a
  `.png`-extensioned copy of it (`home/vesktop-assets/discord-icon.png`,
  needed since an absolute-path `Icon=` needs a real image extension to be
  sniffed correctly; the existing extensionless `tray` file only works
  because Vesktop itself reads it by fixed filename convention, a different
  mechanism). New `xdg.desktopEntries.vesktop` in `home/vesktop.nix`
  overrides nixpkgs' own packaged `vesktop.desktop` — confirmed this works
  via home-manager's own module doc/source
  (`modules/misc/xdg/desktop-entries.nix`: installs as a `hiPrio` package
  providing `share/applications/vesktop.desktop`, same filename as
  nixpkgs' own, so it wins the profile priority collision). Categories/
  mimeType/genericName mirror nixpkgs' own entry (so discord:// deep links
  and menu categorization don't regress); only name/icon actually change.
  **One real correction made against both existing desktop files, not
  copied blindly from either**: `StartupWMClass` — the AUR file says
  `vesktop` (lowercase), nixpkgs' own packaged one says `Vesktop` (capital)
  — confirmed live which is actually correct by launching the real
  nixpkgs-built binary under niri and reading its true `app_id` via `niri
  msg windows`: lowercase `vesktop`, matching the AUR file, not nixpkgs'
  own (stale/wrong) packaged value. **Verified live** (post-redeploy): the
  resolved `~/.nix-profile/share/applications/vesktop.desktop` has the
  correct `Name=Discord`, the correct `Icon=` (the new custom PNG's real
  store path), and `StartupWMClass=vesktop`.
- **A real, separate bug found purely as a side effect of the above
  investigation** (needed to actually launch Vesktop to read its live
  `app_id`) — **Vesktop couldn't launch under niri at all**, crashing with
  `Missing X server or $DISPLAY` (ozone falling back to X11, which
  immediately fails since XWayland is disabled repo-wide). Root cause:
  nixpkgs' own `vesktop`/`vscode` wrapper scripts only add their
  `--ozone-platform-hint=auto` flag when `$NIXOS_OZONE_WL` is set (read
  directly from the wrapper scripts) — nothing in this repo had ever set
  it. `home/niri/cfg/misc.kdl`'s own `environment {}` block already sets
  `ELECTRON_OZONE_PLATFORM_HINT`/`XDG_SESSION_TYPE`/etc. and looked like it
  should already cover this — but confirmed live via `systemctl --user
  show-environment` on the VM that **none of that KDL environment block
  actually reaches the systemd `--user` manager's own environment**; only
  `WAYLAND_DISPLAY`/`XDG_CURRENT_DESKTOP`/`XDG_SESSION_TYPE`/`XDG_SESSION_ID`/
  `NIRI_SOCKET` do (almost certainly imported by logind/PAM at session
  start — a different, separate mechanism from niri's own KDL environment
  block, which apparently only applies to niri's own directly-spawned
  children, not systemd-user-service-launched apps like anything Noctalia
  launches via `shell.launch_apps_as_systemd_services`). This means *any*
  Electron app launched the normal way (Noctalia's launcher, or any
  systemd user service) never saw those variables either — not a
  Vesktop-specific bug, a repo-wide gap affecting VS Code too. Fixed with
  the actual NixOS-standard mechanism instead: new
  `environment.sessionVariables.NIXOS_OZONE_WL = "1";` in
  `modules/desktop/niri.nix` (system-level, imported via the standard PAM/
  systemd session environment path that *does* reach `systemctl --user
  show-environment`, confirmed by testing). **Verified live**, both before
  and after the fix: before, `NIXOS_OZONE_WL` absent from `systemctl --user
  show-environment` and Vesktop crashed on every launch attempt; after
  redeploy, present, and a live launch produced a real Wayland window
  (`app_id: "vesktop"`, correctly picked up by the renamed desktop entry
  above) with no ozone/X11 error. A `MESA: error: vdrm_device_connect
  failed` message also appeared in Vesktop's log during this testing — not
  investigated further, matches this repo's existing track record of
  VM-only GPU/rendering quirks (`virtio-gpu-gl`) unrelated to actual repo
  config; revisit only if it turns out to matter on real hardware.
  Separately confirmed, not a bug: Vesktop logs `EROFS: read-only file
  system` when it tries to write back to its own `settings.json` after any
  in-app settings change — expected and accepted, the same inherent
  trade-off every other Nix-declaratively-managed app config in this repo
  already has (no in-app UI changes persist across a rebuild; the Nix
  declaration is always the source of truth).

**Two more apps added to Phase 6 at the operator's request, after the
initial four were already verified live**: Feishin (a Jellyfin/Navidrome/
Subsonic music client) and Obsidian (markdown notes). Both in nixpkgs
(`pkgs.feishin`, `pkgs.obsidian`), no new flake input needed.

- **Neither app's real config was ported — a deliberate security/scope
  call, not an oversight.** Checked the operator's actual config first,
  same as every other app this phase: Feishin's real config.json
  (currently a Flatpak install, `~/.var/app/org.jeffvli.feishin`) has a
  `server` key holding actual Jellyfin/Navidrome/Subsonic connection
  details — almost certainly a token or password, the exact kind of real
  credential this repo never commits (same standing discipline as
  sops-nix for anything that genuinely must be declared). Obsidian's real
  config (`~/.config/obsidian/obsidian.json`) only ever holds a vault path
  (`/home/ol/Documents/Notes` on the laptop) — genuinely machine-specific
  runtime state pointing at a vault that wouldn't exist identically on any
  other host, not a declarative preference. `home/feishin.nix`/
  `home/obsidian.nix` are both package-only, matching `home/vscode.nix`'s
  precedent — the operator sets up the server connection / opens their
  real vault once via each app's own UI after first launch.
- **`pkgs.obsidian` is unfree** (a custom, nixpkgs-flagged license, not a
  standard OSS one — confirmed via `nix eval nixpkgs#obsidian.meta.license`).
  `modules/desktop/vscode.nix` (Phase 6's earlier VS Code unfree-allow
  module) was renamed to `modules/desktop/unfree.nix` and its predicate
  extended to a list (`["vscode" "obsidian"]`) now that it's allow-listing
  more than one package — a naming fix, not new logic.
- **Theming still wired in for both**, despite no config porting — real,
  separate templates confirmed via the community-templates catalog: the
  official `"feishin"` community template writes a separate
  `$XDG_CONFIG_HOME/feishin/custom.css` (confirmed already active on the
  operator's real Flatpak install — a `matugen-template.css`/`custom.css`
  pair already present there); the official `"obsidian"` community
  template discovers every local vault (any `.obsidian` directory under
  `$HOME`, confirmed by reading its own `apply.sh`) and writes/enables its
  own CSS snippet inside each vault's `snippets/` folder. Neither touches
  anything this repo manages, so both added cleanly to `home/noctalia.nix`'s
  `community_ids` with no conflict.
- **Verified live on `the-entertaining-nios-vm`**: both binaries present
  and launch; Feishin's `~/.config/feishin/custom.css` was generated by
  Noctalia (self-recovered from an initial "not cached yet" warning in
  Noctalia's log, the same pattern already seen once for `yazi` in Phase
  5); Obsidian auto-created a default vault
  (`~/Documents/Obsidian Vault/.obsidian`) on first run, and Noctalia's
  template correctly discovered it and wrote/enabled
  `snippets/noctalia.css` there, confirmed via that vault's own
  `appearance.json` (`enabledCssSnippets: ["noctalia"]`). Unlike the
  earlier Phase 6 deploy, `~/.local/state/noctalia/settings.toml`'s
  `community_ids` sidecar was *already* correctly in sync with the new
  additions with no manual patch needed this time — apparently
  self-corrected on its own between deploys, not something to rely on in
  general (see the standing sidecar lesson above), but worth noting this
  particular redeploy didn't need it.

**Three more Zen Browser fixes, found via the operator's own live use after
the `twilight-official` channel bump, not caught by build/eval.**

- **The `Mod+Z` niri keybind never worked at all, under any channel** —
  `home/niri/cfg/keybinds.kdl` had `spawn "zen-browser"`, a binary that
  never existed in any zen-browser-flake channel (confirmed: the flake only
  ever produces `zen-beta`/`zen-twilight`). Fixed to
  `spawn-sh "zen-twilight || zen-beta || zen"` — tries each real binary in
  turn, so the keybind survives a future channel switch (like the one that
  just happened) without needing another edit itself.
- **`home/niri/cfg/rules.kdl`'s two window-rules for Zen (maximize,
  Picture-in-Picture floating) had almost certainly never matched under any
  channel either** — `match app-id="zen$"` requires the app-id to *end* in
  "zen", but the real live app-id (confirmed via `niri msg windows` after
  launching the actual binary) is `zen-twilight`, which doesn't end in
  "zen" at all (same would be true for `zen-beta`). Fixed to
  `app-id=r#"^zen(-\w+)?$"#`, matching `zen`, `zen-beta`, `zen-twilight`,
  or any future channel name. Verified live: after the fix, a fresh launch
  showed `is_floating: false` with the window tiled to the full output
  size, confirming `open-maximized-to-edges` now actually applies.
- **The Noctalia launcher was showing some unrelated icon for Zen** — the
  `twilight-official` channel's own packaged `.desktop` entry sets
  `Icon=zen-twilight-official`, which matches no installed icon file at
  all (confirmed live: the package only ever ships `zen-twilight.png`, at
  every `hicolor` size, never a `-official`-suffixed name) — a real bug in
  the flake's own packaging for this specific channel attribute, not
  something introduced by this repo. Fixed the same way as Vesktop's
  launcher override (`home/vesktop.nix`): new `xdg.desktopEntries.zen-twilight`
  in `home/zen-browser.nix`, replicating the packaged entry's other fields
  (Exec, Categories, MimeType, Actions, StartupWMClass) with just the
  `Icon` corrected. Unlike the keybind fix, this one **isn't** channel-agnostic
  — overriding a desktop entry means matching its exact filename, which
  differs per channel (`zen-beta.desktop` vs. `zen-twilight.desktop`), so
  this override (and its attribute name) needs revisiting again if the
  channel changes.
- **A live-dotfiles gotcha hit while testing, not a new bug**: after the
  redeploy, the keybind still didn't work — turned out the fix existed
  only in this repo's local working tree, not yet pushed to `origin/main`,
  and niri's KDL config is live-symlinked to a *separate* clone at
  `~/.dotfiles` on the VM (`docs/live-dotfiles.md`) that only updates via
  its own `git pull`. Worked around for testing by `scp`-ing the two
  changed files directly to that clone and reloading niri
  (`niri msg action load-config-file`) — same technique already used once
  before for niri config changes — rather than needing a full commit/push/
  pull cycle just to verify a fix.
- **A separate, real "bug report" that turned out to be a self-inflicted
  testing artifact, not a repo issue**: two Zen windows appeared on every
  launch after the keybind fix. Traced to Zen's own crash-recovery session
  restore — repeated test launches during this session were all killed via
  `pkill` rather than closed cleanly, and one of those saved sessions
  happened to have 2 windows open; Zen kept restoring that saved session on
  every subsequent launch (confirmed via `browser.startup.couldRestoreSession.count`
  and the profile's `zen-sessions.jsonlz4`/`sessionstore-backups/`).
  Clearing those session files and relaunching produced exactly one window.
  Nothing in the repo's config was at fault.
- **Confirmed NOT fixable from this repo's config, not a bug either**: the
  operator's own `smart_auto_hide = true` (set via Noctalia's Settings UI,
  living in the `~/.local/state/noctalia/settings.toml` sidecar, not
  anything this repo declares) doesn't free up tiled-window space while the
  bar is hidden. Confirmed by reading Noctalia's own source directly
  (`src/shell/bar/bar_reserved_zone.h`): the layer-shell exclusive zone a
  bar reserves is computed purely from its *static* config (position,
  `thickness`, `marginEdge` — the last defaulting to `0` and unset here),
  never from its current runtime shown/hidden state — so toggling
  auto-hide only affects whether the bar's content renders, not how much
  space niri reserves for it. This is current upstream Noctalia behavior,
  not a config gap on our side; the only real fix would be an upstream
  change to update the exclusive zone dynamically on hide/show.

**Zen Browser transparency (Transparent Zen mod + niri), a later session
investigating and fixing four separate, independent bugs — not one bug with
four symptoms.** The operator found two separate community add-ons and asked
to try them: "Transparent Zen" (a Zen Mod, `zen-browser.app/mods`, UUID
`642854b5-88b4-4c40-b256-e035532109df`, `github:sameerasw/zen-themes` — makes
the browser's own webpage backplate transparent) and "Zen Internet" (an
unrelated WebExtension, `zen-internet` on addons.mozilla.org — injects
per-site CSS for popular websites' content, orthogonal to the mod, no
opacity-relevant settings). Both install manually through Zen's own UI (Mods
store / Firefox Add-ons), matching this repo's existing "no extension/mod
porting" convention for Zen (`home/zen-browser.nix`'s own comment) — neither
is Nix-managed.

**Opacity wiring** (`home/zen-browser.nix`): Transparent Zen's own
transparency toggle (`browser.tabs.allow_transparent_browser` + the
Linux-specific `zen.widget.linux.transparency`) makes the backplate fully
see-through with no tint at all — no built-in "how much" slider. To match
Ghostty/Noctalia's shared `transparency.nix` opacity, the mod's own
`mod.sameerasw.zen_bg_color_enabled`/`zen_transparency_color` preferences
give it a custom semi-transparent background color instead. Set via
`programs.zen-browser.policies.Preferences` (`policies.json`), deliberately
not `profiles.<name>.settings` (`prefs.js`, the pattern the flake's own
examples use) — the latter requires declaring a `profiles.<name>` entry,
handing the whole profile directory to Home Manager to create/manage; this
repo has never done that for Zen, and the VM already has a real ad hoc
profile from earlier live testing, with no guarantee a Nix-declared
"default" profile would line up with it (risking a second, empty profile
being created instead). `policies.Preferences` is stock home-manager Firefox
`policies` (confirmed by reading `mkFirefoxModule.nix` directly): applied at
package-wrap time, fully independent of any `profiles.*` declaration,
reaching whichever profile is actually in use. `Status = "default"`
throughout (not `"locked"`) — seeds the starting value but stays a normal,
user-editable pref, so the mod's own settings panel keeps working for live
tweaking.

**Four independent bugs found and fixed, each via live testing, not
assumption:**

1. **Wrong color format silently discarded.** Live devtools inspection
   (Browser Toolbox — needs both `devtools.chrome.enabled` *and*
   `devtools.debugger.remote-enabled`, the second easy to miss since only
   the first is commonly documented, plus a full restart for the debugger
   server to initialize) on the actual `zen-appcontent-wrapper` element
   showed `--mod-sameerasw-zen_transparency_color` resolving to all zeros
   despite the pref being set correctly in `about:config`. Root cause: the
   mod's preference-to-CSS-variable binding only accepts 8-digit hex
   (`#RRGGBBAA`, matching its own `"#00000000"` default) for this string
   pref — the CSS `rgba(0, 0, 0, 80%)` value first tried was accepted as a
   *valid preference* (about:config showed it fine) but silently zeroed out
   when bound to CSS. Fixed using `lib.toHexString`/`lib.fixedWidthString`
   to compute `#000000CC` from the shared `transparency.nix` opacity
   (0.80 → byte 204 → hex `CC`), so it stays driven by one source of truth
   rather than a hardcoded hex string.
2. **The mod's own box-shadow around the webpage view** (a multi-layer
   `box-shadow` in its `chrome.css`, meant to blend invisibly against an
   opaque white page) showed up as a stray rim once the backplate went
   transparent. Fixed via the mod's own `mod.sameerasw.zen_no_shadow`
   preference, set through the same `policies.Preferences` mechanism.
3. **`draw-border-with-background false` backfired at first, for a reason
   specific to Zen's own state, not the setting itself.** Tried first to
   stop niri's own focus-ring/border rendering as an opaque rectangle
   behind the translucent window — but for a CSD-less window (via
   `prefer-no-csd`, already enabled repo-wide since the original niri port)
   with no background *and* no fill, the ring/border space rendered as a
   literal transparent gap, indistinguishable at a glance from "no fix at
   all." Initially fixed by disabling `focus-ring`/`border` outright for
   Zen's window-rule instead. **Root cause found later** (via the identical
   fix landing cleanly for Nautilus — see the dedicated Nautilus section
   below): niri's own bundled `default-config.kdl` comments explain the
   bleed-through only happens because the ring has nowhere else to render
   for a window with no surrounding space — Zen is `open-maximized-to-edges`
   (zero gap, fills the whole output), so there's genuinely nowhere for the
   ring to go as long as that stays true, unlike Nautilus's normal tiled
   window with real gap space. **Reverted back to `draw-border-with-background
   false` anyway, at the operator's explicit request**, so Zen's config is
   already correct the moment `open-maximized-to-edges` is ever removed
   (making it a normal tiled window) — currently reintroduces the empty-gap
   artifact as a known, accepted tradeoff until/unless that happens.
4. **`open-maximized-to-edges` appeared not to work at all, across several
   rounds of live debugging** — for a while looking like a niri/Zen
   incompatibility (the mod's own docs only list KDE/Hyprland as
   confirmed-working on Linux for its own transparency, and niri's
   `open-maximized-to-edges` genuinely does require client cooperation per
   niri's own docs: "windows are aware of their maximized-to-edges status
   and generally respond by squaring their corners"). Ruled out via
   `niri msg windows` (needs `NIRI_SOCKET` exported manually over SSH —
   `systemctl --user show-environment | grep NIRI_SOCKET`, since an ad-hoc
   SSH shell has no session context for it, the same class of scoping
   issue as `gcr-ssh-agent`'s `SSH_AUTH_SOCK`): the reported `app_id`
   (`zen-twilight`) matches the existing regex fine, and the operator
   confirmed the rule *does* apply correctly outside the VM. The real cause,
   on the VM specifically: Zen briefly opens maximized (niri's rule firing
   correctly at window-open, exactly as documented — "applies once when a
   window first opens"), then snaps back to a smaller remembered size a
   moment later. Root cause: Zen's own `xulstore.json` (Firefox-family
   window-chrome-state persistence, tracks `sizemode`/width/height) had a
   remembered non-maximized geometry from earlier ad hoc live testing on
   that same profile, predating any of this session's rules — Zen restores
   it shortly after niri's one-shot open-time rule applies, and niri
   (correctly) honors the client's own subsequent resize request. Fixed
   operationally, not via Nix: deleting the relevant entry from
   `xulstore.json` in the VM's profile. Same *shape* of gotcha this repo has
   hit repeatedly before (`greeter.toml`, Noctalia's `settings.toml`
   sidecar) — mutable app state seeded once, silently overriding what's
   declared, until manually reset; will recur if the window is ever
   manually resized/un-maximized again.

**niri additions** (`home/niri/cfg/rules.kdl`, Zen's existing window-rule):
`opacity 0.80` (matching `transparency.nix`, kept in sync by hand — same
duplication precedent as `misc.kdl`'s cursor block) as a compositor-level
fallback independent of whether the mod's own CSS-based transparency
actually renders correctly on niri; `draw-border-with-background false`
per bug 3 above (currently shows the empty-gap artifact while
`open-maximized-to-edges` stays set — accepted, see bug 3).

**Verified live end-to-end** (VM): `about:config` shows all four Nix-set
prefs correctly; the workspace-background gutter renders as an
80%-opaque black tint (not fully see-through) with niri's blur showing
through at the edges; the box-shadow rim and the focus-ring/border gap are
both gone; Zen opens genuinely maximized-to-edges and stays that way after
the `xulstore.json` fix.

**Nautilus given the same transparency treatment, immediately after the Zen
work above, plus a real GTK-wide icon-theming gap found and fixed along the
way.** `home/niri/cfg/rules.kdl` gained a new window-rule for
`org.gnome.Nautilus`: `opacity 0.80` (matching `transparency.nix`, same as
Zen) and `draw-border-with-background false` — **not** the `focus-ring {
off }` / `border { off }` treatment Zen needed. The distinction, straight
from niri's own bundled `default-config.kdl` comments: the focus-ring/border
"solid background rectangle bleed-through behind semitransparent windows"
only happens because the ring has nowhere else to render for a window with
no surrounding space. Zen is `open-maximized-to-edges` (zero gap, fills the
whole output — confirmed live that `draw-border-with-background false` left
an empty transparent gap there, nothing for the ring to draw into), but
Nautilus is a normal tiled window with real gap space (`layout.kdl`'s `gaps
16`) for the ring to render into instead of bleeding through the translucent
content. **Verified live**: the focus-ring now shows correctly (a real
colored ring in the gap, no bleed-through) when Nautilus is focused.

Separately, changing the wallpaper turned up a real, GTK-wide gap: the
operator reported Nautilus's folder icons staying stuck on the *previous*
wallpaper's recolor (Papirus' folder-color symlinks, driven by Noctalia's
`papirus-icons` community template) even though other theming (GTK/Qt
colors, etc.) updated correctly. Confirmed via live checks that the
recolor itself was working fine on disk (`~/.local/share/icons/Papirus/48x48/places/folder.svg`
correctly symlinked to the new color, `Papirus-Dark`'s equivalent correctly
resolving through to it) — the problem was Nautilus's own already-running
process holding stale icon-theme state in memory. GTK apps only re-scan
icon-theme *content* changes on their own theme-*name* change signal (e.g.
switching from "Papirus-Dark" to something else and back), not on the
underlying files changing in place while the theme name stays constant —
confirmed empirically: killing and relaunching Nautilus picked up the
correct icons immediately, closing the window alone did not. Root-caused,
not just documented as a one-off, since the operator didn't want to run
`pkill nautilus` by hand every time they change wallpaper.

Fixed via Noctalia's own `hooks.colors_changed` — a genuinely
template-independent hook (confirmed by reading `application_services.cpp`/
`template_apply_service.cpp` in the `noctalia` flake input directly:
`TemplateApplyService`'s `setAfterApplyCallback`, invoked once *all*
builtin+community+user templates have finished for a given palette
resolution — a sibling `[hooks]` TOML section to `[theme]`, not a
per-template `post_hook` the way `theme.templates.user.<id>` entries have).
Investigated first whether `community_ids` entries (like `papirus-icons`)
could carry their own `post_hook` the same way `user` templates do — no:
confirmed via `config_types.h`/`config_schema.cpp` that `communityIds` is a
bare `vector<string>`, no per-entry table form parsed at all, unlike
`userTemplates`' `namedMap` with `pre_hook`/`post_hook`/`post_action`
fields. `home/noctalia.nix` now sets `hooks.colors_changed = [ "nautilus
-q" ]` — Nautilus's own documented quit flag (cleanly stops its
backgrounded D-Bus service, harmless no-op if it isn't running) rather than
`pkill`. **Verified live**: changing wallpaper now quits Nautilus
automatically, and reopening it shows the correctly-recolored folder icons
with no manual intervention.

**Vesktop given the same transparency treatment, immediately after
Nautilus — by far the most iterated of the three, and ultimately settled
on the simplest of the mechanisms tried, not the most sophisticated.**
Researched properly before writing any changes (per the operator's
request): Vesktop's own `transparencyOption` (Mica/Acrylic/Tabbed) is
Windows-only (`VesktopNative.app.supportsWindowsTransparency()`), but a
separate, platform-agnostic mechanism exists —
`VencordSettings.store.transparent` (confirmed via reading
`src/main/mainWindow.ts` directly, pinned nixpkgs version 1.6.5) sets real
`transparent: true` on the Electron `BrowserWindow` with no platform
check. The active Discord theme (Noctalia's "discord" community template,
`discord-midnight.css`, a fork of `refact0r/midnight-discord`) also has
built-in CSS toggles for exactly this (`--remove-bg-layer`,
`--transparency-tweaks`, `--panel-blur`, plus per-panel `--bg-*`
background variables), settable via `programs.vesktop.vencord.extraQuickCss`
(a genuinely separate output file from Noctalia's own generated theme, no
conflict — confirmed via `mkVesktopLikeModule.nix`).

Combining Electron's real transparency with the theme's CSS toggles went
through several rounds of live testing, each ruling out a real, specific
problem rather than guessing — worth summarizing since the tempting
"simpler" options in between are exactly what a future attempt would
retry:
- Electron transparency + `--remove-bg-layer` alone, no niri opacity: text
  stayed legible (CSS background changes don't touch text color), but
  most primary panels (server list, channel/DM list, chat, member list)
  stayed fully opaque — `--remove-bg-layer` only strips one specific
  wrapper element, not each panel's own background variable.
- Adding alpha to the theme's `--bg-3`/`--bg-4` variables to reach those
  panels: broke text/icon legibility, because `--bg-4` is *also* reused
  directly as a text/icon color in several places in the theme's base
  stylesheet (`--text-0`, `--control-expressive-text-*`, direct
  `color:`/`fill:` uses) — confirmed by reading every occurrence in the
  ~2372-line base stylesheet, not just a partial scroll (the first,
  incomplete check missed this).
- Overriding the more specific `--background-base-low/-lower/-lowest`
  variables directly instead (genuinely background-only, verified every
  reference) fixed the legibility problem and reached most primary panels
  — but at that point the CSS surface being depended on (a third-party,
  actively-maintained community theme with hundreds of interdependent
  custom properties) was judged too fragile to keep building on, and the
  operator asked to drop the whole CSS/Electron-transparency approach.

**Landed on**: niri's own `opacity` window-rule alone — the same
mechanism as Zen/Nautilus, matching `transparency.nix`, on Vesktop's
confirmed app-id (`vesktop`, lowercase, from the original Phase 6 port),
paired with `draw-border-with-background false` (Nautilus's treatment,
not Zen's — Vesktop uses plain `open-maximized`, which still respects
gaps/struts, giving real gap space for the focus ring). `home/vesktop.nix`
reverted entirely to its original Phase 6 form (no `extraQuickCss`, no
`VencordSettings.store.transparent`) — accepting niri's known tradeoff
(it dims text along with everything else, since it's a whole-frame
compositor multiplier with no concept of text vs. background) as simpler
and more robust than depending on a theme's CSS internals holding steady
release to release.

**Vesktop autostart, same session.** A `systemd.user.services.vesktop`
unit bound to `graphical-session.target` — not Vesktop's own native
autostart toggle (`src/main/autoStart.ts`), which on Linux (non-Flatpak)
just writes a mutable `~/.config/autostart/vesktop.desktop` file via a UI
action with no corresponding `settings.json` key, so it isn't something
Nix can declare cleanly anyway. Matches this repo's standing convention
for autostarted apps (recorded in `ARCHITECTURE.md`'s "Home Manager"
section back when `cfg/autostart.kdl` was removed): their own
`systemd.user.services.<name>`, not a niri `spawn-at-startup` line or an
app's own mechanism. Launches with the window showing, not minimized to
tray, per the operator's explicit choice (despite `tray`/`minimizeToTray`
both already being enabled).

**A real race condition, found and fixed via live testing, not
assumption.** The tray icon didn't appear in Noctalia's bar when Vesktop
autostarted this way, despite showing up fine on a manual launch after
login had fully settled. Investigated whether home-manager's own
`tray.target` (a stock unit, confirmed present: "Home Manager System
Tray") would solve this cleanly — it doesn't: reading its actual
definition (`modules/xsession.nix`/`modules/wayland.nix` in the pinned
home-manager rev) shows it's just `Requires=graphical-session-pre.target`,
reached essentially immediately, with no real ordering against any tray
host wired in. Checked every home-manager module that consumes or
provides it (waybar, trayer, polybar, stalonetray as hosts; pasystray,
kdeconnect, cbatticon, and others as consumers) — none of them get an
actual start-order guarantee from it either, since `Wants=`/`PartOf=`
relationships don't imply `Before=`/`After=`. Since Noctalia (the actual
tray host here) is a separate flake's plain `Type=simple` service, not
something this repo can add real dbus-readiness signaling to, there's no
clean systemd-level fix available. Settled for the pragmatic one instead:
`vesktop.service` orders `After = [ "graphical-session.target"
"noctalia.service" ]` (best-effort, not a guarantee) plus an
`ExecStartPre = "sleep 5"` — the sleep is what actually closes the race in
practice. **Verified live**: the operator confirmed the tray icon now
appears correctly on a fresh boot.


---

## Phase 7 — Extra features

### What the gaming stack ended up being, and what was argued out of it

The roadmap line was "Docker, Steam, Proton GE, Tailscale, gaming profile."
Three of those five changed on contact with the operator's actual
requirements.

**Proton GE became proton-cachyos.** The operator runs CachyOS and wanted
its Proton fork and its gaming kernel rather than the more commonly-packaged GE build. Neither is
in nixpkgs — verified against this repo's pinned revision, where the only
attribute matching "cachy" at all is `ananicy-rules-cachyos`. Both come
from [chaotic-nyx](https://www.nyx.chaotic.cx/)
(`github:chaotic-cx/nyx/nyxpkgs-unstable`), added as a flake input.

**Millennium was in the software-stack list and had no package.** There is
no `millennium` attribute in nixpkgs (there's an open packaging request,
nixpkgs#382086), but upstream ships its own flake at
`github:SteamClientHomebrew/Millennium?dir=packages/nix`, whose overlay
exports a `millennium-steam` — upstream's own steam derivation overridden
with Millennium's bootstrap shim preloaded — which drops straight into
`programs.steam.package`.

**Neither new input follows this repo's nixpkgs, for two different
reasons.** chaotic-nyx says so explicitly in its own docs: following
produces hash mismatches against its prebuilt cache, and for
`linuxPackages_cachyos` that means compiling a kernel from source.
Millennium pins a *specific nixpkgs commit* (not a channel) because its Bun
fixed-output derivation is version-sensitive and breaks when the revision
moves. The accepted cost is two more nixpkgs copies in the closure and a
Steam that trails ours by a patch release (`1.0.0.85` vs `1.0.0.87`) — the
same tradeoff already accepted for `noctalia` in Phase 3.

**What was proposed and dropped.** MangoHud, gamescope, gamemode, Lutris,
Bottles, goverlay, protontricks, ludusavi, steamtinkerlaunch and vkbasalt
were all offered and declined in favour of a minimal profile; the operator's
instruction was "keep the gaming profile minimal." Two are worth recording
because they'd otherwise be re-proposed:

- **goverlay is actively redundant, not merely optional**: it's a GUI for
  editing MangoHud's config file, and Home Manager has a `programs.mangohud`
  module. That's the same "app mutates a file Home Manager owns" collision
  as the starship/lazygit templates in Phase 5.
- **protonup-qt / protonplus are deliberately absent.** They are GUI
  downloaders that write Proton builds into `~/.steam` by hand — precisely
  the app-owned mutable state this repo's standing gotchas are about.
  `programs.steam.extraCompatPackages` does the same job declaratively.

**umu-launcher survived the cull for a specific reason.** It isn't a
launcher; it's the containerised runtime Heroic hands Proton games to.
Steam runs Proton inside pressure-vessel + the Steam Linux Runtime, whereas
Heroic on its own runs Proton bare against host libraries — the usual cause
of "runs under Steam, breaks under Heroic."

### The unfree allow-list was gated on the wrong thing

`modules/desktop/unfree.nix` was gated on `config.features.niri`, on the
reasoning (recorded in its own header comment) that every unfree package in
the repo was a GUI app. That stopped being true the moment a host wanted
`features.gaming` without a compositor: the allow-list would simply not
apply, and eval would fail with an unfree-license error pointing at nixpkgs
rather than at the gate. Moved to `modules/system/unfree.nix`, ungated,
bundled by `profiles/base.nix` — an allow-list entry costs nothing on a host
that never evaluates the package it names. This was a latent bug, not a
refactor: no host had yet combined the two flags.

**A second, unrelated unfree entry surfaced during verification**:
`hardware.xone.enable` pulls `xone-dongle-firmware`, Microsoft's
redistributable-but-unfree firmware blob for the Xbox Wireless Adapter.
Nothing in the option name suggests it, and it only appeared as an eval
failure a long way from `modules/hardware/controllers.nix`.

### Where the desktop's kernel and GPU control live, and why not in the profile

`profiles/gaming.nix` deliberately contains neither
`boot.kernelPackages = pkgs.linuxPackages_cachyos` nor `services.lact.enable`.
Both sit in `hosts/the-entertaining-nios-desktop/default.nix`, on the same
reasoning as the VM's `spice-vdagentd`: they describe *that machine* (a
Ryzen 5600 + Radeon RX 6600 box that runs games), not the role. A future
gaming host on different hardware shouldn't inherit a kernel choice from a
profile. AMD graphics otherwise need nothing declared — amdgpu and Mesa's
RADV are already the default — so `lact` (fan curves, clocks, undervolting)
is the only GPU-specific config the machine needs.

`modules/hardware/audio.nix` and `graphics.nix`, both long-planned, were
never created and shouldn't be: PipeWire arrives with
`programs.noctalia.recommendedServices.enable` (verified: `services.pipewire.enable`
is already true on the VM and false on the laptop, exactly tracking that
module), and the only graphics option the stack needs is
`hardware.graphics.enable32Bit`, which belongs with the thing that requires
it.

### Verification, and its honest limit

The gaming stack targets the desktop, which has no `nixosConfigurations`
entry (no `hardware-configuration.nix`, no secrets — it has never been
bootstrapped). So it cannot be eval'd where it actually lives. It was
instead verified by *temporarily* importing `profiles/gaming.nix` on the VM,
evaluating, and reverting — which confirmed the whole chain resolves:
`programs.steam.package` → `steam-1.0.0.85` (Millennium's),
`extraCompatPackages` → `proton-cachyos`, `pkgs.linuxPackages_cachyos.kernel`
→ `linux-7.1.8`, Heroic present in the user's packages. That is an
evaluation, not a boot: none of it has run on hardware, and per this repo's
own standing rule, eval passing is not verification. The first real test is
the desktop's bootstrap.

---

## Phase 8 — Long-term improvements

### nixfmt instead of alejandra

`ARCHITECTURE.md` recommended `alejandra` for formatting. It was not
adopted. Every `.nix` file in the repo had been hand-written in RFC 166
style (spaces inside braces, one attribute per line, expanded function
arguments) — alejandra's style differs (`{config, lib, ...}:`), so adopting
it would have reformatted all 40-odd files to gain nothing over the style
already in use. The check uses `pkgs.nixfmt`, which is what nixpkgs now
calls the RFC 166 formatter; `nixfmt-rfc-style` still resolves but warns
that it's an alias. Thirteen files needed reformatting to satisfy it, all
mechanical.

### The three lint checks, and what they were told to ignore

`nix flake check` now runs `format`, `statix` and `deadnix` as real
derivations, alongside a per-host `build-<hostname>` closure build derived
from `self.nixosConfigurations` (so a host can't be added without also being
checked). Two deliberate exclusions:

- **`hardware-configuration.nix` is excluded from all three.**
  `nixos-generate-config` writes those files, and this repo's rule is that
  they're never hand-edited — so making one satisfy a linter would be undone
  the next time a host is regenerated. Every finding deadnix reported
  repo-wide was in one of these files.
- **statix's `empty_pattern` and `repeated_keys` are disabled** in
  `statix.toml`. The first wants `_:` instead of `{ ... }:` for a module
  taking no arguments; the second wants `home.username`/`home.stateVersion`
  collapsed into one `home = { ... }`. Both contradict how this repo's
  modules are deliberately written (the repeated keys are separated by the
  comments explaining each), and a check that has to be argued with on every
  commit stops functioning as a gate. The one genuine statix finding — an
  assignment better written as `inherit (nixpkgs) lib` in `flake.nix` — was
  fixed rather than suppressed.

**The checks were negative-tested, not just run.** A deliberately broken
canary file was added and each check confirmed to actually fail on it
(unformatted source → `format` fails; an unused `let` binding → `deadnix`
fails; `cfg = cfg;` → `statix` fails), then removed. A lint check whose
file-selection expression silently matches nothing passes just as green as
one that works.

### CI is one command on purpose

`.github/workflows/check.yml` runs `nix flake check` and nothing else.
Every piece of validation is declared as a flake check, so CI and `just
check` run identical work by construction and there is no second pipeline to
drift. The one thing the workflow adds is the noctalia and chaotic-nyx
substituters: a NixOS host gets those from its own config
(`modules/desktop/noctalia.nix`, chaotic's own module), but a CI runner has
no such config, and without them the job would compile a Wayland/OpenGL
shell and a kernel from source.

Note this makes `nix flake check` genuinely expensive now — it builds two
full system closures. `just check-fast` (`nix flake check --no-build`) is the
routine local gate; the repo's own driver (`.claude/skills/run-nixos-dotfiles/driver.sh`)
already passed `--no-build` for the same reason.

### Role profiles do not import `base.nix`

`profiles/gaming.nix` originally imported `base.nix`, on the strength of
`ARCHITECTURE.md`'s line that role profiles "should import `base.nix` rather
than duplicate it." The operator pushed back: keep `base.nix` separate and
imported by every host directly. That's the rule now, and the old line was
conflating two different things — what it was actually guarding against is a
role profile *restating base's module list*, and a profile that simply
doesn't mention base isn't duplicating anything.

Two reasons it's the better shape, neither of them about evaluation (Nix
dedupes imports by path, so both arrangements produce an identical system):

- **Symmetry when reading a host.** Under the old arrangement the VM and
  laptop imported `base.nix` visibly while the desktop did not — you had to
  open `gaming.nix` to discover the desktop had a bootloader at all. Every
  host's `default.nix` should read the same way.
- **Role profiles stay purely additive.** Otherwise every future profile has
  to answer "does this one include base?", and eventually two of them answer
  differently.

The counterargument — someone forgets `base.nix` on a new host — is weak: a
host with no boot, users or nix modules fails loudly at eval, not silently.

## Post-Phase 8 — the zen-browser lock rot

### A rolling input broke CI on a commit that only touched documentation

The first red CI run this repo has had. The failing commit
(`4fde3ee`, a docs-only change) had nothing to do with the failure:

```
error: hash mismatch in fixed-output derivation '…-source.drv':
         specified: sha256-/a2mzPZM8dmbJxh9QEh0w2Xu1BmnO61eSbsL3skYweY=
            got:    sha256-XpBySYOCijbYMa6Vatploi9+q4LQceVVUDi9rCnnNVg=
error: 1 dependencies of derivation '…-zen-twilight-bin-unwrapped-1.22t.drv' failed to build
```

`home/zen-browser.nix` imports `zen-browser.homeModules.twilight-official`,
which tracks Zen's nightly. Upstream replaced the tarball behind the exact
revision `flake.lock` had pinned since 2026-08-04, so the fixed-output
derivation that fetches it started failing eleven days later. Zen is in
`home-manager-path`, which is in both host closures, so the rest of the log
was cascade — the two "failed to build" host derivations were collateral, not
two separate problems. Fixed by `nix flake update zen-browser`.

The important property: **this fails on a timer, not on a change.** Nothing in
the repo caused it and nothing in the repo would have prevented it. Left
alone it recurs every time the lock sits untouched for a week or so.

### `--no-build` is structurally blind to this

`.claude/skills/run-nixos-dotfiles/driver.sh check`, `just check-fast` and
`nix flake check --no-build` all passed against the broken lock, before and
after. They evaluate; they never fetch, so a fixed-output hash mismatch
cannot surface. The eval-only gate remains the right routine local check —
but a lock-file bump is exactly the change it cannot speak to, and needs a
full `nix flake check` before pushing.

### What was chosen, and what was ruled out

**Chosen: `.github/workflows/update.yml`**, a daily scheduled bump of the
`zen-browser` input that runs the full `nix flake check` and pushes
`flake.lock` only if it passes. This doesn't make the breakage impossible —
upstream can still break — it relocates it: the red run becomes a scheduled
maintenance job instead of the operator's next unrelated push, and the
one-day window is short enough that the tarball rarely rots at all. Pushing
straight to `main` from CI is consistent with the repo's solo, no-PR flow,
and is safe in the specific sense that the lock is only ever pushed after it
has been checked. GITHUB_TOKEN pushes don't trigger workflows, so this does
not loop back into `check.yml`.

It updates **only that input, by name**. Every other input is pinned by
revision and narHash and cannot rot in place; the rot needs a derivation that
fetches from a mutable URL. Bumping nixpkgs is a different kind of decision —
it changes what the machines run — and stays manual (`just update`).

Ruled out:

- **Switching to the `beta` channel** (`zen-browser.homeModules.beta`), whose
  releases are versioned and whose tarballs are stable. This would eliminate
  the failure class outright rather than merely shortening its window, and is
  the correct fix if the nightly ever stops being worth it. Not taken: the
  operator moved to `twilight-official` deliberately (see the comment block
  at the top of `home/zen-browser.nix`), and the tradeoff there hasn't
  changed.
- **A `pre-push` git hook running `just check`.** It converts a red CI into a
  red terminal, which is worth something, but it doesn't prevent the bump
  from being needed and it puts a multi-minute closure build in front of
  every push. The scheduled workflow addresses the cause; this would only
  soften a symptom.
- **Making CI tolerate the failure** (retry, `--keep-going`, pinning around
  it). A broken lock genuinely is broken — a host would fail the same way on
  `nixos-rebuild`. CI going red here is correct behaviour, and the fix is to
  make it go red somewhere less disruptive.

## Post-Phase 8 — moving Zen to `beta` and deleting the update workflow

### The reversal

`.github/workflows/update.yml` lived for one day. It was deleted, and
`home/zen-browser.nix` now imports `zen-browser.homeModules.beta` — the
option explicitly considered and *not* taken above, at the operator's
direction.

The reasoning that ruled `beta` out was that the move to
`twilight-official` had been deliberate and its tradeoff hadn't changed. It
had: the cost of the nightly was not yet visible when that channel was
chosen, and it turned out to be a scheduled CI job that writes to `main`,
plus a lock that must be re-checked with a full (closure-building) `nix flake
check` on a schedule the operator doesn't control. Being a few days ahead of
`beta` is not worth standing infrastructure. `beta` publishes immutable
per-release artifacts, so a locked revision stays buildable indefinitely and
the whole failure class disappears rather than being relocated — which the
entry above already identified as the difference between the two options.

With it gone, **every input is again pinned by revision and narHash with no
fetch-from-a-mutable-URL derivation among them**, and nothing in CI writes to
the repository.

### Two twilight-only workarounds went with the channel

Both were corrections for upstream naming bugs specific to the
`twilight-official` attribute, and both are wrong to keep on `beta`:

- **`xdg.desktopEntries.zen-twilight`** existed because that channel's
  packaged entry set `Icon=zen-twilight-official`, an icon the package never
  shipped. Verified against the built `beta` store path that its entry is
  self-consistent: `Icon=zen-browser`, `Exec=zen-beta`,
  `StartupWMClass=zen-beta`, and `share/icons/hicolor/*/apps/zen-browser.png`
  really is present. Nothing to correct, so the override is gone.
- **`home.sessionVariables.BROWSER = lib.mkForce "zen-twilight"`** existed
  because the flake's `default-browser.nix` derives `BROWSER = "zen-${name}"`
  from the *attribute* name, which was `twilight-official` while the binary
  was `zen-twilight`. On `beta` the attribute and the binary agree, so
  upstream's own value is already right.

`home/niri/cfg/keybinds.kdl`'s `spawn-sh "zen-beta || zen-twilight || zen"`
needed no structural change — it was written channel-agnostic for exactly
this reason — only a reorder so the live channel is tried first instead of
after a guaranteed miss.

The general rule this leaves: **when a channel changes, re-read the built
package's own `.desktop` and icon names rather than carrying its predecessor's
fixes forward.** A workaround for a bug that no longer exists is
indistinguishable from configuration until something breaks.

## Making the VM non-interactive

### The friction, and why it mattered

Verifying anything on `the-entertaining-nios-vm` needed a human twice per
cycle: a sudo password for every `nixos-rebuild switch` over SSH, and a
console login at the greeter before any GUI existed to test against. Root
SSH is off (`modules/system/ssh.nix`, `PermitRootLogin = "no"`) and the
`ol` account is password-gated for sudo, so neither was scriptable.

That is a bigger problem than it sounds, because this repo's own hardest-won
rule is that **eval passing is not verification** — every phase has shipped
a bug that only appeared when an app was actually opened. A verification
step that requires a human at a console twice is a verification step that
gets skipped, and the rule quietly stops being followed.

### What was added, all on the host and none of it in a module

Three settings in `hosts/the-entertaining-nios-vm/default.nix`:

- `security.sudo.wheelNeedsPassword = false` — makes
  `ssh ol@<vm> sudo nixos-rebuild switch …` run unattended.
- `services.greetd.settings.initial_session` — autologin into `niri-session`
  at boot, so a graphical session exists with nobody at the console.
  Upstream's noctalia-greeter module sets only `default_session.command`,
  at `mkDefault` (confirmed by reading its `nix/nixos-module.nix`), so this
  merges rather than conflicts. `initial_session` applies only to the first
  login after boot, so the greeter is still reachable by logging out — it
  stays testable.
- An `in-session` wrapper script — imports `WAYLAND_DISPLAY`, `NIRI_SOCKET`
  and the other graphical variables out of the session's systemd `--user`
  manager, then execs. This is the long-standing "an ad-hoc SSH shell has no
  session context" gotcha turned into one command.

**Host file, not a module or profile, and deliberately so.** Each of the
first two trades away a real security property. That trade is only
defensible for this specific machine — disposable, host-local libvirt
network, throwaway SSH key, holds nothing — and a module would make it
available to the laptop and desktop, which are none of those things. This is
the same reasoning that keeps `services.spice-vdagentd` in this file: it
describes one machine, not a role.

Passwordless sudo was left at the whole `wheel` group rather than an
allow-list of `nixos-rebuild`. An allow-list reads tighter but isn't:
rebuilding to an arbitrary flake path is already root by another name.

### The bootstrap is unavoidably interactive, exactly once

Applying the change that removes the password prompt still requires a
password-authenticated switch. There is no way around it from the
development machine, and it is worth stating rather than rediscovering.

### What this does not do

It makes the mechanics non-interactive; it does not make verification
automatic. Rendering, "does this look right", and anything visual still
needs eyes on the VM's display. The point is only to remove the friction
that made the live check expensive enough to skip.

## Post-Phase 8 — Zen was never actually the default browser

`home/zen-browser.nix` has set `programs.zen-browser.setAsDefaultBrowser =
true` since Phase 6, and checking it appeared to confirm it worked:
`xdg-settings get default-web-browser` on the VM answered
`zen-beta.desktop`, and `BROWSER` was `zen-beta` in the session environment.
Both were true. Neither was the setting doing anything.

The flake's `hm-module/default-browser.nix` writes fifteen
`xdg.mimeApps.defaultApplications` entries (http, https, text/html,
mailto, ...) pointing at `zen-${name}.desktop`, plus
`home.sessionVariables.BROWSER`. What it never does is set
`xdg.mimeApps.enable`, and home-manager's `xdg.mimeApps` module writes no
`mimeapps.list` at all while disabled. Nothing in this repo enabled it
either, so every one of those associations was computed and thrown away.
Confirmed by evaluating the option directly: `defaultApplications` held all
fifteen correct entries while `enable` was `false`.

What made it look correct:

- `BROWSER` is real, but most GUI applications ignore it and call
  `xdg-open`, which reads `mimeapps.list`.
- With no explicit association, xdg falls back to scanning
  `mimeinfo.cache`, and Zen was the only registered `x-scheme-handler/http`
  handler on the VM, so it won by default. That is an accident of what
  else is installed, not a setting — a second browser would have silently
  taken over, and the ordering was never guaranteed on a fresh host.
- The `~/.config/mimeapps.list` that did exist on the VM was written at
  runtime by Vesktop and `xdg-settings` (mode 0644, not a store symlink),
  and contained only `x-scheme-handler/discord`. The same app-owned-mutable-
  state shape as Noctalia's settings sidecar and Zen's own profile.

**Resolved** with `home/xdg-mime-apps.nix`: `xdg.mimeApps.enable = true`,
plus a restated `x-scheme-handler/discord = vesktop.desktop` (taking over
the file discards whatever was only recorded there at runtime;
`home/vesktop.nix`'s desktop entry advertises the scheme via `MimeType=`,
which makes Vesktop *a* handler, not the default), plus
`xdg.configFile."mimeapps.list".force = true`.

Three choices worth recording:

- **A separate module, not a line in `home/zen-browser.nix`.** `enable` is
  not a browser setting — it's the switch deciding whether *any* module's
  mime associations reach disk. Buried in one app's module it is a landmine
  for the next one. Follows `home/xdg-user-dirs.nix`, which exists for the
  same reason on the other half of XDG.
- **`force`, not a documented manual `rm`.** Home-manager's mime-apps module
  sets only `.source`, not `force` (checked in
  `modules/misc/xdg/mime-apps.nix` at the pinned revision), so a first
  activation over the pre-existing unmanaged file would abort with "existing
  file would be clobbered". Forcing keeps a rebuild convergent on every host
  with no hand step.
- **Zen's fifteen associations are not restated.** They arrive at
  `lib.mkDefault` from the flake, so they merge in and stay overridable.
  One of them is `text/plain = zen-beta.desktop`, which now actually
  applies — a `.txt` opened from Nautilus will open in the browser. Left as
  upstream has it, because there is no GUI text editor in this repo's stack
  to point it at instead (Neovim is terminal-only and deliberately not
  home-manager-managed). Override in `home/xdg-mime-apps.nix` if that
  changes.

Ruled out: setting `xdg.mimeApps.enable` inside `home/zen-browser.nix`
(scoping problem above); calling `xdg-settings set default-web-browser` from
an activation script (imperative, and writes the same mutable file this now
owns declaratively).

Verified live, not just by eval — the failure mode here was precisely one
eval cannot see. The closure was built locally, `nix copy`'d to the VM and
activated with `switch-to-configuration test` (avoiding the VM's
`~/.dotfiles` clone, which carries an unrelated uncommitted edit).
Activation completed with no clobber error; `~/.config/mimeapps.list` became
a store symlink; `xdg-mime query default` answered `zen-beta.desktop` for
http and https and `vesktop.desktop` for discord; and
`xdg-open https://example.com` actually opened a `zen-beta` window titled
"Example Domain — Zen Browser" in niri.

## Post-Phase 8 — Neovim as the default text editor

Follows directly from the `mimeapps.list` work above, which left
`text/plain = zen-beta.desktop` (upstream zen-browser's own default),
i.e. a `.txt` opened from Nautilus would open in the browser.

Two halves, and neither was in the state it looked to be in.

**`EDITOR`/`VISUAL` were already `nvim`, but only in zsh.** They were set
via `programs.zsh.sessionVariables` in `home/zsh.nix`, which exports into
interactive zsh and nothing else — a bash shell, a `sh -c` in a script, or
any tool shelling out to `$EDITOR` outside zsh saw them unset. Moved to
`home.sessionVariables` in `home/neovim.nix`, which reaches every shell via
`hm-session-vars.sh`. Verified on the VM: before the change `bash -lc 'echo
$EDITOR'` was empty, after it reports `nvim`, as does `sh`. Placed in
`home/neovim.nix` rather than left in `home/zsh.nix` because `EDITOR=nvim`
is a fact about Neovim, not about a shell. `home/git.nix` sets no
`core.editor`, so git picks this up with nothing to conflict.

**The GUI half needed a new desktop entry, not just an association.**
Neovim's packaged `nvim.desktop` is `Terminal=true`, which defers "find a
terminal to run this in" to the launcher — and in a bare niri session there
is nothing to defer to. glib picks a terminal from a hardcoded list (xterm,
gnome-terminal, konsole, …) that Ghostty is not on.

This was confirmed live *before* designing around it, and the failure is
worth recording because it is silent and actively misleading: at the time,
`xdg-mime query default text/plain` already answered `nvim.desktop` (by the
same `mimeinfo.cache` fallback accident described in the previous entry),
and `xdg-open /tmp/probe.txt` opened **Zen Browser**. It also left an
orphaned `nvim /tmp/probe.txt` running with no terminal attached — so glib
did try, got a process with no tty, and fell onward to the browser.

**Resolved** with `xdg.desktopEntries.nvim` in `home/neovim.nix`:
`Exec=ghostty -e nvim %F`, `Terminal=false`. Reuses the `nvim` entry id so
it shadows the package's own copy rather than putting a second, nearly
identical "Neovim" in the launcher — home-manager gives its generated entry
priority over the package's within the profile (verified: the active
`~/.nix-profile/share/applications/nvim.desktop` is the generated one).
Same override-an-existing-entry pattern already used by `home/vesktop.nix`.
`-e` is last in `Exec` because Ghostty treats everything after it as the
command to run.

The mime types were **checked, not guessed** — each was read off
`xdg-mime query filetype` against a real file on the VM. Worth doing: `.nix`
and `.conf` have no type of their own and are plain `text/plain`, while
`.toml`/`.yaml` are `application/toml`/`application/yaml` rather than the
`text/x-*` names one would assume. `text/html` is deliberately left with the
browser.

**Associations moved to live with each application.** `home/xdg-mime-apps.nix`
had briefly carried Vesktop's `x-scheme-handler/discord` entry; that moved
into `home/vesktop.nix`, so the rule is now uniform — that module owns the
*file* (`enable`, `force`), and each app declares its own associations in
its own module, the way the zen-browser flake's hm-module already did.
A central list would have to be kept in sync with every module that has a
desktop entry.

Verified live on the VM (built locally, `nix copy`'d, registered with
`nix-env -p /nix/var/nix/profiles/system --set` and activated with
`switch-to-configuration switch` — a real switch this time, not `test`, so
it survives reboot; the previous entry's `test` activation had already been
reverted by a reboot, which is exactly how the `Terminal=true` behaviour
came to be observed in the first place). `xdg-mime query default` answers
`nvim.desktop` for text/plain, application/json and text/markdown, still
`zen-beta.desktop` for https and `vesktop.desktop` for discord; and
`xdg-open /tmp/probe.txt` opened a Ghostty window running
`ghostty -e nvim /tmp/probe.txt`, with nvim actually editing the file.

## Making blur and transparency actually render

### The complaint, and what was actually wrong

"Theming and blur + transparency aren't functional." Theming turned out to
be fine — every template output was present and wallpaper-derived
(`qt6ct/colors/noctalia.conf`, both `gtk-*/noctalia.css`,
`ghostty/themes/noctalia`), and the palette tracked the wallpaper
correctly. Transparency was partly working. Blur was not working anywhere
it was supposed to, for two independent reasons, neither of which produces
an error message anywhere.

This was found by driving the VM over SSH and *looking* — `grim` through
the `in-session` wrapper (`docs/testing-on-the-vm.md`), screenshots pulled
back and inspected. `niri validate` passed the whole time, Noctalia's log
was clean, and every config file said what it was supposed to say.

### Reason one: niri's `opacity` window-rule cannot show blur

The decisive experiment was one screenshot with Ghostty and Vesktop tiled
side by side over the same wallpaper. Ghostty's backdrop was visibly
smeared; Vesktop's stars were pin-sharp — same compositor, same wallpaper,
same `background-effect { blur true }` window-rule matching both.

The difference is where the transparency comes from:

- **Ghostty** sets `background-opacity 0.80` itself, so its surface reaches
  the compositor with a real alpha channel. niri draws the blurred backdrop
  behind it and it shows through. This works.
- **Vesktop, Zen and Nautilus** get their transparency from niri's own
  `opacity 0.80` window-rule, which fades the entire already-composited
  window over whatever is actually behind it on screen. There is nothing
  translucent about the window's *background* for a blurred backdrop to
  appear through, so the real wallpaper shows through unblurred instead.

So `opacity` buys transparency and never blur. Both were tried against
`xray true`/`xray false` and with the wallpaper in and out of the backdrop
(`place-within-backdrop`); none of those variables changed it, which is
what ruled out every other explanation. This is now recorded in
`ARCHITECTURE.md`'s per-app transparency section, because the repo's own
comments had asserted the opposite in three places — including the
justification for the shared `0.80` in `home/transparency.nix`, which was
written as "enough for blur to actually read as blur" for windows that
could never have shown blur at any value.

### Reason two: Noctalia's panels were fully opaque, by default

Every Noctalia panel — launcher, control center, clipboard, session,
wallpaper picker — rendered as a flat opaque rectangle. The cause is a
single setting that had never been set: `shell.panel.transparency_mode`,
which defaults to `"solid"`. Setting it to `"glass"` (the other value is
`"soft"`) makes the panels translucent, and the wallpaper is then visibly
blurred through them. `bar.default.background_opacity` was already set and
was already working — confirmed separately by driving it to `0.15` and
watching the bar nearly vanish.

**Finding the config path took four wrong guesses and is worth recording.**
Noctalia's settings schema files this option under `panels`
(`settings.schema.panels.transparency-mode`) and its *values* under `shell`
(`settings.options.shell.panel-transparency.glass`). Neither is the config
path, which is `[shell.panel]`. `[panels]`, `[shell]`, `[panel]`, `[ui]`
and a dozen other candidates were all rejected.

What made this tractable is that Noctalia reports unknown config at
startup, in two distinguishable forms:

```
[WRN] [config] panels: unknown section
[WRN] [config] shell.transparency_mode: unknown setting
```

Writing candidate sections with a deliberate junk key in each, then reading
which ones came back as "unknown section" versus "unknown setting",
enumerates the real section list directly. The junk key mattered: an
early reading of "no warning, therefore accepted" was simply wrong — the
warning existed and had been missed — and a canary key is what caught it.
The general lesson is this repo's existing one about checks that cannot
fail, applied to a config file: **confirm the mechanism reports failure
before trusting its silence.**

### Reason three, minor: the layer-rule never enabled blur

`rules.kdl`'s Noctalia layer-rule set only `xray false`, with a comment
describing blur as "applied broadly then tuned down" for these surfaces.
The broad `blur true` it referred to is in a `window-rule`, which does not
apply to layer-shell surfaces at all — so the bar, panels, notifications,
dock and OSD had no niri-side blur enabled in the first place. Now set
explicitly.

### `xray false` was removed everywhere

The config forced `xray false` on every surface. Removing it is
pixel-identical — verified by diffing screenshots taken with and without
(`compare -metric AE` over the bar strip: 16 pixels of difference across
the whole region, all of it the clock). It is not free, though: niri's own
docs mark non-xray effects **experimental**, with the documented
limitations that they disappear during window open/close animations and
while dragging a tiled window, and they are much more expensive — non-xray
blur recomputes whenever a window moves or anything underneath changes,
while xray blurs the wallpaper once and reuses it.

The reason there is no visual trade-off is specific to this setup: the
wallpaper sits in niri's backdrop (`place-within-backdrop true`), so for
these surfaces there is nothing below them *except* the wallpaper, and
xray and non-xray sample the same pixels. If a future config wants blur
that picks up other windows underneath, `xray false` is what turns that
on — at the cost above.

### Verification note

Every claim here was checked on the VM against screenshots, not against
eval. `nix flake check` cannot see any of it: all four problems were
configuration that evaluated perfectly and rendered wrong.

## Unifying the visual style, and turning blur/transparency off

### The complaint, and what was actually wrong

The ask was to make niri, Noctalia and the apps "all have a similar
style". The obvious reading — that colors were inconsistent — turned out
to be wrong. Color was already the *most* unified thing in the repo:
Noctalia's template pass drives fifteen targets off the wallpaper palette
(five builtin, seven community, three custom), and every app anyone would
notice was already on it.

What had never been declared anywhere was **shape, typography and
density**. Three concrete disagreements, all of them invisible to eval:

- **Corner radius.** niri rounded every window to 20px
  (`rules.kdl`'s `geometry-corner-radius`), Noctalia's bar to its own
  default of 12, adw-gtk3 to whatever libadwaita ships, and Qt to nothing
  at all — qt5ct/qt6ct run the Fusion style, which is square-cornered.
- **Typography.** `modules/system/fonts.nix` installed exactly one font,
  JetBrains Mono Nerd, and only Ghostty ever referenced it. Noctalia's
  `shell.font_family` was undeclared (its default is the literal string
  `"sans-serif"`), `gtk.font` was undeclared, and Qt's font was
  undeclared. Every one of those independently resolved through
  fontconfig to whatever ranked first — DejaVu Sans. The whole GUI was
  running on a fallback nobody had chosen.
- **Borders and shadows.** `shell.panel.borders`, `shell.panel.shadow`
  and `shell.shadow.{direction,alpha}` were all undeclared defaults.

None of this is a bug in the ordinary sense. Every value was individually
"correct"; nothing recorded that any of them had been *chosen*, so
nothing stopped them disagreeing.

### `bar.default` looked wrong and is right

Worth writing down, because it will look like a bug again. The pinned
Noctalia's own `example.toml` documents the bar as `[bar.main]`, while
`home/noctalia.nix` writes `[bar.default]`. The repo is correct: bars are
arbitrary-named TOML tables, and `"default"` is the built-in one —
`src/config/config_migrations.cpp` seeds exactly that name for a config
with no `[bar]` table at all ("A config with no [bar] table at all uses
the built-in default bar, so seed that one"). `main` is just the name
upstream's example happens to give its example bar. Don't "fix" this.

### Where the shared vocabulary lives, and why not in its own file

A standalone `home/style.nix` — the obvious mirror of
`home/transparency.nix` — was considered and rejected. The problem it has
to solve is that `home/niri/cfg/*.kdl` are deliberately out-of-store
symlinks into the operator's live `~/.dotfiles` clone
(`docs/live-dotfiles.md`), and a static KDL file cannot read a Nix value.
A token file in Nix would leave niri's radius hand-duplicated, which is
the drift the change exists to remove.

Noctalia can reach it. Its template engine already writes
`~/.config/niri/noctalia.kdl` (focus-ring and border colors), so the
mechanism for "generate KDL that niri includes" was already proven in
this repo. The `style` block therefore lives in `home/noctalia.nix`, and
a second custom user template — `niri-style` — renders the shape half.

The one non-obvious part: the template's *input* is generated by Nix
(`pkgs.writeText`) rather than checked in as a static `.tmpl` alongside
the starship/lazygit/neovim ones. That is what keeps `style` the single
source of truth — a checked-in template would have the radius written in
it a second time, reintroducing exactly the duplication being removed.

### The new include had to be seeded, or it would brick a fresh host

Adding `include "./noctalia-style.kdl"` to `config.kdl` reintroduces a
failure this repo has already hit once: a genuinely fresh
`nixos-anywhere` install of the VM had niri refuse to start on first
login with `failed to read included config from ".../noctalia.kdl": No
such file or directory`, because greetd launches niri long before
Noctalia's first re-theme pass exists to write the included file.

A missing include is **fatal to niri**, not a warning — confirmed
directly rather than assumed (see verification below). On a host whose
only way back in is a TTY, that is not an acceptable first-boot risk.

`home.activation.seedNiriStyle` therefore copies the same generated file
into place at every Home Manager activation. Notes on its shape:

- A plain `cp`, not an `xdg.configFile`. Noctalia's template engine must
  be able to **write** this path, and a read-only Nix store symlink is
  precisely what broke `noctalia.kdl` before.
- Unconditional, not `cp -n`. The content is generated from `style` and
  contains no palette data, so Noctalia's own render is byte-identical —
  there is nothing to preserve, and a create-if-missing seed would
  silently fail to propagate a changed `style.radius`.
- Same shape as `home/gtk.nix`'s `seedPapirusIcons`, for the same reason:
  seed a real, writable file that a runtime tool then owns.

### Duplicate top-level nodes in niri KDL are fine

A `layout { focus-ring { ... } }` block was initially left out of the
generated file out of caution, on the theory that `cfg/layout.kdl`'s
existing top-level `layout` node would make a second one a duplicate-node
error. That caution was unnecessary: Noctalia's own builtin `niri`
template already emits a second top-level `layout {}` (its
`assets/templates/niri/niri.kdl` is nothing but one), and that has worked
all along. niri merges them.

The generated file still only carries the `window-rule`, because radius
is the only shape token there is a second consumer for. The reasoning is
recorded here so the next person doesn't re-derive the wrong constraint.

### Typography is one lever, not five

`fonts.fontconfig.defaultFonts.sansSerif` is what actually unifies UI
type, and it is why there is no per-app Qt font setting anywhere. Every
toolkit ends up asking fontconfig to resolve a generic family: Noctalia
asks for `"sans-serif"`, GTK's default `gtk-font-name` is `"Sans 10"`,
and Qt's default resolves the same way. Setting the generic default fixes
all three at once.

This matters especially for Qt, where the per-app route is closed:
qt5ct/qt6ct store the font as a serialized `QFont` blob
(`@Variant(...)`), which cannot be written as plain INI text through
home-manager's `qt5ctSettings`. Falling through to fontconfig is the only
clean way to get Qt onto the same family.

It lives at the NixOS level rather than in `home/` for the same reason
`modules/desktop/theming.nix` installs cursors system-wide:
noctalia-greeter runs before login, outside any user's Home Manager
profile, so a user-scoped fontconfig setting would leave the greeter on a
different font from the session it launches.

**Adwaita Sans** was chosen over Inter, and the choice turned out to be
narrower than it looked: nixpkgs' `adwaita-fonts` describes itself as
"Adwaita Sans, a variation of Inter, and Adwaita Mono, Iosevka customized
to match Inter". It is simultaneously the native match for the
adw-gtk3/libadwaita half of the stack and the neutral-modern-sans option.
JetBrains Mono Nerd stays as the monospace font — Adwaita Mono carries no
Nerd Font patches, which Starship and eza depend on.

`serif` is deliberately left unset. It is not a UI surface; it is what a
web page asks for when it genuinely wants a serif, and aliasing it to a
sans would be a content bug wearing theming's clothes.

### Blur and transparency, off but not deleted

Turned off at the operator's request. Neutralized rather than removed,
because the machinery encodes findings that took months to establish and
are not recoverable by re-reading the code (see the previous section).

The single load-bearing value is `home/transparency.nix`, now `1.0`. That
one number neutralizes every client-side transparent surface at once, and
client-side alpha is the half that matters — niri can only blur behind a
surface that has some. With it at 1.0 the compositor-side rules would be
inert even if they were still active.

They are commented out anyway, so the intent is legible rather than
implied: the three blur blocks in `rules.kdl`, the tuning block in
`misc.kdl`, and the three `opacity 0.80` window-rules.

`home/zen-browser.nix` got a small refactor rather than an edit-in-place.
Its four transparency prefs now derive from `transparent = opacity < 1.0`
instead of being hardcoded `true`, so they flip with the shared value in
both directions. Without that, `zen_bg_color_enabled` would have stayed
on while `zen_transparency_color` computed to `#000000FF`, painting Zen's
chrome opaque black instead of letting Noctalia's own template theme it —
a strictly worse outcome than before the change.

Re-enabling everything is: `transparency.nix` back to `0.80`,
`shell.panel.transparency_mode` back to `"glass"`, and uncommenting the
four KDL blocks.

### Verification, and its honest limit

Beyond `nix flake check` (both hosts, the ISO, and all three lints):

- The generated `config.toml` was built and read directly, confirming
  `[shell] font_family = "Adwaita Sans"`, `[shell.panel]`'s
  `borders`/`shadow`/`transparency_mode = "solid"`, `[bar.default]`'s
  `radius = 16` and `background_opacity = 1.0`, and the
  `[theme.templates.user.niri-style]` entry. This caught a real bug in an
  intermediate version, where the `shadow` block landed as a top-level
  `[shadow]` instead of nesting under `[shell.shadow]` — a mistake
  Noctalia reports only as a single startup warning line, so it would
  have looked exactly like working.
- The full niri config was **assembled and validated against the real
  niri binary** (`niri validate`) with both generated includes in place —
  the `noctalia.kdl` colors and the new `noctalia-style.kdl` — and
  reported `config is valid`.
- That validation was then canaried, per this repo's own rule that a
  check which cannot fail is worse than none: replacing the radius with a
  string made `niri validate` fail *inside `noctalia-style.kdl`*, proving
  the new include is genuinely parsed rather than silently ignored.
- The same run incidentally confirmed the missing-include failure mode
  first-hand: before `cfg/input.kdl` (Nix-generated, not in the repo
  tree) was copied in, niri refused the whole config. That is the exact
  behaviour the seed activation exists to prevent.

The limit is the usual one, and it is real: **none of this has been seen
on a screen.** Whether Adwaita Sans at size 11 actually sits well next to
Noctalia's bar, and whether radius 16 reads as one family across niri's
windows and the bar, are judgements only a live session can make. Both
are one-value changes — `style` in `home/noctalia.nix`, and the font size
in `home/gtk.nix` — if they look wrong.

---

## Bringing the desktop host up to installable

The desktop was a scaffold: `/dev/CHANGEME`, no `nixosConfigurations` entry,
no `hardware-configuration.nix`, no secrets, and no `modules/desktop/*`
imports at all, so installing it would have produced a gaming machine with no
graphical session. This closes
everything that doesn't physically require the installer or a drive that
isn't plugged in.

### The machine

The scaffold was already written for this exact box (16 G swap,
`linuxPackages_cachyos`, `lact` for an RX 6600) and the hardware confirms it:
ASRock B550M Pro4, Ryzen 5 5600X, 15.5 GiB RAM, Navi 23 (RX 6600), UEFI.

Worth recording because the two real hosts are easy to conflate on paper:
this one is AMD, while
`hosts/the-entertaining-nios-laptop/hardware-configuration.nix` declares
`kvm-intel` and an `rtsx_pci_sdmmc` card reader. Two genuinely different
machines, not two names for one.

### Why a `/dev/disk/by-id/` path, not `/dev/nvme0n1`

The placeholder existed because "the real device name is only knowable from
an installer environment" — but that framing accepts a hazard it doesn't need
to. Kernel enumeration order is not a promise, so `/dev/nvme0n1` resolved
from *this* boot is not guaranteed to name the same disk from the installer's
boot. `/dev/disk/by-id/nvme-Samsung_SSD_980_1TB_S649NL0T998840Y` encodes the
model and serial, so it either matches the intended disk or matches nothing.
For a step whose failure mode is "silently formats the wrong drive", that
asymmetry is worth the longer string.

The same device also appears as `nvme-eui.002538d921a42377` and as a `…_1`
suffixed duplicate of the chosen name. All three are the same disk.

### The second disk: ext4, `nofail`, and a placeholder that stays

The 2 TB drive is bulk storage for games and video. Deliberately plain ext4
on a single partition rather than btrfs: nothing there wants snapshots
(`features.snapshots`' snapper configs cover `/` and `/home` only) and a
library of already-compressed media is CPU spent for nothing under
`compress=zstd`.

`mountOptions = [ "nofail" ]` is load-bearing rather than defensive habit.
This is a secondary drive on a machine that boots fine without it; without
`nofail`, systemd makes the mount a requirement of `local-fs.target` and a
missing or failed drive drops the entire boot to an emergency shell.

Its device was `/dev/CHANGEME-storage` for as long as the drive was not
attached — there was no `by-id` path to read, and obviously invalid beats
plausibly wrong. The drive is now physically installed, and the placeholder
is resolved to `/dev/disk/by-id/ata-ST2000DM008-2FR102_ZK3055P8` (Seagate
ST2000DM008, serial ZK3055P8), read from `ls -l /dev/disk/by-id/` on the live
CachyOS install. It arrives carrying one NTFS partition labelled `Extra` from
that life; `disko` destroys it, so anything worth keeping has to come off
first.

### The 500 GB SATA SSD is deliberately absent from `disko.nix`

It holds the live CachyOS install. Leaving it undeclared means
`nixos-anywhere` never touches it, so after the install it is still a
bootable, working system reachable from the firmware boot menu — a real
fallback during the period when the new NixOS install is unproven. Declaring
it as extra storage would have wiped exactly the thing worth keeping.

### `/mnt/storage` plus a symlink, and why neither half lives in `home/`

`/mnt/storage` is the conventional spot and keeps the path machine-level
rather than tied to the `ol` user; the `~/Storage` symlink is what makes it
one click away in Nautilus and in file dialogs. Mounting directly at
`/home/ol/Storage` was considered and rejected: it puts a mountpoint inside
snapper's `@home` scope, and a drive that drops out then looks like an empty
folder rather than a missing disk.

Both the ownership rule and the symlink are `systemd.tmpfiles.rules` in the
host's own `default.nix`, for two separate reasons. disko formats ext4 but
leaves its root directory owned by `root`, so something has to chown it. And
the symlink cannot live in `home/`: that entry point is machine-agnostic
(there is no per-host Home Manager module), so a symlink declared there would
dangle on the VM and the laptop. Same reasoning that already keeps this
host's kernel and `lact` in its own `default.nix`.

### The flake entry was added before the machine can boot

`checks` is derived from `self.nixosConfigurations`, and the desktop is the
only host importing `profiles/gaming.nix`. So until now nothing built the
Phase 7 gaming stack at all — `CLAUDE.md` recorded it as eval-only precisely
because of the missing entry, and the workaround was temporarily importing
`profiles/gaming.nix` on the VM. Adding the entry converts that into a real,
permanent closure build in CI. The cost is a slower `nix flake check` pulling
from chaotic's and Millennium's own substituters; the benefit is that the
gaming stack can no longer rot unnoticed.

The host evaluates without `secrets.nix`: `modules/system/users.nix` only
sets `hashedPasswordFile` if a `password-hash` secret exists, and
`modules/system/ssh.nix` gives key-only login from `vars.user.sshPublicKey`.
`secrets.nix` cannot simply be imported early and left inert —
`defaultSopsFile = ./secrets/secrets.yaml` is a path literal, so importing it
before the file exists is an eval error.

### GNOME, COSMIC and Plasma were evaluated for this host, and niri kept

Since this machine is primarily for gaming and video, a conventional desktop
environment was considered. Against the pinned nixpkgs the options were real
and current — GNOME 50.2, COSMIC 1.5.0, KDE Plasma 6.7.3, all with
first-class NixOS modules — and Plasma in particular has the strongest
gaming story (mature HDR, per-display VRR, an explicit tearing-allowed mode).

niri + Noctalia was kept anyway. Worth recording what the switch would have
cost, since the reason is structural rather than aesthetic: `features.niri`
is not really a niri flag. It gates the entire graphical layer — every GUI
app module (`home/vscode.nix`, `zen-browser.nix`, `vesktop.nix`,
`feishin.nix`, `obsidian.nix`, `nautilus.nix`, `xdg-mime-apps.nix`,
`xdg-user-dirs.nix`) as well as niri, Noctalia, greetd and the GTK/Qt/cursor
theming, and `ARCHITECTURE.md` documents it that way. A second desktop
environment therefore can't just be added; the flag has to be split first —
the shape agreed on was an enum (`features.desktop = null | "niri" | …`),
gating shared app modules on `!= null` and session-specific ones on the
value, which makes mutual exclusion structural instead of an assertion. That
refactor is not needed now, but it is the entry point if a DE swap is ever
revisited.

### The desktop's SSH key: real, per-host, passphrase-less

`hosts/the-entertaining-nios-vm/secrets.nix` already had the mechanism —
provision an SSH private key through sops straight to `~/.ssh/id_ed25519`
(owner `ol`, mode `0400`) and let the GCR agent `programs.niri` already runs
pick it up at login, with no module and no `features.*` flag involved. The
desktop reuses it unchanged. What differs is the key: the VM deliberately
only ever gets a throwaway, while this is a real `ol@the-entertaining-nios-desktop`
identity intended for GitHub.

Per-host rather than one shared key, and separate from `variables.nix`'s
`sshPublicKey`: those are three different jobs. The bootstrap key reaches
installer ISOs, the host key is regenerated by NixOS on every reinstall, and
this one authenticates the operator to GitHub *from this machine* — so it can
be revoked there without disturbing any other host.

No passphrase, deliberately. What actually protects the key is the host's age
key at `/var/lib/sops-nix/key.txt`, staged in by
`nixos-anywhere --extra-files` and readable only by root: anyone who can read
that decrypts the SSH key regardless of a passphrase. A passphrase would also
have to be typed once per boot chain by hand, since there is nowhere
declarative to keep it — the encrypted-at-rest guarantee is already provided
one layer down. The trade is reversible with `ssh-keygen -p` and a re-encrypt;
nothing in the config depends on it.

Round-tripped before committing: `sops decrypt` of the stored value, fed back
to `ssh-keygen -y`, reproduces the same public key.

## Moonshine on the desktop — remote desktop and game streaming

Goal: reach the desktop from a Moonlight client with nobody logged in at the
machine, and get a full niri desktop rather than just a game.

### Why Moonshine rather than Sunshine

Sunshine captures an existing session, which means somebody has to be logged
in at the machine and the stream shows whatever is on the physical screen.
Moonshine is headless by design: every stream gets its own isolated
compositor, spun up fresh, and what Moonlight lists as an "app" is just a
command Moonshine runs inside it. A full remote *desktop* therefore isn't a
special mode — it's an app entry whose command happens to be a compositor
session launcher.

### The upstream flake does almost all of it

`github:hgaiser/moonshine` ships `nixosModules.moonshine`, and it is not a
thin wrapper: it already does lingering (`users.users.<user>.linger`), the
`uinput`/`uhid` kernel modules, the udev rules, `users.groups.moonshine` for
the sleep-inhibit polkit rule the package itself ships, `hardware.graphics`
plus the moonshine-wsi Vulkan layer installed into `/run/opengl-driver`
(where the loader scans regardless of environment — a systemd system service
has no `XDG_DATA_DIRS`, and without it everything silently falls back to
XWayland rendering), and the system unit with `XDG_RUNTIME_DIR` and
`DBUS_SESSION_BUS_ADDRESS` bootstrapped the way upstream's
`start-moonshine.sh` does by hand.

So `modules/services/moonshine.nix` is thin on purpose. It imports that
module — in the one file that consumes it, the same rule
`modules/programs/steam.nix` follows for chaotic/millennium — and adds only
what is genuinely this repo's business: which user, the app list, two group
memberships, and one polkit rule.

The input *does* `.follows` this repo's nixpkgs, unlike noctalia/chaotic/
millennium. Those three don't follow because following costs them a binary
cache; Moonshine publishes none, so there is nothing to lose and a fourth
nixpkgs in the closure to avoid. The cost is real either way: ~300
derivations built from source, which the full `nix flake check` closure-build
for the desktop now pays for. `--no-build` (so `just check-fast`, so
`driver.sh check`) is unaffected.

### Three things the obvious approach gets wrong

**A `home/moonshine.nix` writing `~/.config/moonshine/config.toml` would be
read by nothing.** The upstream module generates the TOML into the store and
passes it to the daemon as argv, and Moonshine only ever writes a config of
its own when the given path doesn't exist. All configuration goes NixOS-side
through `services.moonshine.settings`. This is also why the service is a
system unit rather than a user one: `nixos-rebuild switch` only manages the
lifecycle of system units, so as a user unit every config change would need a
manual `systemctl --user restart`.

**A polkit rule dropped into `/etc/polkit-1/rules.d` is read by nothing
either.** nixpkgs builds polkit with its rules directory under
`/run/current-system/sw/share`. `security.polkit.extraConfig` is the route.

**The module asserts on an underived uid.** It reads
`users.users.<user>.uid` to locate `/run/user/<uid>` and to order itself
after `user@<uid>.service`, and this repo had never declared one — the
primary user's uid was left to be allocated. `modules/system/users.nix` now
pins `uid = 1000`, which is the value the first normal user gets on every
host here anyway, so it changes nothing on disk while making the fact
declared. Preferred over hardcoding `services.moonshine.uid` in the service
module, which would have put an unexplained literal in the wrong file.

### GNOME was never on the table

Tried first, and it black-screens: Mutter grabs the DRM device rather than
nesting inside Moonshine's compositor, unlike the Sway/COSMIC examples in
upstream's TIPS.md. GNOME 49 removed `--nested` from Shell/Mutter outright
and GNOME 50 dropped the X11 backend, killing the `gnome-xorg` fallback too.
The replacement, `gnome-shell --devkit --wayland` (needs `mutter-devkit`), is
a development tool for testing Shell extensions, not a supported way to run a
real session — no session-manager or portal integration, no autostart. Not
worth carrying.

Debugging note for next time, since it cost the most time: the apps Moonshine
launches run as *transient* units in the user manager, so their output is in
`journalctl --user -u moonshine-session.service`, not in the system service's
log. And by default apps are launched with `StandardOutput=null`, so a
failing app produces no diagnostics at all — every entry here sets
`stdout`/`stderr` to `"journal"` for that reason, cheap insurance on a stack
that has never run on hardware.

### niri, and the one caveat

niri is a Smithay compositor with a supported nested (Winit) backend, which
it auto-detects with no flag — the same category as the Sway/COSMIC examples
that already work. `niri-session` rather than bare `niri`: launched as one of
Moonshine's transient units it detects that (`MANAGERPID` set,
`SYSTEMD_EXEC_PID` equal to its own pid) and execs `niri --session`, which
does the systemd/D-Bus session setup a display manager would normally
provide. greetd never sees this session, so nothing else would do it.

The caveat, verified by reading the `niri-session` script: `niri --session`
does `systemctl --user import-environment` and drives
`graphical-session.target` in the *same* user manager as a local login.
Streaming the desktop while also logged in at the machine means two niri
instances contending over that target and over `WAYLAND_DISPLAY`. The
headless case — the one lingering exists for — is clean. Not worked around,
because working around it would mean giving up the session setup that makes
portals and Noctalia work at all.

### Tailnet only

`openFirewall` is left `false`. `modules/services/tailscale.nix` already puts
`tailscale0` in `networking.firewall.trustedInterfaces`, so Moonshine is
reachable over the tailnet — already authenticated and encrypted — without
opening TCP 47984/47989/48010 and UDP 47998/47999/48000 to the LAN. Upstream
is explicit that Moonshine is not designed for untrusted networks. Flipping
the flag is the escape hatch for a client that can't be on the tailnet.

### The app entries

`Desktop` is the point of the exercise. `Steam` carries upstream's
recommended `pre_command` (TIPS.md, issue #134): Steam is single-instance per
user, so with a desktop Steam already running the `steam://` URL is forwarded
to *it* — Big Picture opens on the physical screen and the stream dies with a
503. The pre-command asks any running Steam to quit and waits up to ~30s.
Note it therefore closes a desktop Steam session when a stream starts.

`Heroic` covers the rest of the library — Epic, GOG and Amazon — launched
with `--console`, Heroic's console mode: a controller-driven, TV-shaped UI
that swaps the normal sidebar layout for a full-viewport one, which is the
right shape on the end of a stream. The flag was verified rather than
assumed, by grepping Heroic 2.22.0's `app.asar`: the main process reads it as
`process.argv.includes("--console")`, next to `--fullscreen` and `--no-gui`,
and the renderer keys a distinct `consoleContent` layout off it. `--fullscreen`
is available as well if the window ever comes up smaller than the stream.

Heroic is named from a *different profile* than the entries around it:
`/etc/profiles/per-user/ol/bin/heroic`, not `/run/current-system/sw/bin/...`.
The two are different things — the latter is `environment.systemPackages`,
the former is Home Manager's `home.packages`, and Heroic is a Home Manager
package (`home/heroic.nix`). That path only exists because
`home-manager.useUserPackages` is on; see the entry below, which turned it
on. It was briefly a store path via `lib.getExe` while the flag was still
off, since back then `home.packages` lived in the user's own
`~/.nix-profile` and no system unit could name them at all.

Steam stays on the system path deliberately: `programs.steam` installs a
*wrapped* Steam there, and the unwrapped derivation would be the wrong thing
to launch.

Both launcher entries are gated on `config.features.gaming`, not just on
`features.moonshine`. The two flags are independent, and `features.gaming` is
what installs Steam and Heroic in the first place — without the guard, a
host that streamed but didn't game would advertise two entries in Moonlight
whose commands point at binaries that were never installed, which is exactly
the silent-failure mode the `stdout`/`stderr` settings exist to mitigate.
Verified by `extendModules`-ing the host with `features.gaming = false`: the
app list drops from `["Desktop","Steam","Heroic","Shutdown"]` to
`["Desktop","Shutdown"]`.

`Shutdown` needs two independent things, which is easy to conflate: the
polkit rule grants the *authorization* (Moonshine launches apps from a
context polkit doesn't consider an active interactive session, so
`systemctl poweroff` otherwise fails with `InteractiveAuthorizationRequired`),
while `-i` governs whether systemd proceeds despite *other* sessions and
inhibitors. Both are required.

Two group memberships, for unrelated reasons. `input` because streamed games
read the virtual gamepad/keyboard/mouse Moonshine creates through inputtino —
an active local session would get that via the seat's ACLs, but the headless
case has no active seat and upstream's module deliberately doesn't grant it.
`moonshine` because that is the group upstream's own polkit rule is scoped
to, which is what lets Moonshine hold a block-type sleep inhibitor for the
duration of a stream; without it streaming works but the host may suspend
mid-session.

### Box art: declared, not resolved

Moonlight showed all four entries as blank cards. Moonshine does try to fill
that in by itself — `resolve_missing_boxart()` in `moonshine-core`'s
`app_scanner` walks the XDG icon directories for a file whose stem matches
the app's own lowercased title — but that can never fire here, for two
independent reasons:

- **The search path is empty on NixOS.** The resolver builds its roots from
  `XDG_DATA_HOME` and `XDG_DATA_DIRS`, falling back to `/usr/local/share`
  and `/usr/share` when the latter is unset. A systemd *system* service gets
  no `XDG_DATA_DIRS` — upstream's own module says so in a comment, which is
  why it installs the Vulkan WSI layer into `/run/opengl-driver` rather than
  relying on the variable — and neither of the fallbacks exists on NixOS.
  Setting `XDG_DATA_DIRS` on the unit would fix this half, but only this
  half.
- **Half the titles aren't application names.** "Desktop" and "Shutdown"
  describe what the entry *does*; no icon is named after them. Even with the
  search path repaired, the resolver would light up Steam and Heroic and
  leave the other two blank.

So each entry declares its `boxart` outright. The path is pinned per entry
rather than scored by a resolver, and the two non-application entries get an
icon chosen for what they mean.

Papirus-Dark, the same theme `home/gtk.nix` sets for the session, so a
streamed machine looks like itself. It ships SVG only and Moonshine's
decoder handles raster formats only (`png`/`jpg`/`jpeg`/`webp`/`bmp`/`ico`),
so a small `runCommand` rasterizes each with `rsvg-convert` at build time.
600px square, because 600 is Moonshine's own `BOXART_WIDTH`: it letterboxes
anything that isn't 600x801 onto a transparent canvas of that size, so
rendering at the width means it centres the icon without rescaling it.
Interpolating the results into `settings` puts store references in the
generated config TOML, which is part of the system closure — they can't be
garbage-collected out from under a running daemon.

Steam, Heroic and Shutdown map to `steam`, `heroic` and `system-shutdown`.
"Desktop" was going to be `devices/video-display`, the obvious generic, but
rendering it first showed why that was wrong: it is a near-black monitor on
a transparent background, which vanishes into Moonlight's own dark app grid.
`apps/preferences-desktop-remote-desktop` says the same thing in blue and
green. **Render the icon and look at it before picking one** — an icon name
that reads correctly says nothing about whether it will be visible against
the client's background.

### Scanners: the library, not just the launchers

The four entries above are front ends — Big Picture, Heroic's console mode, a
desktop and a power button. They get you to a machine, not to a game: from
Moonlight you land in a launcher UI and navigate it over the stream. Moonshine
also has *application scanners*, which read a launcher's own library and emit
one app entry per installed game, so a stream can start in the game itself.
`modules/services/moonshine.nix` now configures two of the four upstream
supports (Steam and Heroic; Lutris and the generic `.desktop` scanner aren't
relevant on this host), on `features.gaming` alongside the launcher entries
they complement.

Scanning happens in the daemon at startup, not at build time — the generated
TOML only names the libraries. Installing a game therefore changes the app
list at the next `systemctl restart moonshine`, with no rebuild. Scanned
entries are merged into the static list and de-duplicated on
`(title, command)`, so the manual launcher entries can't collide with them.

**Steam.** One scanner covers both of this host's libraries: `steamlocate`
reads `libraryfolders.vdf` from the path given and then walks every library it
lists, so the games on `/mnt/storage/SteamLibrary` are found from the
`~/.local/share/Steam` entry. Box art is read from
`appcache/librarycache/<appid>` — under the *configured* library, which is
also where Steam caches art for games installed elsewhere, so the second
library needs no entry of its own. The command carries `-bigpicture` next to
`steam://rungameid/{game_id}`, as upstream's own example does: without it
Steam draws the desktop client window in the stream's compositor beside the
game and the two compete for focus. The `-shutdown` pre-command the Big
Picture entry already needed applies identically here — a `steam://` URL
handed to a running Steam is forwarded to *it*, so the game opens on the
physical screen and the stream 503s — so that workaround is now a `let`
binding shared by both.

**Heroic.** `--no-gui` plus `heroic://launch?appName={app_name}&runner={runner}`
is Heroic's own launch protocol; it starts the game without drawing the
library window. `{runner}` is the store (`legendary`/`gog`/`nile`/`sideload`).
`config_dir` is stated rather than left to the default, which probes for the
native and Flatpak directories from the daemon's process context — a runtime
guess where this repo knows the answer. The command uses
`/etc/profiles/per-user/`, for the same reason the launcher entry does.

Heroic is single-instance too, and now gets an equivalent of Steam's
pre-command — `heroicShutdown`, shared by the Heroic launcher entry and every
game the scanner emits, the same way `steamShutdown` is. This reverses the
earlier decision to leave closing Heroic as a manual step ("it has no
graceful `-shutdown` to ask with, and killing an Electron app that might be
mid-download is worse than the problem"); both hazards named there are real,
and the script is built around them rather than in spite of them.

The problem is the same as Steam's, confirmed in 2.22.0's `app.asar` rather
than assumed: the main process takes Electron's
`requestSingleInstanceLock()`, and the `second-instance` handler forwards a
later invocation's argv to the running copy and shows its window. So
`heroic --console`, or a `heroic://launch?...` URL, sent while a desktop
Heroic is open acts on *that* instance — the launcher or the game appears on
the physical screen, and the stream gets a compositor with no client in it.
That is the same blank-frame-with-a-live-cursor symptom as the greeter's
`Writeback-1` bug and the `niri --session` one, from a third cause.

What Heroic lacks is Steam's `-shutdown`, so there is nothing to ask politely
with and the script signals the process instead. Two guards make that
acceptable:

- **It refuses outright while Heroic is busy.** Heroic drives `legendary`,
  `gogdl`, `nile` and `comet` as child processes, so any of those running
  means a download, an install, or a game actually being played. That is the
  case the old "close it by hand" note was protecting, and it is now detected
  rather than left to the operator to remember.
- **Only the main process is signalled.** Electron's renderer, GPU and zygote
  children all share the name `heroic`, so the script picks out the processes
  whose parent is *not* also a `heroic` and sends SIGTERM only to those; the
  children go away with the parent. There is no SIGKILL escalation — if the
  process is still there 30 seconds later the script gives up and says so.

Refusing means exiting non-zero, and that aborts the launch rather than
merely logging it: Moonshine builds pre-commands into the transient unit's
`ExecStartPre` with the ignore-failure flag off (`build_exec_entry` returns
`false` for it), so a failed pre-command fails the unit and the app never
starts. That is deliberate — a visible failure on the Moonlight client beats
a game silently starting on the machine's own screen, which is the failure
this exists to prevent. The messages go to stderr, so they land in
`journalctl --user -u moonshine-session.service` like everything else an app
entry prints.

One environment note behind the process detection: Heroic is an FHS-env
package and its wrapper runs it under `bwrap`, but that wrapper passes no
`--unshare-pid`, so the Electron processes are ordinary entries in the host's
PID namespace and `pgrep -x heroic` sees them. The bash wrapper itself is
*not* matched — a script's `comm` is its interpreter's name, so it reads as
`bash`, which is also why the real main process is correctly identified as
one whose parent is not a `heroic`. The parent/child split was verified
against a synthetic tree of same-named processes, not reasoned about alone;
the live path (a real Heroic open while a stream starts) is still untested.

Box art for scanned games comes from each launcher's own cache — Steam's
`library_600x900.jpg`/`library_capsule.jpg`, Heroic's `images-cache/`. A game
whose art the launcher never downloaded falls through to
`resolve_missing_boxart()`, which as established above cannot resolve
anything on NixOS, and will show as a blank card. The fix is to open the
launcher once so it fetches the art, not anything repo-side.

### Status

No longer eval-only — the desktop has been installed and booted since this
was written, and a paired Moonlight client lists the four entries above,
which is how the blank box art was noticed. Pairing is at
`http://<host>:47989/pin`. The declared box art is **verified live
2026-08-21**: switched on the desktop, all four PNGs resolved in the running
daemon's config, and the operator confirmed the icons render in Moonlight.

## Turning on `home-manager.useUserPackages`

Prompted by the Moonshine work above: the Heroic app entry needed a stable
path to a Home Manager package for a *system* unit to launch, and there
wasn't one. Investigating why turned up an unexamined default rather than a
decision.

### It was never chosen

`useUserPackages` appeared nowhere in this repo — not in `lib/mkHost.nix`,
not in `ARCHITECTURE.md`, not here. `mkHost` set only `useGlobalPkgs`, and
upstream declares the other as `mkEnableOption`, so it defaulted to `false`
and that default simply fell through. Both of home-manager's own flake
templates set it `true`, and its manual says it "may become the default value
in the future".

### What it actually changes — and what it doesn't

Not what's in the closure. Checked before changing anything: Heroic is in the
desktop's toplevel *derivation* closure either way
(`heroic-unwrapped-2.22.0.drv`, `heroic-2.22.0-fhsenv-profile.drv`, …),
alongside `home-manager-path.drv`. Home Manager packages were always built,
fetched and GC-rooted with the generation.

What changes is how they are *exposed*:

- **off** — a oneshot activation unit `home-manager-ol.service`
  (`ExecStart=…/hm-setup-env`, `TimeoutStartSec=5m`) imperatively installs
  `home.path` into the user's own nix profile on every switch.
- **on** — `home.path` becomes `users.users.<name>.packages`, i.e.
  `/etc/profiles/per-user/<name>`, built declaratively and swapped atomically
  with the generation. Verified: `users.users.ol.packages` went from `[]` to
  `["home-manager-path"]`.

Rollback worked before — the old generation's activation unit re-runs and
re-points the profile — so this is not a bug fix. It is a fidelity fix. The
repo's headline claim is "one `nixos-rebuild switch`, one rollback", and with
the flag off the user's package set moved by an activation side-effect rather
than by the generation swap: one more step able to half-fail, on a repo whose
standing gotchas already include an HM activation race ("Existing file …
would be clobbered"). It also removes the reason the Heroic entry had to name
a store path.

### Two knock-on effects, both checked before flipping it

**`xdg.portal` grows an assertion** under this flag: it requires
`environment.pathsToLink` to contain `/share/applications` and
`/share/xdg-desktop-portal`. Harmless here twice over — nothing in `home/`
enables `xdg.portal` (portals come from `programs.niri` at the NixOS level),
and both paths are in `pathsToLink` already.

**Home Manager's `fonts.fontconfig.enable` changes its default** from `false`
to the value of NixOS' `fonts.fontconfig.enable`, so it flipped on. That
looked like a direct threat to this repo's rule that UI fonts have exactly
one source of truth (`modules/system/fonts.nix`), so the three generated
files were read rather than assumed:

- `52-hm-default-fonts.conf` — an empty no-op. HM's `defaultFonts.*` all
  default to `[]`, so it contains a `<description>` and nothing else. The
  system's `fonts.fontconfig.defaultFonts` is untouched.
- `10-hm-rendering.conf` — likewise a no-op (`<match target="font"></match>`).
- `10-hm-fonts.conf` — adds font *directories*, including
  `/etc/profiles/per-user/ol/share/fonts`.

So the font default stays where it was, and the flip is a small net gain:
fonts installed through `home.packages` become discoverable to fontconfig,
which upstream's own comment says they are not on NixOS by default.

### The one migration cost

`environment.profiles` lists `$HOME/.nix-profile` *before*
`/etc/profiles/per-user/$USER`. On a host already installed with the flag
off, the stale user profile therefore keeps shadowing the new location until
it is removed by hand — an old binary silently winning after a switch that
looks clean. Only `the-entertaining-nios-vm` is affected; it is disposable,
and the desktop and laptop have never been installed, so they get this for
free. Recorded as a standing gotcha in `CLAUDE.md`.

## The desktop's first boot: a black screen with a live cursor

The desktop bootstrapped and rebooted cleanly, and landed on a black screen
— with a mouse cursor that moved, and was already the right Bibata theme.
That combination is the whole diagnosis in miniature: a Wayland compositor
was up and had loaded the greeter's cursor settings, but nothing was being
drawn.

### It was not the GPU, and not theming

Both were checked first and both came back clean. `amdgpu` was loaded with
`/dev/dri/card1` present, and the greeter's own log had already got as far
as `EGL 1.5`, `OpenGL ES vendor="AMD" renderer="AMD Radeon RX 6600
(radeonsi, navi23, ACO, DRM 3.64, 7.1.8-cachyos)"`, Mesa 26.1.6. greetd was
running, the greetd socket was connected, the keymap had loaded. The cursor
being *correctly themed* was itself positive evidence that `greeter.toml`
had been written and read.

The greeter runs as uid 998, and its stderr goes to the journal under that
uid rather than under the `greetd` unit — `journalctl -b -u greetd` shows
only PAM lines and is actively misleading here. `journalctl -b _UID=998` is
where the failure actually is:

```
[wayland] output 'DP-1' ready 2560x1440 at (0,0) scale=2
[wayland] output 'HDMI-A-1' ready 1920x1080 at (0,0) scale=1
[greeter] syncOutputWindows: 3 target output(s), 0 view(s)
...
[greeter-window] toplevel close requested
[WRN] [render] renderScene failed: eglSwapBuffers failed
[ERR] [greeter] Wayland flush failed after greeter init
[ERR] [main] failed to initialize greeter
[ERR] [main] holding process so greetd does not respawn; fix config and restart greetd
```

The first attempt, before greetd's one restart, failed more explicitly with
`protocol error 3 interface=xdg_surface`.

### Three outputs, two monitors

`/sys/class/drm/card*-*/status` explains the count:

```
card1-DP-1        connected
card1-DP-2        disconnected
card1-DP-3        disconnected
card1-HDMI-A-1    connected
card1-Writeback-1 unknown
```

amdgpu exposes a `Writeback-1` connector — a DRM writeback target, not a
display. noctalia-greeter's default is to mirror onto every output, so it
counted writeback as a third monitor, created a surface on it that can never
be presented, violated xdg-shell, and aborted before drawing a single frame.
It then deliberately held the process open rather than exiting, which is why
greetd did not respawn-loop and why the compositor stayed up drawing the
cursor.

`examples/greeter.toml` in the pinned greeter source documents the fix
directly: `[output] name` — "Pin the greeter to one connector; omit to
mirror on every monitor."

### Why the pin is host-level

`programs.noctalia-greeter.settings.output.name = "DP-1"` went into
`hosts/the-entertaining-nios-desktop/default.nix`, not
`modules/desktop/greetd.nix`. A connector name describes one machine's
cabling, and the VM shares that module and has neither a DP-1 nor a
writeback connector — the module stays host-agnostic, per the usual layering
rule.

Worth noting the option merges cleanly across the two files despite
`settings` being declared as `oneOf [ tomlFormat.type str path ]`; this was
verified by evaluating the merged result rather than assumed, since a
`oneOf` containing non-attrset members is exactly the shape that can reject
a second definition:

```json
{"cursor": {"size": 22, "theme": "Bibata-Modern-Classic"},
 "keyboard": {"layout": "fr"},
 "output": {"name": "DP-1"}}
```

Consequence to accept: HDMI-A-1 shows nothing at the login screen. Only the
session drives both monitors.

### Correction: the `greeter.toml` seed-once gotcha is obsolete

Phase 3 recorded (and `CLAUDE.md` carried) that
`programs.noctalia-greeter.settings` only ever *seeds*
`/var/lib/noctalia-greeter/greeter.toml` through a systemd-tmpfiles `C`-type
rule, so changes needed `sudo rm … && sudo systemd-tmpfiles --create && sudo
systemctl restart greetd` to land. That was true when it was written. At the
pinned revision (`4aa960d`) upstream's `nix/nixos-module.nix` uses an `L+`
force-symlink instead:

```nix
"/var/lib/noctalia-greeter/greeter.toml"."L+" = {
  argument = "${generateToml "greeter.toml" cfg.settings}";
```

and its own option description now reads "Full declarative greeter.toml,
symlinked into the Nix store and replaced on every activation". So a plain
`nixos-rebuild switch` is sufficient and the manual dance is dead. The
earlier Phase 3 and Phase 5 entries above are left as written — this is an
investigation log, and they were accurate at the time — but `CLAUDE.md` and
the comment in `modules/desktop/greetd.nix` have been corrected. Re-check
that tmpfiles rule whenever the `noctalia-greeter` input is bumped; it has
changed once already.

### niri is unaffected — verified in a live session

The open question when the fix was written was whether niri would trip over
`Writeback-1` the same way the greeter did. It does not. From the running
session on the desktop:

```
$ niri msg outputs
Output "Samsung Electric Company C27F390 H4ZR113985" (HDMI-A-1)
  Current mode: 1920x1080 @ 60.000 Hz (preferred)
Output "Samsung Electric Company LS27CG51x H9JW901815" (DP-1)
  Current mode: 2560x1440 @ 164.999 Hz (preferred)
```

Two outputs, both at their preferred mode, no writeback connector among
them. So the mirror-onto-every-output behaviour is noctalia-greeter's alone,
not something inherent to Wayland compositors on amdgpu, and `output.name`
is needed only for the greeter — niri's own `display.kdl` needs no
corresponding exclusion.

## Auditing the VM's Noctalia sidecar into declarative config

The VM had been configured through Noctalia's own settings pages for some
months, and nothing in this repo recorded what had been changed that way. The
question was what of it belonged in `home/noctalia.nix` so every host would
follow it.

### What the sidecar actually held

`~/.local/state/noctalia/settings.toml` on `the-entertaining-nios-vm`, read
in full, contained five things beyond `config_version`:

| key | value | verdict |
| --- | --- | --- |
| `shell.telemetry_enabled` | `true` | declared, as `false` — see below |
| `theme.templates.builtin_ids` | same five ids as Nix, reordered | already declarative; the sidecar copy is a redundant shadow |
| `lockscreen_widgets.*` | `enabled = false` + a `lockscreen-login-box@Virtual-1` placement | only the switch is portable |
| `wallpaper.default` / `.last` / `.monitors.Virtual-1` | the black-hole wallpaper | `default.path` declared |
| `config_version` | `12` | Noctalia's own migration marker, not a setting |

That is the whole delta. The settings pages had touched far less than the
size of the file suggested — most of its bulk is one lockscreen widget's
geometry.

### Telemetry was a setup-wizard click, not a decision

`telemetry_enabled` defaults to `false` upstream (`config_types.h`), and the
*setup wizard* is what put `true` in the VM's sidecar: `setup_wizard_panel.cpp`
calls `setOverride({"shell", "telemetry_enabled"})` with whatever the toggle
was left on. Propagating the VM's value verbatim would have switched an
anonymous startup ping on for the desktop and laptop on the strength of a
first-run click on a disposable machine. The operator chose `false`, and it is
now stated explicitly rather than left to the next host's wizard.

### Correction: `wallpaper.default.path` is not inert

`home/noctalia.nix` carried a note saying Noctalia reads the active wallpaper
only from its own state and never from `config.toml`, and that declaring a
default would therefore do nothing. That is half right, and the half it gets
wrong matters.

The key is real and documented — `example.toml` describes
`[wallpaper.default] path` as the "optional initial/default wallpaper path",
and Noctalia's own settings UI writes it. What the old note correctly
identified is the *precedence*. `wallpaper.cpp` says so in a comment on
`applyResolvedWallpaper`:

```
// Match wallpaper panel "All monitors": per-output overrides win over default in
// getWallpaperPath(), so set every connected output plus default or the image never updates.
```

Picking a wallpaper in the UI writes `[wallpaper.monitors.<connector>]`, and
that beats `default`. So the declared value is the wallpaper a host that has
never picked one comes up on, and a host that has picked one keeps its
choice. Both halves are wanted, and the feared failure mode — re-pinning the
wallpaper on every login and overwriting the user's choice — cannot happen,
because Nix writes only the base layer and never touches the sidecar.

### The lockscreen widget placement is not portable

The VM's widget id is `lockscreen-login-box@Virtual-1` and its position is
`cx = 640.0, cy = 618.0` — absolute pixels on that machine's single output.
Widget ids embed a connector name, which is machine cabling, the same reason
the greeter's `output.name` pin is host-level rather than in a module. Only
`lockscreen_widgets.enabled = false` was taken; the placement was left behind.

### The sidecar shadows the base config permanently

Worth stating plainly, because it bounds what this change can achieve.
Noctalia deep-merges the sidecar over `config.toml` at load, and there is no
compare-against-base pruning anywhere in `config_overrides.cpp` — the only
erase path is `eraseOverridePath`, called when a setting is explicitly reset.
So a value set once in the UI shadows this repo forever on that host, even
after it is declared here and even if the declared value is identical.

Making the VM and the desktop actually follow the declared values is a
one-time manual step per host: delete the corresponding sections from
`~/.local/state/noctalia/settings.toml` and restart the shell.

```bash
# per host, after a switch that carries the new config.toml
systemctl --user stop noctalia
$EDITOR ~/.local/state/noctalia/settings.toml   # drop shell.telemetry_enabled,
                                                # theme.templates.builtin_ids,
                                                # lockscreen_widgets.*, wallpaper.*
systemctl --user start noctalia
```

An activation script that pruned those keys automatically was considered and
rejected. That file is also where Noctalia keeps genuinely runtime-learned
state — the active wallpaper, clipboard history position, widget placements —
and a `nixos-rebuild switch` that silently reverted a choice made in the UI
would be a worse surprise than a stale key that can be found by reading one
file. It is the same reasoning that keeps the wallpaper *selection* out of
Nix while the wallpaper *default* goes in.

### Verification

`driver.sh check` passes for all three hosts, and the generated
`config.toml` validates clean under Noctalia's own build-time validator (the
`noctalia-config` derivation, which the home module runs because
`validateConfig` defaults to `true`).

That validator needed a canary before it could be trusted, per this repo's
own rule. It does **not** fail the build on a bad key — a junk
`canary_junk_section.nope` still produced `✓ Config is valid`, exit 0, with
the problem reported only as `WARN canary_junk_section: unknown section` in
the build log. So it is a real check, but reading its `nix log` output is the
part that matters; a green build alone says nothing about whether a key was
recognised. With the canary removed, the log is warning-free, which is what
confirms `lockscreen_widgets.enabled` and `wallpaper.default.path` are
spelled the way Noctalia expects.

Not yet verified live: no host has been switched onto this config, and no
sidecar has been cleaned. The standing rule that eval passing is not
verification applies here as everywhere.

## Rebasing the Noctalia declarative config on the desktop's effective export

The section above audited the *VM's* sidecar. That was the wrong host to
generalise from: the VM is disposable, its Noctalia had been barely touched,
and its whole delta was five keys. The desktop — the machine actually used —
had months of settings-page work in its sidecar that this repo had never
recorded. This pass replaces the VM-derived guesses with the desktop's real
state.

### The input: an effective-config export, not a sidecar

The source was Noctalia's own export of the *merged* configuration
(`~/Downloads/noctalia-config.toml`), not the sidecar alone. That matters,
and it is the better artifact to work from: the sidecar is a diff against a
base you then have to reconstruct by hand, whereas the export is what the
operator actually sees on screen. Folding it back in is a straight
"everything in this file should be declared", with one filter applied.

### The filter: display independence

The one editorial rule was that nothing tied to a particular display may be
declared. Dropped on that basis:

| dropped | why |
| --- | --- |
| `lockscreen_widgets.widget.*` (6 tables) | ids are `lockscreen-login-box@<connector>`; every widget carries `output`, `cx`/`cy`, `placement_width`/`placement_height` in absolute pixels |
| `lockscreen_widgets.widget_order`, `.grid`, `.schema_version` | the same canvas's bookkeeping, meaningless without the placements |
| `wallpaper.last`, `wallpaper.monitors.<connector>` | per-output runtime selection, and the thing that deliberately beats `wallpaper.default` |

Everything else in the export is display-independent and was declared —
including the bar layout, which is a list of widget *ids* and identical on
every host. Upstream does offer per-monitor bar overrides
(`[bar.<name>.monitor.<key>]`, matching on a connector); they are
deliberately unused, so one bar description serves the desktop's two outputs
and the laptop's one.

### `lockscreen_widgets.enabled = true` is safe without placements

This was the one genuinely risky call, since `enabled = true` with an empty
widget list could plausibly mean a lock screen with no login box — an
unlockable machine. It does not, and this was confirmed by reading upstream
rather than by reasoning about it. `LockscreenWidgetsController::normalizeSnapshot`
calls `lockscreen_login_box::ensureWidgets`, which walks the live Wayland
outputs and, for every connected output without a login box, *inserts* one
with `defaultPanelCenter`/`defaultPanelSize`, then force-enables one if none
is enabled:

```cpp
for (const auto& output : wayland.outputs()) {
  ...
  if (outputsWithLoginBox.contains(outputKey)) { continue; }
  DesktopWidgetState widget;
  widget.id = widgetIdForOutput(outputKey);
  ...
  widgets.insert(widgets.begin(), std::move(widget));
}
```

So a fresh host comes up with a centered, correctly-sized login box per
monitor. The cost is that the widget *arrangement* is per-host runtime state
this repo does not back up — accepted, because the alternative is hard-coding
one machine's cabling.

### Correction to the previous section's runbook

The runbook above tells the operator to delete `lockscreen_widgets.*` from a
host's sidecar. **Do not do that on the desktop.** That host's sidecar holds a
hand-built six-widget lockscreen canvas — two login boxes, a clock, a
calendar and two media players, individually positioned — and deleting the
section would destroy it with nothing in this repo to restore it from, by
design (see the filter above). The keys that are safe to clear on an
already-provisioned host are the ones this repo now declares and whose
sidecar copy is a redundant shadow: `theme.*`, `shell.*`, `bar.*`,
`calendar.*`, `control_center.*`, `location.*`, `notification.*`,
`plugins.*`, `widget.*`, `desktop_widgets.*`, `lockscreen.*`, and
`lockscreen_widgets.enabled` *only* — never `lockscreen_widgets.widget`,
`.grid` or `.widget_order`, and never `wallpaper.monitors`/`wallpaper.last`
unless the intent is to reset the wallpaper.

### Two things the export surfaced that were already broken

Neither was introduced here; both were found by reading the export against
upstream's schema, and both were declared as-found rather than silently
"fixed", since fixing either is a visible change that is the operator's to
make. The operator has since resolved both — in each case by deleting the
dead setting rather than by supplying the missing half that would have made
it live.

- **`shell.app_icon_color` was inert.** `example.toml` documents it as a
  color role "when colorize is enabled", and `appIconColorize` defaults to
  `false` (`config_types.h`). The desktop set the color and never set the
  switch, so it never had any effect. Resolved by removing the key: enabling
  `app_icon_colorize` would have been a visible recolor of every app icon in
  the shell, which is not what the exported state was asking for — the color
  was set once in the UI and left stranded. Same sidecar caveat as below,
  though this one is harmless: a host that still has `shell.app_icon_color`
  in its `settings.toml` keeps a value nothing reads.
- **The bar's `bar_2` slot pointed at a plugin that is not installed.**
  `widget.bar_2.type = "icefish/phone-connect:bar"`, but `plugins.enabled`
  lists only `8bury/mini-docker` and `rylos/tailnet`, so the slot rendered
  nothing. Resolved by removing the slot rather than by installing the
  plugin — the operator does not use `icefish/phone-connect`, so the id had
  come along in the export only as leftover state from having tried it. The
  `"bar_2"` entry in `bar.default.end` and the `[widget.bar_2]` block are
  both gone. Note this is a case where the sidecar keeps the old value alive:
  an already-provisioned host that set the slot through the UI still has
  `widget.bar_2` in its `settings.toml`, and removing it from Nix does not
  remove it there — add `widget.bar_2` to the safe-to-clear list for any host
  that shows a stray empty slot after the switch.

### Verification

`nix flake check --no-build` passes for all three hosts. The generated
`config.toml` was built directly out of the desktop's evaluated Home Manager
config and diffed key-by-key (flattened, via `tomllib`) against the operator's
export. After the pass the only differences are the deliberate drops in the
table above, plus three explainable items:

- `shell.telemetry_enabled` exists in the generated file and not in the
  export. This is an artifact of *when* the export was taken, not a
  disagreement: the export is the desktop's current base (built from `main`,
  which has no such key) merged with its sidecar (which has none either), so
  the key could not have appeared in it.
- `theme.templates.community_ids` holds the same ten ids in a different
  order. Order is apply order for template ids and carries no meaning; the
  existing list order was kept and the three new gaming ids appended.
- `theme.templates.user.niri-style.input_path` names a different store path.
  `cmp` confirms the two files are byte-identical — a derivation-name
  difference, not a content one.

Noctalia's own build-time validator reports three warnings and no errors:

```
WARN  widget.bar: unrecognized widget type "rylos/tailnet:bar"
WARN  widget.mini-docker: unrecognized widget type "8bury/mini-docker:mini-docker"
✓ Config is valid (2 warning(s))
```

(A third, for `widget.bar_2`, was present until that slot was removed.)

These are expected and permanent: plugin widget types are resolved from
plugins Noctalia fetches at runtime into `~/.local/state/noctalia/plugins`,
which a build-time validator running in a sandbox cannot see. Their presence
is also useful — it means the validator *is* reading the `[widget.*]` blocks,
and that every other new section here (`bar.default`'s layout, `calendar`,
`control_center`, `location`, `lockscreen`, `notification`, `plugins`, the
`shell.*` additions) was recognised, since an unknown section or key produces
exactly this kind of line and none appeared for them. Per this repo's rule
that the validator warns but never fails, the `nix log` output is the part
that carries the information, not the green build.

### Verified live on the desktop (2026-08-21)

The desktop was switched onto this config and the one-time sidecar cleanup
run. Confirmed on the running system rather than by eval:

- `/run/current-system` is the closure built from this branch.
- Merging `origin/main` in first was necessary, not cosmetic: the branch was
  19 commits behind, and switching as-is would have reverted live fixes
  (Zen's remembered geometry, the Z407 volume puck). `home/noctalia.nix` has
  no overlap with main, so the merge conflicted only where both sides had
  appended sections to this file.
- Four sidecar keys shadowed the new declarations and were cleared:
  `bar.default.end` (which still listed `bar_2`, and would otherwise have
  kept the removed slot on screen), `theme.templates.community_ids`,
  `shell.app_icon_color` and `[widget.bar_2]`. Nothing else was touched — the
  six-widget lockscreen canvas and both `wallpaper.monitors` entries survive.
  This is the concrete case the sidecar gotcha warns about: **deleting a key
  from Nix does not delete it from a provisioned host**, so a removal needs a
  matching sidecar clear or it simply does not take effect.
- The effective merge (base + sidecar, recomputed the way Noctalia does it)
  now has no `bar_2` or `phone-connect` anywhere, no `app_icon_color`, and
  `bar.default.end` is the declared eight-widget list.
- Noctalia restarted clean: both plugins loaded, two outputs detected (no
  writeback connector), a bar created on each, polkit agent registered,
  telemetry disabled, `lockscreen_widgets.enabled = true` with all six stored
  widgets intact. **Zero warnings from the running instance** — the
  `unknown widget "bar_2"` line appears only in the pre-cleanup instance's
  log, which is what proves the clear was the operative step.

The `theme.templates.user.niri-style.input_path` store path changed again
across the merge; `cmp` again confirms byte-identical contents.

## Porting the laptop's real Zen setup, and the `policies.Preferences` allowlist

The operator asked for Zen to be set up the way it actually is on their
daily-driver CachyOS laptop (`the-entertaining-caos-laptop`, AUR
`zen-browser-bin` 1.21.10b, profile `~/.config/zen/u7zjeytq.Default
(release)`). That reverses one earlier decision and turned up one real bug
in what was already there.

### What was ported, and what deliberately wasn't

Phase 6 recorded "no extension/policy porting" — the real profile is mutable
Firefox-style state, out of scope. Extensions are now in scope; the rest of
that decision stands, for a reason that only became visible on reading the
live profile: **the laptop is signed into Firefox Sync**
(`services.sync.username` in `prefs.js`, with the addons, prefs, forms,
clients and `workspaces` engines all enabled). Bookmarks, history, logins,
workspaces and pinned tabs already replicate to a new install through an
account, and they are exactly the data Nix has no business holding. So the
split is: Nix seeds the *browser*, Sync seeds the *profile*.

Six add-ons are declared in `policies.ExtensionSettings`, matching the six
enabled on the laptop: uBlock Origin, Dark Reader, Bitwarden, Obsidian Web
Clipper, Chrome Mask, and the French language pack. `normal_installed`, not
`force_installed` — it installs and keeps them updated but leaves them
removable from `about:addons`, the same seed-don't-lock stance as
`Status = "default"` on every pref. The three add-ons present but *disabled*
on the laptop (the DarkMagic and Matte Black themes, Conex) are not
declared. Install URLs use AMO's `/latest/` redirect rather than a versioned
`/file/<id>/` URL, so the file doesn't need a bump per extension release;
the cost is that the exact version isn't reproducible, which was already
true of every other byte in a browser profile.

Prefs were taken from `prefs.js` and filtered three ways: browser-written
state and telemetry/sync bookkeeping dropped, machine-local paths dropped
(`browser.download.lastDir`, `browser.backup.location` — they name
directories that need not exist on a NixOS host), and then the allowlist
below applied. `browser.newtabpage.activity-stream.showSponsoredTopSites` is
deliberately *not* declared: it is still at its default on the laptop, so
there was no operator choice there to reproduce, and asserting a value would
have been inventing one.

### `policies.Preferences` has a prefix allowlist, and `zen.*` is not on it

Read out of the shipped browser rather than the docs —
`/opt/zen-browser-bin/browser/omni.ja`, unzipped, then
`modules/policies/Policies.sys.mjs`, `Preferences: onBeforeAddons`. The
allowed prefixes are `accessibility.`, `alerts.`, `app.update.`, `browser.`,
`datareporting.policy.`, `devtools.`, `dom.`, `extensions.`,
`general.autoScroll`, `general.smoothScroll`, `geo.`, `gfx.`,
`identity.fxaccounts.toolbar.`, `intl.`, `keyword.enabled`, `layers.`,
`layout.`, `mathml.disabled`, `media.`, `network.`, `pdfjs.`, `places.`,
`pref.`, `print.`, four specific `privacy.*` prefs, `sidebar.`, `signon.`,
`spellchecker.`, two `svg.*`,
`toolkit.legacyUserProfileCustomizations.stylesheets`, `ui.`, two `webgl.*`,
`widget.`, and some `xpinstall.*`. `security.*` is an exact-match allow-list
of its own, and there is a four-entry blocked list. Anything else is
dropped with an `Unable to set preference X. Preference not allowed for
stability reasons.` line in the browser console — no eval error, no visible
failure, nothing that `nix flake check` could ever catch.

Zen inherits that list unchanged; it does not add its own namespace. Two
consequences:

- **The transparency prefs written during "Making blur and transparency
  actually render" were never applied.** `zen.widget.linux.transparency`,
  `mod.sameerasw.zen_bg_color_enabled`, `mod.sameerasw.zen_transparency_color`
  and `mod.sameerasw.zen_no_shadow` are all outside the allowlist. Only
  `browser.tabs.allow_transparent_browser` in that block was ever reaching
  the browser. This is currently harmless — `home/transparency.nix` is
  `1.0`, so every one of them evaluates to `false`/inert anyway — and the
  entries are kept rather than deleted so the intent isn't silently lost,
  but **turning transparency back on will need another mechanism for them**
  (`profiles.<name>.settings`, i.e. prefs.js, with the profile-ownership
  cost described below). The live verification recorded in that earlier
  entry presumably observed the mod's own settings panel, not a
  policy-applied pref.
- **None of the laptop's genuinely Zen-specific UI settings can be ported**:
  `zen.view.compact.enable-at-startup`, `zen.view.use-single-toolbar`,
  `zen.glance.activation-method`, `zen.tabs.ctrl-tab.ignore-essential-tabs`,
  `zen.pinned-tab-manager.restore-pinned-tabs-to-pinned-url`,
  `zen.swipe.is-fast-swipe`, `zen.workspaces.continue-where-left-off`. They
  are left to the browser's settings UI rather than declared somewhere that
  cannot apply them.

### Why not `profiles.<name>.settings`

That option does reach `prefs.js`, and would also unlock the flake's
`profiles.<name>.mods` (which is how the laptop's one Zen mod, "Better
Unloaded Tabs", `f7c71d9a-bce2-420f-ae44-a64bd92975ab`, would be declared).
It is still declined, for the reason already in `home/zen-browser.nix`:
declaring a profile hands the profile directory to Home Manager, which
writes `profiles.ini`, and there is no guarantee a Nix-declared "default"
lines up with the profile a host is actually using — the VM already carries
an ad hoc one from earlier live testing. The failure mode is Home Manager
creating and switching to a second, empty profile. `mods` also fetches from
`raw.githubusercontent.com` at *activation* time, which makes a switch
network-dependent. If this is ever revisited, do it on a host with no
existing Zen profile and verify `profiles.ini` afterward.
## CI routes around Millennium's unreproducible Bun FOD

Adding the desktop's `nixosConfigurations` entry made CI build the Phase 7
gaming stack for the first time — and turned the `flake-check` workflow red
on every push that touched anything, for a reason having nothing to do with
the diff:

```
error: hash mismatch in fixed-output derivation '…-millennium-typescript-bun-deps.drv':
         specified: sha256-BEupNhAlkAELGGLj6/SVUjj101hBm4JzJH9N5i1qM6A=
            got:    sha256-FgPlXsAfLLsrvCn3AXqltUe2TvE0MgbuYmfTpVNTmSY=
```

### Why no re-pin can fix it

Upstream's `millennium-typescript-bun-deps` runs a *build* inside a
fixed-output derivation — `bun install --frozen-lockfile` plus a rollup
bundle, with whole `node_modules` trees copied into `$out`. An FOD promises
a stable output hash; a build of a JS dependency tree cannot make that
promise. Three GitHub Actions runs of one unchanged revision produced three
different hashes, while `nix build --rebuild` on the same `.drv` reproduces
the expected hash locally. Bumping the `millennium` input doesn't help: at
`cecdc95` (the newest revision as of this entry) the derivation has the same
shape, only a different `outputHash`. Upstream publishes no binary cache
either, so the CI substituter trick that already covers noctalia and
chaotic-nyx has nothing to point at.

That is what makes this different from the rolling-source rot that killed
`update.yml`: upstream drift gives every failure the *same* wrong hash and a
re-pin fixes it, this gives a different hash each time and no pin ever holds.

### What was rejected

- **Wait for upstream.** The honest answer, and the previous state — but it
  leaves a permanently red gate on the one host that most needs building,
  which trains everyone to ignore CI.
- **Drop the desktop's `build-<host>` check.** Loses closure coverage for the
  entire niri stack, proton-cachyos, the controller modules and Home Manager
  on that host, to work around one package.
- **Weaken the check to eval-only.** Redundant: `nix flake check` already
  evaluates every `nixosConfigurations` attribute, so this would have been a
  check that could not fail for any reason the existing pass wouldn't catch.
- **Our own Cachix.** Would work, but it means credentials, a secret in the
  repo's Actions config, and a cache to maintain — a lot of standing
  machinery to paper over someone else's bug.

### What was done

`flake.nix` grew a `ciClosure` helper between `nixosConfigurations` and
`checks`. For a host with `features.gaming` it returns
`host.extendModules { … programs.steam.package = lib.mkForce pkgs.steam; }`'s
toplevel; for every other host it returns the host's own toplevel unchanged.
Only the `checks` attribute goes through it — `nixosConfigurations` itself,
and therefore `just build`, `just switch` and `nixos-anywhere`, still get the
Millennium-patched Steam.

Verified before committing: the check's derivation closure
(`nix-store -qR`) contains no `millennium` path at all, still contains
`proton-cachyos` and a stock `steam-1.0.0.87`, and the vm and laptop check
derivations hash identically to the ones the failing run built — so the
substitution touches exactly one host and exactly one package. The real
config still resolves `programs.steam.package` to Millennium's
`steam-1.0.0.85`, the same store path that appears in the failure log.

The cost, stated plainly: a build failure *inside* Millennium will no longer
be caught by CI, only on the machine. That is a real reduction in coverage,
accepted because CI could never build that derivation successfully in the
first place. `ciClosure` is deliberately one small, self-describing
function, to be deleted whole the day upstream's FOD stops being a build (or
nixpkgs#382086 lands and Millennium comes from nixpkgs proper).
## Five desktop-only apps: KDE Connect, FreeCAD, Prism Launcher, IntelliJ IDEA, Claude Code

Requested for the desktop host specifically. Three questions had to be
answered before any of them could be written down.

### Where a "desktop-only app" goes when there is no per-host home entry point

`home/default.nix` is machine-agnostic and every host's Home Manager user
points at it (`lib/mkHost.nix`), so there is no file that means "packages for
the desktop". The only mechanism that expresses "this machine and not the
others" is a `features` flag the module self-gates on — which is the same
mechanism `home/vscode.nix` and friends already use with `features.niri`.

Reusing `features.niri` was rejected: it is on for the VM too, and the VM is
the disposable verification host. FreeCAD and IntelliJ are large closures
that would be built and fetched there for nothing.

So three new flags, named for capabilities rather than for packages, per the
one-flag-per-*capability* rule:

- `features.kdeconnect` — phone integration. `modules/services/kdeconnect.nix`
  (firewall + package) and `home/kdeconnect.nix` (the session daemon), the
  same system/home split niri and Nautilus use.
- `features.cad` — `home/freecad.nix`.
- `features.development` — `home/jetbrains.nix` and `home/claude-code.nix`:
  the tooling that sits on top of the terminal stack every host already gets.

Prism Launcher got no flag at all. It rides `features.gaming` next to
`home/heroic.nix` — same capability, same purely user-level shape — which is
why that flag now gates four modules rather than three.

### KDE Connect needs a system module, not just a package

Upstream's `programs.kdeconnect` module (read in full) does exactly two
things: install the package and open TCP **and** UDP 1714-1764. That range is
the entire point — discovery and pairing happen over it, and
`modules/system/networking.nix` leaves the firewall on, so a `home.packages`
entry alone would install a daemon that never finds a phone.

What that module does *not* do is start anything. Outside Plasma nothing
does, so `home/kdeconnect.nix` adds a `systemd.user.services.kdeconnect`
running `kdeconnect-indicator` — upstream's non-Plasma entry point, a
StatusNotifierItem tray icon that D-Bus-activates `kdeconnectd` itself, so
one unit covers both daemon and UI. It carries the same
`After=noctalia.service` + `ExecStartPre=sleep 5` treatment as
`home/vesktop.nix`, for the same already-diagnosed reason: Noctalia is a
plain `Type=simple` unit, so "started" is not "tray host ready", and an SNI
item registered too early is dropped in silence.

### `jetbrains.idea-community` does not exist any more, and its successor is flagged insecure

JetBrains discontinued the separate Community edition in 2025 and merged
everything into one distribution. nixpkgs removed the attribute outright —
evaluating `jetbrains.idea-community` now throws a "has been removed" error
naming two replacements: `jetbrains.idea-oss` (the Apache-2.0 build, the
literal Community successor) and `jetbrains.idea` (JetBrains' own unified
binary, unfree).

`idea-oss` was the obvious pick and does not work: nixpkgs pins it at
2025.3.4 and marks that version insecure (NIXPKGS-2026-2269, multiple known
vulnerabilities), so `nix flake check` refuses to evaluate it. Taking it
would mean adding `permittedInsecurePackages`, which this repo has never
needed and which is a worse trade than an unfree allow-list entry for a
package the operator is entitled to run — the unified distribution starts in
its free feature set and only asks for a subscription for the Ultimate
features. So `jetbrains.idea`, with `"idea"` added to
`modules/system/unfree.nix`. Revisit if nixpkgs bumps idea-oss past the
advisory. (The dry-run closure names the artifact `ideaIU-…tar.gz`; that is
the one binary JetBrains ships now, not a licensing claim.)

`claude-code` is unfree too (Anthropic's commercial terms rather than an OSS
license) and needed the same one-line allow-list entry. FreeCAD and Prism
Launcher are LGPL/GPL and needed nothing.

### Configuration: all five are package-only

Each one keeps its own state in a file it rewrites itself — FreeCAD's
`user.cfg` (window layout and per-workbench state in the same XML document),
IDEA's versioned `~/.config/JetBrains/IntelliJIdea<version>` directory (with
JetBrains' own Settings Sync already carrying it between machines), Prism
Launcher's instances and Microsoft account token, Claude Code's
`~/.claude.json` OAuth credentials, KDE Connect's paired-device keys. Same
call as Obsidian, Feishin and Zen: app-owned mutable state, not declarative
preferences, and in three of the five carrying a real credential.

### Verified

`driver.sh check` green, and the three lint/format check derivations built
(they are the ones `--no-build` skips). `nix build --dry-run` on the desktop
closure names `idea-2026.2.0.1`, `claude-code-2.1.220`, `freecad-1.1.1`,
`prismlauncher-11.0.3` and `kdeconnect.service`; the same dry-run on the VM
and the laptop names none of them.

Then confirmed live: the operator merged this to `main`, pulled it into the
desktop's own `~/.dotfiles` clone and switched, and reported all five
launching on the machine. That makes these the first pieces of the desktop's
application layer verified on real hardware rather than by eval — the rest
of Phase 7's gaming stack still has not been exercised there.

One incidental finding from trying to drive that switch remotely: the
desktop is not on the tailnet. `features.tailscale` installs and starts the
daemon, but `tailscale up` is a one-time interactive login that nobody has
run since the reinstall, so the node simply does not exist in
`tailscale status` — the only desktop entry there is the old CachyOS
`caos-desktop`. Worth knowing before assuming the desktop is reachable for
anything else, Moonshine included: that module deliberately sets
`openFirewall = false` because `modules/services/tailscale.nix` trusts
`tailscale0`, which means streaming cannot work until the same login
happens.

## The desktop's first day of use: no XWayland, and a keyring nobody unlocked

Two unrelated complaints from the first real session on
`the-entertaining-nios-desktop`: Steam refusing to start for want of an X
server, and VS Code warning that it was falling back to weak/plaintext
encryption for stored credentials. Both turned out to be one-line gaps, and
one of them was a documented claim that was simply false.

### Steam: there was no XWayland at all

`programs.niri.enable` does not bring XWayland, and this repo never added it
— `docs/decisions.md`'s Phase 3 notes recorded the "xwayland-satellite not
found" line in niri's log as *expected*, which it was, right up until an
X11-only app was actually installed. The Steam client has no Wayland backend
of any kind, so it simply refuses to run without `DISPLAY`.

What the fix is **not**: a systemd user unit for `xwayland-satellite`, a
`spawn-at-startup` line, or an `xwayland-satellite {}` block in the KDL.
Reading niri 26.04's own config defaults (`niri-config/src/lib.rs`) shows
the integration is already on:

```rust
xwayland_satellite: XwaylandSatellite {
    off: false,
    path: "xwayland-satellite",
},
```

`path` is a bare binary name, resolved on the compositor's PATH at startup.
So the entire fix is `environment.systemPackages = [ pkgs.xwayland-satellite ];`
in `modules/desktop/niri.nix`. It has to be system-level: niri is launched by
greetd, whose PATH is `/run/current-system/sw/bin`, so a `home.packages`
entry would not be visible at the moment niri looks.

Two behaviours worth having written down, both read out of `src/main.rs`:
niri sets `DISPLAY` from the satellite *before* calling `import_environment()`,
and `DISPLAY` is one of the five variables that function passes to
`systemctl --user import-environment` — so unlike the KDL `environment {}`
block (the standing gotcha), this really does reach the systemd `--user`
manager, and apps Noctalia launches as user services get it too. But
`niri.rs`'s reload path is explicit that it doesn't repeat that
(`// This won't change the systemd environment, but oh well.`), so the change
lands on a fresh login, not on a config reload.

`home/cursor.nix`'s comment about `x11.enable` was re-checked rather than
flipped: home-manager's `home.pointerCursor` exports `XCURSOR_THEME` and
`XCURSOR_SIZE` unconditionally, and `x11.enable` only adds an `xsetroot` call
in `xsession.profileExtra` plus two Xresources properties — an xsession this
repo never starts. Xwayland clients are covered by the env vars already, so
the option stays off; only the comment's reasoning changed.

### VS Code: two separate halves, and a false claim in ARCHITECTURE.md

The warning is Chromium's, not VS Code's own: Electron's `safeStorage` picks
a password store by sniffing `XDG_CURRENT_DESKTOP`, recognises GNOME and KDE
and nothing else, and under `niri` falls back to "basic text encryption" —
Settings Sync tokens and extension credentials written to disk in the clear.
Pinning it is `--password-store=gnome-libsecret`, delivered through
nixpkgs' own `code` wrapper hook:

```bash
if [[ -f $XDG_CONFIG_HOME/code-flags.conf ]]; then
   CODE_USER_FLAGS="$(sed 's/#.*//' $XDG_CONFIG_HOME/code-flags.conf | tr '\n' ' ')"
fi
```

`code-flags.conf` over `~/.vscode/argv.json` deliberately: all three of the
package's `.desktop` entries exec that same wrapper (`Exec=code %F` and
friends), so the flag applies from the launcher as well as from a shell,
while `argv.json` is VS Code's own mutable state and gets rewritten — the
app-owned-state conflict this repo keeps rediscovering. `libsecret` is
already in `pkgs.vscode`'s closure, so nothing else needed installing.

That flag alone would still not have been enough. Checking whether a keyring
was actually available turned up the second half:

```
$ nix eval .#nixosConfigurations.the-entertaining-nios-desktop.config.security.pam.services.greetd.enableGnomeKeyring
false
```

`ARCHITECTURE.md`'s SSH-agent section asserted that enabling
`services.gnome.gnome-keyring` "in turn makes greetd's own module set
`security.pam.services.greetd.enableGnomeKeyring = true`". It does not.
Grepping nixpkgs, neither the greetd module nor the niri module touches that
option — the only references are in `security/pam.nix`, where it is *read*.
Both real hosts evaluated it `false`, meaning the keyring daemon has been
running since Phase 3 with a login keyring that nothing ever unlocked. What
made this hard to notice is that the one thing anyone tested — `ssh-add`
followed by a real `git push` over the gcr agent — works either way for the
lifetime of a session.

`modules/desktop/greetd.nix` now sets it explicitly, alongside the greeter
settings, since it describes the login path rather than one machine. The
ARCHITECTURE.md paragraph is corrected in place with a dated note rather than
silently rewritten.

**Verified live, the Steam half** (2026-08-20, on the desktop after a switch
and a fresh login): Steam starts and shows its window under the satellite.
That is also the first time anything in Phase 7's gaming stack has actually
run on hardware rather than merely evaluating — the launcher only, though; no
game has been launched through Proton yet and no controller has been paired,
so `xone`/`xpadneo` and `proton-cachyos` remain untested.

**Still to verify live**: that VS Code stops warning, and that the login
keyring is genuinely open after a greetd login (`secret-tool store`/`lookup`
is the direct test, not `ssh-add -l`). The keyring half of this commit is the
part with no live evidence at all yet — Steam working says nothing about it,
since the two fixes are unrelated.


### Follow-up: the keyring was fine, the flags file was read by nothing

Live on the desktop after the switch and a fresh login, Steam worked and VS
Code went on warning. Checked over SSH, in this order:

```
$ cat ~/.config/code-flags.conf
--password-store=gnome-libsecret
$ busctl --user --json=short call org.freedesktop.secrets \
    /org/freedesktop/secrets/collection/login \
    org.freedesktop.DBus.Properties Get ss org.freedesktop.Secret.Collection Locked
{"type":"v","data":[{"type":"b","data":false}]}
```

So the keyring half of the previous commit works: the login collection
exists and is **unlocked** after a greetd login, and its two items are
Noctalia's own (`Noctalia encrypted storage key`, `Noctalia calendar refresh
token`) — a real app storing real secrets through libsecret. `/etc/pam.d/greetd`
turns out to be nothing but `include login`, and the `pam_gnome_keyring.so`
auth/session lines live in `/etc/pam.d/login`, which the include pulls in
with the entered password. Worth knowing before reading that file and
concluding the option didn't apply.

What was missing is a `Code Safe Storage` item — nothing VS Code had ever
written. The reason was in the installed wrapper:

```
$ cat $(readlink -f $(which code))
…
exec -a "$0" "/nix/store/…-vscode-1.130.0/bin/.code-wrapped" \
  ${NIXOS_OZONE_WL:+${WAYLAND_DISPLAY:+--ozone-platform-hint=auto …}} "$@"
```

No `code-flags.conf` handling anywhere in it. That hook is real, but it
arrived in a *newer* nixpkgs than this flake pins — the wrapper it was read
out of came from `nix build nixpkgs#vscode` on the laptop, which resolves the
**registry's** nixpkgs (VS Code 1.133.0), not this flake's locked input (VS
Code 1.130.0). A perfect example of the kind of check that cannot fail:
`xdg.configFile` wrote the file, eval was green, `nix flake check` was green,
and the feature was inert. Inspect wrapper-provided hooks through the flake's
own locked nixpkgs, always.

The fix is upstream's own supported argument, which exists at both revisions:

```nix
home.packages = [
  (pkgs.vscode.override { commandLineArgs = "--password-store=gnome-libsecret"; })
];
```

Verified by building it and reading the wrapper back, rather than by
assuming a second time — the last line is now
`… "$@"  --password-store=gnome-libsecret`. The cost is that vscode's
derivation is rebuilt (an unpack and a wrapper, no compilation) instead of
coming straight from cache.

**Still to verify live**: that the warning is actually gone, and that a
`Code Safe Storage` item appears in the login keyring once VS Code stores
something. That item's presence is the unambiguous test — the notification
can be dismissed, the keyring item can't be faked.


### `extraCompatPackages` never reaches Heroic

Reported live on the desktop (2026-08-20): Heroic's per-game compatibility
dropdown offered no `proton-cachyos`, despite `modules/programs/steam.nix`
declaring it. The two facts that explain it:

`programs.steam.extraCompatPackages` is not a system-wide installation. It
exports `STEAM_EXTRA_COMPAT_TOOLS_PATHS` into Steam's *own* FHS environment
and nothing else — no directory is created anywhere on disk, and indeed
`~/.steam/root/compatibilitytools.d` did not exist at all on a host that had
already run Steam. Any other launcher is on its own.

Heroic's search paths were read out of the shipped bundle rather than guessed
at (`…-heroic-2.22.0-fhsenv-rootfs/opt/heroic/resources/app.asar`, which
greps fine as plain text). It collects candidate directories:

```
~/.config/heroic/tools/proton/
<steam lib>/steamapps/common          (only with showValveProton)
<steam lib>/root/compatibilitytools.d
<steam lib>/compatibilitytools.d
```

then, for each entry `b` in each, accepts it if `<dir>/<b>/proton` exists,
naming the tool after the directory. So a Proton build is discovered by
directory layout, not by any registry — which makes it something a symlink
can satisfy:

```nix
home.file.".config/heroic/tools/proton/proton-cachyos".source =
  "${pkgs.proton-cachyos}/bin";
```

`$out/bin`, not `$out`: this derivation puts the whole tool tree (`proton`,
`toolmanifest.vdf`, `files/`, `protonfixes/`) under `bin`. That is the layout
Steam expects of a *search path* entry, not of a tool — nixpkgs' steam module
builds `STEAM_EXTRA_COMPAT_TOOLS_PATHS` with
`lib.makeSearchPathOutput "steamcompattool" ""`, and this package has only an
`out` output, so Steam is handed `$out` and finds the tool one level down in
`bin/` (it takes the name from that directory's `compatibilitytool.vdf`,
which says `Proton-CachyOS`; Heroic, by contrast, names it after the
directory, hence the symlink's name).

Choosing Heroic's own tools directory over `~/.steam/root/compatibilitytools.d`
was deliberate. The latter would have to be created for Steam, which has no
reason to want it — Steam already has the env var — and putting a
Nix-managed symlink inside a directory Steam creates and manages on demand is
the app-owned-mutable-state trap. Heroic's tools directory is only ever
written by Heroic's downloader, one directory per build, so an extra entry
alongside is exactly what the app expects. The host already had a
hand-downloaded `GE-Proton-latest` sitting there — the very thing this repo
avoids for Steam by declining protonup-qt — and it is left untouched.

**Verified live** (2026-08-20, on the desktop after `nixos-rebuild switch`):
`proton-cachyos` appears in Heroic's dropdown. Still not verified: that a
game actually *runs* under it, from either launcher.


### Phase 7 closes: a game under `proton-cachyos`, and a wired pad on `xone`

Later the same day (2026-08-20), on the desktop, the two remaining eval-only
claims in Phase 7 were exercised for real:

- **Proton.** Sifu installed and played through Heroic. Heroic's `config.json`
  default *and* that game's `GamesConfig/*.json` both name
  `~/.config/heroic/tools/proton/proton-cachyos/proton` with
  `"type": "proton"`, so the build that ran is the symlink from the section
  above, not the hand-downloaded `GE-Proton-latest` sitting beside it. The
  prefix under `~/Games/Heroic/Prefixes/Sifu` is the evidence it got as far as
  actually running.
- **Controller.** A wired Xbox pad enumerates as `Microsoft Xbox Controller`
  on `js1`/`event23`, with `xone_wired` and `xone_gip_gamepad` bound (both via
  `xone_gip`). So `modules/hardware/controllers.nix` does its job over USB
  with nothing else declared — no udev rule of this repo's, no user
  configuration.

What is still untested is `xpadneo`, the *other* module that file enables:
it is loaded, but with no device bound, because the pad was connected by
cable. The Bluetooth path is the only part of the gaming stack that has never
had hardware behind it.

This retires "Phase 7 is eval-only" from `CLAUDE.md`. Worth keeping in view
that the stack needed two live fixes before it worked at all — XWayland for
Steam, and the Heroic Proton symlink — neither of which eval could have
found.


## Z407 volume: two gain stages, because the kernel disabled the hardware one

The Logitech Z407 speakers on the desktop stepped volume unevenly, the puck and
the keyboard's volume keys disagreed with each other, and the whole scale sat
far quieter than the same speakers on Windows — "20% was more than loud enough
there, here I can barely hear anything at 40%."

This took two wrong diagnoses before the hardware was actually asked. Both are
recorded because the reasoning that produced them was plausible and will be
tempting again.

### Wrong answer 1, and the question that broke it

First diagnosis: two chained gain stages — the puck drives the speaker's own
amplifier *and* sends HID volume keys the host acts on. A hwdb entry was written
to stop the host half.

Then: *why do they work on Windows?* A puck wired straight to the speaker's
amplifier would misbehave under every OS, so the second stage looked impossible
and the hwdb entry was reverted.

### Wrong answer 2, and the test that broke it

Second diagnosis: a single stage, made uneven by arithmetic. That part is real
and is documented below, but it was treated as the *whole* explanation, and the
Windows argument above was treated as proof that no second stage existed.

The mistake was reasoning from Windows' behaviour to the device's wiring instead
of measuring the device. The measurement is easy and should have come first:
comment out the two volume binds in `keybinds.kdl` (niri auto-reloads), freeze
the host volume, and turn the puck. If loudness changes, the host is not
involved and the puck reaches the amplifier directly.

It changes. **The second stage is real.** A capture of `/dev/input/event8`
during the same test also shows exactly one press/release per detent, so it is
not key repeat and not a double-firing device:

```
  KEY VOLUMEDOWN press
  KEY VOLUMEDOWN release      (host volume held at 0.50 throughout)
```

### Why Windows does not have the problem

The Z407 advertises a real UAC Feature Unit, and the kernel read its range
successfully: min -13824, max -1024, res 256 in 1/256 dB units — **-54.0 dB to
-4.0 dB in 50 steps of exactly 1.00 dB.**

Windows drives that unit. So Windows' slider and the puck are two views of the
*same* gain element: the puck moves the amplifier, the Feature Unit reports it,
the slider tracks it. One stage, and it can never desync.

Linux cannot do this, because kernel 7.1 refuses the control at probe:

```
usb 3-2.3: 9:1: sticky mixer values (-13824/-1024/256 => -1024), disabling
```

`check_sticky_volume_control()` in `sound/usb/mixer.c` writes the control's min
and max, reads back, and if neither write moves the readback it decides the
control does nothing and declines to register it. The Z407 keeps only
`PCM Playback Switch`, the mute half of that same unit; the Yeti Nano on the
same bus keeps both halves, which is the comparison that makes it obvious.

There is no override — the call site is unguarded, `ignore_ctl_error` does not
reach it, and no `QUIRK_FLAG_*` in `sound/usb/usbaudio.h` skips it. It is also
new: `grep -c sticky sound/usb/mixer.c` gives 0 on 6.12.103 and 16 on the
running 7.1.8-cachyos.

So the host loses its one route to the amplifier and falls back to attenuating
in software — which *stacks on top of* the amplifier instead of being it. That
is the second stage, and the kernel's heuristic is what creates it. The device
may well be sticky exactly as the kernel claims; the puck owning the amplifier
directly is entirely consistent with the Feature Unit being inert.

### The cubic scale, and why "40% here" is not "40% on Windows"

PipeWire's volume is cubic — the number `wpctl` prints is the cube root of the
gain. Verified: `wpctl` showed 0.59 while `pw-dump` showed
`channelVolumes: [ 0.205375, ... ]`, and 0.59³ = 0.205379.

If Windows' slider is roughly linear in amplitude, that is about a 10 dB gap:

```
  Windows  20%   ->  amplitude 0.200  = -14.0 dB
  here     40%   ->  amplitude 0.064  = -23.9 dB
  here     58.5% ->  amplitude 0.200  = -14.0 dB   (the matching position)
```

The same curve means a flat percentage step is not a constant loudness step.
Noctalia steps 5% (measured: `volume-up` moved 0.49 to 0.54), which is 1.41 dB
at 0.90 and 10.57 dB at 0.10.

### The fix

`services.udev.extraHwdb` in the desktop's `default.nix` remaps the puck's three
volume usages to `reserved`, matched on this speaker's vendor:product so a
keyboard is unaffected. The puck then drives the amplifier alone — one stage,
uniform 1 dB steps, which is the Windows behaviour.

A hwdb remap rather than `LIBINPUT_IGNORE_DEVICE` because the same HID interface
carries play/pause/next/prev. The codes are HID consumer-page usages
(`c00e9`/`c00ea`/`c00e2`), not evdev keycodes.

With the amplifier as the volume control, **the sink belongs at 100%** —
anything less is a software stage stacked under the hardware one, and it also
throws away bit depth on a device that only accepts S16_LE. Raise it with the
puck turned down first: at 40% the software stage is -24 dB, so going to 100% is
a 24 dB jump.

### Reverted 2026-08-21: the hwdb remap is gone

At the operator's request, `services.udev.extraHwdb` was removed from the
desktop's `default.nix`. The puck's three consumer-page usages reach niri again,
so turning it moves both the amplifier and the host's software stage — the
two-stage behaviour described above, knowingly reaccepted. What is gained back
is Noctalia's OSD following the puck, and the puck being able to drive the host
volume at all.

Everything else in this entry still holds: the sink is still a software stage
stacked under the amplifier, the scale is still cubic, and the kernel still
refuses the Feature Unit. If uneven stepping or a dial/keyboard mismatch is
reported again, this is the cause and the block above is the fix to restore.

### Rejected: a dB-uniform stepping wrapper on the keyboard keys

A `volume-step up|down [dB]` wrapper was written, bound to the volume keys, and
verified on hardware (+1.000 dB at -18.6 dB, +1.001 dB at -55.2 dB, +3.000 dB
when asked for 3, and down-then-up returning to the exact starting value). Its
one non-obvious detail is worth keeping even though the code is gone: it read
via `pw-dump`, not `wpctl get-volume`, because wpctl rounds its *display* to two
decimals, and below ~0.26 on the cubic scale a 1 dB step is smaller than 0.01 —
a two-decimal read quantizes the step away and the volume sticks near the
bottom.

It was removed at the operator's request once the hwdb rule landed. With the
amplifier as the volume control and the sink parked at 100%, the keyboard keys
are a software trim that should not normally be used at all, so a second,
better-behaved way to drive that trim is complexity earning nothing. The
keyboard keys are back on plain `noctalia msg volume-up`/`volume-down`.

### The accepted trade-off, and the way out of it

With no reachable hardware control, the host cannot know where the amplifier is,
so Noctalia's OSD no longer follows the puck. That is how any speaker with a
physical knob behaves, and it is the price of the kernel's decision.

The realistic escape is analog rather than a kernel patch. The board's rear
line-out is a Realtek ALCS1200A whose `Master` control is
`min=0 max=87, dBscale-min=-65.25dB, step=0.75dB` — 88 uniform hardware steps
with a dB TLV, which PipeWire will delegate to. Over the jack, with USB
unplugged, the HID device does not exist, so the two-stage problem is
structurally impossible, the software attenuation goes away, *and* the OSD
tracks a real hardware control again. The cost is the PC's analog path (noise
floor, possible ground-loop hum) in place of the speaker's own DAC. The analog
profiles currently read `available: no` purely because nothing is plugged in.

Do not plug both: with USB connected for the media keys, the puck drives two
stages again and the hwdb rule is still required.

A kernel patch to re-enable the Feature Unit was considered and rejected —
`boot.kernelPatches` forces a from-source CachyOS build, losing the binary cache
that host's own config exists to preserve, at every kernel bump, and it would
only help if the unit is not genuinely inert, which is unknown. Revisit if
upstream adds a quirk for 046d:0a4c.

### The lesson worth keeping

Two diagnoses were argued from how the device behaves on another OS. The
question that settled it took about a minute: unbind the keys, freeze the host,
turn the knob. When a peripheral's *wiring* is in question, measure the
peripheral — another OS's behaviour is evidence about that OS's driver stack,
not about what is connected to what.

## "Zen crashes on start" was a window-geometry fight, not a crash

Reported twice as Zen crashing on launch. It never crashed. The symptom, once
described precisely, was: the window opens correctly maximized, flashes, and
settles at half the screen width.

### What it actually was

Three things had to line up:

1. `home/niri/cfg/rules.kdl`'s Zen window-rule set `open-maximized-to-edges
   true`. That is the correctly-maximized window visible for the first frame.
2. Zen then restores its own remembered window state from
   `~/.config/zen/<profile>/xulstore.json`, which held `"main-window": {
   "sizemode": "normal", "width": "1256", "height": "1374" }`. `sizemode:
   "normal"` makes Gecko send `xdg_toplevel.unset_maximized`.
3. niri honours that and drops the window to an ordinary tiled column at the
   *default* column width. `home/niri/cfg/layout.kdl` sets `gaps 16` and
   `preset-column-widths`, but never `default-column-width` — so it fell back
   to niri's built-in `proportion 0.5`.

The flash is step 2 → step 3.

The arithmetic is what confirmed it rather than merely fitting it. DP-1 is 2560
wide with `gaps 16`, so a half-proportion column is `(2560 − 3×16) / 2 = 1256`
— byte-for-byte the width already sitting in `xulstore.json`. Zen had recorded
the half-width niri gave it and was asking for it back on every launch.

That is also why it recurred, and why it will recur for any app with the same
shape: Zen rewrites `xulstore.json` with whatever geometry the window had when
it closed, so being wrong once makes it wrong permanently. Clearing the
`main-window` entry by hand fixes exactly one launch.

### The fix, and why it is the better of the two

The operator's fix was to drop `open-maximized-to-edges true` from the Zen rule
entirely and add `default-column-width { proportion 1.0; }` in its place.

The alternative on the table was to keep the maximize and *also* set
`proportion 1.0`, so that the un-maximize landed on full width. That removes
the half-sizing but not the flash, because the state transition still happens.
Removing the maximize outright means there is no maximized state for Zen to
un-maximize out of, so there is no transition at all.

It also resolved a pre-existing conditional in that block's own comments. The
`draw-border-with-background false` line had been carrying a note saying it was
"already correct the moment `open-maximized-to-edges` is ever removed"; a
full-width *column* still respects `gaps 16`, unlike maximized-to-edges, so the
focus ring now has real gap space to draw into and the empty-transparent-gap
artifact is gone. Nothing in the file uses `open-maximized-to-edges` any more,
which made a stale `open-maximized-to-edges false` in the Picture-in-Picture
rule dead code (it existed only to cancel the base rule); it was removed.

### What the diagnosis cost, and the lesson

Roughly the first half of the investigation was spent on the wrong question,
because "crash" was taken at face value. Ruling that out was worth doing and
was quick — `coredumpctl list | grep zen` was empty for the whole boot, there
were no minidumps and no `Crash Reports/` in either profile, and no OOM kill in
the journal — but it pointed nowhere, and neither did the two most
suspicious-looking numbers in the profile. `toolkit.startup.recent_crashes = 1`
turned out to be self-inflicted: a test launch had been killed by a 25-second
`timeout`, which lands inside Gecko's 30-second startup-crash window, so Zen
scored the investigation's own probe as a crash. A 28 MB `sessionstore.jsonlz4`
looked like a plausible cause of a slow, crash-like start and was not related
at all.

The question that actually solved it — "what does it look like on screen?" —
took one sentence to answer and should have been asked first. A user-supplied
noun for a symptom ("crash") is a hypothesis, not an observation. This is the
same lesson the Z407 investigation above ends on, arrived at from the opposite
direction: there, three wrong answers came from reasoning about a device
instead of measuring it; here, one wrong direction came from reasoning about a
symptom instead of looking at it.

## Moonshine's Desktop entry streamed a blank frame: `--session` vs. nesting

Reported as "the desktop entry for moonshine doesn't work — it opens and is
just blank, the only thing visible is the mouse". Following the lesson the Zen
investigation above ends on, that one sentence was taken as the primary
evidence rather than as a hypothesis, and it is what identified the failure
class immediately: a live cursor over nothing is the *greeter's `Writeback-1`*
shape — a compositor that is up and drawing a pointer but has no client
content — not a GPU, theming or codec problem.

### What was actually happening

`journalctl --user -u moonshine-session.service` had it in two lines, logged
every time the entry was launched:

```
WARN niri: running as a session but WAYLAND_DISPLAY is set, removing it
WARN niri: running as a session but DISPLAY is set, removing it
...
DEBUG niri::backend::tty: session is not active, starting libinput in paused state
```

niri chooses its backend by sniffing the environment: `WAYLAND_DISPLAY` or
`DISPLAY` set means the nested Winit backend, neither set means take over a DRM
device through the TTY backend. Moonshine's `make_envs()`
(`moonshine-core/src/session/application.rs`) sets both, plus
`MOONSHINE_WAYLAND_DISPLAY`, when it launches an app — that is the entire
mechanism by which an app reaches the per-stream compositor.

`niri --session` deletes both, unconditionally, *before* the backend is chosen.
That is not a bug: `--session` exists for the display-manager case, where a
leaked `WAYLAND_DISPLAY` from the greeter would be the bug, and niri's own
`--help` says so outright — "Do not set when running as a nested window".

So niri took the TTY backend, discovered it did not own seat0 (the local login
did), started libinput paused and rendered nothing anywhere. Moonshine's
compositor had no client at all, and the stream was a blank frame with only
Moonshine's own cursor composited onto it.

The `niri-session` shell wrapper was no escape, and was in fact how the bug got
in: its first branch is

```sh
if [ -n "${MANAGERPID:-}" ] && [ "${SYSTEMD_EXEC_PID:-}" = "$$" ]; then
    case "$(ps -p "$MANAGERPID" -o cmd=)" in
    *systemd*--user*) exec niri --session ;;
    esac
fi
```

Moonshine launches apps as transient units in the *user* manager, so that
branch always matches. The module's comment claimed this was the desirable
behaviour ("launched as one of Moonshine's transient units it detects that and
execs `niri --session`, which does the systemd/D-Bus session setup a display
manager would normally provide"). The setup half was right; the cost of getting
it was not noticed.

Confirmed rather than assumed, before any edit — running plain `niri` inside
the existing session, with `WAYLAND_DISPLAY=wayland-1` set:

```
INFO niri::niri: putting output winit at x=0 y=0
```

against the `niri::backend::tty` line from the stream. Backend selection, one
variable, no ambiguity.

### The fix

Run plain `niri`, and do by hand the session wiring `--session` would have
done. `modules/services/moonshine.nix` grows two `writeShellScript`s.

The wiring cannot run *before* niri, which is the non-obvious part. The values
that have to be published are the **nested** instance's `WAYLAND_DISPLAY` and
`NIRI_SOCKET` — not Moonshine's — and those do not exist until niri is up. They
do exist in the environment of niri's own startup command, which niri spawns as
a child specifically so it inherits them. So the wiring is
`niri -- <startup-script>`, and the script does exactly what niri's session mode
does, verified against the strings in the binary rather than from memory:

```
systemctl --user import-environment WAYLAND_DISPLAY DISPLAY XDG_CURRENT_DESKTOP NIRI_SOCKET
dbus-update-activation-environment --systemd <same four>
```

with `XDG_CURRENT_DESKTOP=niri` exported first, since niri only sets it for
children in session mode — the mode that cannot be used here — and the import
would otherwise have nothing to import.

One addition over what `--session` does: `systemctl --user start
graphical-session.target`. In a normal login that target is pulled in by
`niri.service`'s `BindsTo=`, and the compositor is deliberately not running as
that unit here. Without it nothing starts Noctalia, and the stream would be a
*nested* blank screen instead of a TTY-backend one — the same symptom, one
layer over, which is worth stating because it would have looked like the fix
had failed.

### The guard that matters more than the fix

`graphical-session.target` is per-**user**, not per-seat. A local login already
owns it, and the naive version of this fix is actively destructive in two
directions: taking the target over moves Noctalia off the physical screen and
onto the stream, and the teardown at the end of the stream
(`niri-shutdown.target`, which `Conflicts=` the session target) kills the
local session outright. Ending a remote stream should not log the user out of
the machine they are sitting at.

So the wrapper decides *before* starting niri:

```sh
if systemctl --user -q is-active graphical-session.target; then
  export MOONSHINE_OWNS_SESSION=0     # a local login owns it; touch nothing
else
  export MOONSHINE_OWNS_SESSION=1     # headless: drive it, and tear it down
  trap '...niri-shutdown.target...' EXIT
fi
```

and the startup script exits early, with a journal line saying why, when it
does not own the session. The degraded result — a nested niri with no bar and
no wallpaper — is still a working remote desktop, since keybinds and window
management are niri's own, and it is a far better outcome than either of the
two failure modes above. Headless, the case lingering exists for, takes the
other branch and gets the full session.

The trap is registered with `trap ... EXIT` on a shell that does **not** `exec
niri`, which is the reason the wrapper ends in a plain `niri -- ...` call: an
`exec` would replace the shell and the trap would never fire.

### Also changed

The Desktop entry moved under `lib.optionals config.features.niri`, matching
what the two launcher entries already do for `features.gaming`.
`features.moonshine` and `features.niri` are independent flags, and a streaming
host without a compositor was advertising a Moonlight card whose command is not
installed — the exact failure the module's own comment says the split exists to
prevent.

### Not verified live yet

Everything above is eval-clean, closure-builds, and both generated scripts were
read and syntax-checked; the backend claim at the heart of it was confirmed by
running niri nested. But per this repo's own rule, that is not verification: the
Desktop entry has not been streamed from a Moonlight client since the change,
and the branch that matters most — the headless one, where the session wiring
actually runs — cannot be exercised while anyone is logged in at the machine.
It needs a stream taken with no local login, checking that Noctalia's bar and
wallpaper appear and that ending the stream leaves the host healthy.

## `nix fmt` and the format check disagreed about which files exist

CI went red on `1e39492` (the Realtek/WoL commit) with a single line from
`check-format.drv`:

```
./hosts/the-entertaining-nios-desktop/default.nix: not formatted
```

Three `nixos-system-*` derivations were named alongside it in the failure
output, which is misleading: they were collateral in the same build set, not
independent failures. The whole of it was one file whose attrset argument
pattern had been left on one line, which nixfmt splits:

```nix
{ config, pkgs, vars, ... }:
```

Fixed by running the formatter and keeping only that hunk.

### The reason it slipped through, and the actual bug

`nix fmt` was `pkgs.nixfmt` bare, and it did not work at all: invoked with no
arguments, Nix hands the formatter no paths, so nixfmt read empty stdin and
died with `unexpected end of input expecting expression`. Invoked as
`nix fmt .` it did run — and reformatted all three generated
`hardware-configuration.nix` files, which `handWrittenNix` deliberately
excludes from the `format` and `deadnix` checks (and `statix.toml` from
statix). So the one command that fixes a format failure produced a diff the
checks did not ask for, every single time, and the habit that grows out of
that is to not run it.

Two exclusions for the same set of files, only one of which the formatter
knew about, is the "second source of truth" that ARCHITECTURE.md warns about,
in miniature.

### The fix

`formatter.${system}` is now a `pkgs.writeShellApplication` wrapping nixfmt:
it defaults to `.` when given no paths, expands a directory argument through
the same `find … -not -name 'hardware-configuration.nix'` the checks use, and
drops a generated file that is named explicitly on the command line. Both of
`nix fmt` and `nix fmt .` now work, and neither touches a generated file.

`writeShellApplication` rather than `writeShellScriptBin` for the shellcheck
pass and `set -euo pipefail`. Two Nix-side details worth remembering: every
bash `${...}` in the script body needs `''${...}`, and `read -r -d ''''` is
ambiguous inside an indented string — `read -r -d ""` is what bash wants
anyway, since both mean a NUL delimiter.

### Verified

Per this repo's rule that a check which cannot fail is worse than none, both
directions were tested rather than just the happy one:

- *Negative:* a deliberately misformatted `hardware-configuration.nix`
  survived both `nix fmt <that file>` and `nix fmt .` untouched, then was
  restored with `git checkout --`.
- *Positive:* a scratch file containing `let x  =  {a=1;   }; in x`, passed by
  path, was rewritten to multi-line RFC 166 style — so the wrapper is not
  simply excluding everything.

The first attempt at that positive control was worthless and was redone: it
appended lines to `modules/system/fonts.nix` and produced a two-line diff that
proved nothing about which files were in scope. A file-selection expression
that silently matches nothing passes just as green as one that works, and the
same is true of a test that would pass either way.

`nix flake check --no-build` is clean and all three lint checks build. Both
commits went green in CI on 2026-08-22 (19m6s and 20m38s), which matters here
beyond the usual: the formatter is a derivation now, so a shellcheck failure
or a bad Nix escape in it is a build failure rather than something only the
operator's machine would notice.

## Papirus folders reverted to default blue on every activation

**Reported** (2026-08-22, desktop): "I don't think nautilus folders are being
themed correctly (papirus folder theme)."

The Phase 6 fix above — symlinking Papirus-Dark's whole `places` directory at
the writable, recolorable `Papirus` copy — was still working exactly as
written. The bug was **timing**, not plumbing. `home/gtk.nix`'s
`seedPapirusIcons` re-copies the pristine store tree on *every* Home Manager
activation, which resets every folder icon to Papirus' default blue, and
Noctalia only runs a template when the theme actually changes. So folders sat
blue from one `nixos-rebuild switch` until the next wallpaper change. Confirmed
live rather than reasoned about: every `places` icon on the desktop resolved to
`folder-blue.svg` while the template's own cached `colors-final` said
`bluegrey`. This was recorded here as an "accepted trade-off" when the seed was
written; it wasn't acceptable, and that paragraph has been corrected.

**Fix**: the seed now ends by re-running Noctalia's *own* cached
`~/.local/state/noctalia/community-templates/papirus-icons/apply.sh`.
Reusing that script rather than calling `papirus-folders` directly keeps the
accent-to-Papirus-color mapping (an HSV nearest-match against the palette)
defined in exactly one place — Noctalia's. It reads `colors-final` and is a
no-op exiting 0 when that file doesn't exist, so it's safe on a host where
Noctalia has never run, and it's `|| true` besides: a theming refresh must
never fail activation.

**`papirus-folders` needs `getent` on the PATH, and eval cannot tell you
that.** Home Manager activation runs with a minimal PATH, so the call is
wrapped in an explicit `lib.makeBinPath`. The first version listed bash,
coreutils, findutils, gawk, gnused and gtk3 — everything an obvious reading of
the two scripts calls for — and still died with the script's own opaque
`Error: Failed to apply papirus-folders`. The real message one line up was
`papirus-folders: line 187: getent: command not found`: its `get_user_home()`
resolves the home directory with `getent passwd "$user"`. Adding `pkgs.getent`
fixed it. `pkgs.gtk3` is there for `gtk-update-icon-cache`, whose absence is
only a warning but a noisy one.

**How it was verified**, since none of the above is visible to `nix flake
check`: a throwaway script reproduced the activation sequence on the live
desktop in order — re-seed from the store path, re-link Papirus-Dark's `places`
dirs, run `apply.sh` under the same explicit PATH — printing `readlink -f` of
`inode-directory.svg` before and after. Before: `folder-blue.svg`. After:
`folder-bluegrey.svg`, and `folder-documents.svg` resolving to
`folder-bluegrey-documents.svg`, with no `gtk-update-icon-cache` warning. This
is the same lesson as every other entry in this file: the missing `getent`
would have shipped green through eval, a full closure build and CI alike.

## A video player, and Showtime's deadlock on GoPro telemetry tracks

Nothing in this repo could open a video: no module claimed a single `video/*`
default, so `xdg-open` fell through `mimeinfo.cache` to whatever happened to
be listed — the same gap `home/loupe.nix` closed for images and
`home/papers.nix` for PDFs, one week and one file type apart.

GNOME's **Showtime** was chosen first, on the same reasoning that picked
Papers over Zathura and Okular: it is GTK4/libadwaita like Nautilus, Loupe and
Papers, so it inherits the existing Papirus/Bibata/adw-gtk3 theming with
nothing new to declare. Celluloid, bare mpv and VLC were the alternatives.
`home/showtime.nix` was written, evaluated clean, and switched onto the
desktop — and then the operator reported that videos still would not open.

### The symptom, and why it is not what it looks like

`xdg-open` on a GoPro `.MP4` produced **no window at all**. Not a black
window, not an error — `niri msg windows` listed nothing, and a
`WAYLAND_DEBUG=1` trace showed **zero `xdg_surface` traffic**: the client
connected to the compositor, bound its globals, created GL contexts, and never
created a toplevel. Meanwhile the process kept running and the audio played.

The mime wiring was not at fault and was ruled out first:
`xdg-mime query default video/mp4` returned `org.gnome.Showtime.desktop`, the
entry was on `/etc/profiles/per-user/ol/share/applications`, and Showtime's own
journal showed it receiving the file (`Playing video: file:///…005.MP4`).

Ruling out a GTK-level problem took a control: a minimal PyGObject
`Adw.ApplicationWindow` run against Showtime's *own* interpreter, typelibs and
site-packages presented and mapped fine. So GTK4, libadwaita, PyGObject and
the compositor were all working.

Instrumenting the app itself is what found it. A `sitecustomize.py` on
`PYTHONPATH` (the wrapper does not set that variable, so it passes through)
patched `Window.present`, `Application.do_activate` and `do_open` to log:
`do_activate` ran, a `Window` was constructed — and `present()` was never
called. A timeout source added to the main loop from the same patch **never
ticked**, which said the GLib main loop was not running at all; the playback
log lines were coming from GStreamer's own threads.

`faulthandler.register(signal.SIGUSR1)` then dumped the stack of the wedged
process, and named the line:

```
File ".../showtime/widgets/window.py", line 784 in _on_missing_plugin
File ".../showtime/play.py", line 136 in _on_pipeline_bus_message
```

```python
if partially_missing := (
    self.pipeline.get_state(Gst.CLOCK_TIME_NONE)[0]   # infinite timeout, main thread
    != Gst.StateChangeReturn.FAILURE
):
```

A missing-plugin bus message, handled on the main thread with an *infinite*
`get_state` timeout, deadlocks the main loop before `win.present()` is ever
reached. Stubbing out that one handler made the window appear immediately
(`mapped=True`), which confirmed the causal chain rather than inferring it.

### The missing "codec" is not a codec, and not HEVC

The obvious next thought — install the codec — was tested and is wrong. Run
with Showtime's complete plugin set (all seven of base/good/bad/ugly/rs/libav/
core; an early run with a truncated `GST_PLUGIN_SYSTEM_PATH_1_0` falsely
showed H.264 and AAC missing too, which is a warning about how easy this
variable is to get wrong):

```
container #0: Quicktime
  video #1: H.264 (High Profile)
  audio #2: MPEG-4 AAC
  unknown #3: meta/x-gst-fourcc-gpmd
Missing plugins
 (…|meta/x-gst-fourcc-gpmd decoder|…)          ← the only one
```

Both a 2015 and a 2024 GoPro clip are H.264 + AAC with no missing media
decoder — the footage is not HEVC, which was the operator's guess. The one
"missing decoder" is for `gpmd`, GoPro's GPMF telemetry track (GPS,
accelerometer, gyro). `meta/x-gst-fourcc-<fourcc>` is not a codec name at all:
it is the placeholder caps `qtdemux` invents for any track type it does not
recognise. Grepping the whole plugin set, the only binary containing the
string `x-gst-fourcc` is `libgstisomp4.so` — the demuxer that *produces* the
label — and nothing anywhere contains `gpmd`. There is no plugin to install,
here or in any distro, because the track is sensor data rather than media.

The trap is broader than one camera: the same unknown-side-track shape is
`mett` in Pixel/iPhone video (upstream issue #277) and `djmd`/`dbgi` in DJI
footage (#299). A non-GoPro phone video played in Showtime perfectly.

### Upstream state, checked before deciding

- [#299](https://gitlab.gnome.org/GNOME/showtime/-/issues/299), opened
  2026-08-03, **still open**, no comments, no linked MR — the same deadlock,
  reported against DJI files. It also names a consequence not yet hit here:
  the hung process keeps the `org.gnome.Showtime` D-Bus name, so later
  launches fail to register until `pkill -9`.
- [MR !96 "Set timeout for get_state()"](https://gitlab.gnome.org/GNOME/showtime/-/merge_requests/96),
  opened 2026-07-27, not a draft, no conflicts, **unmerged**. One line:
  `Gst.CLOCK_TIME_NONE` → `Gst.SECOND`. `main` still carries the blocking call.

That MR was applied to a scratch copy and tested on the offending file. The
deadlock does go away — the window opens and sizes itself — but it lands on a
**"Missing Plugin" / "Unable to Play Video" status page, paused**, needing a
"Try Anyway" click. Read out of the live widget tree rather than guessed:
`placeholder_child=StatusPage:Missing Plugin … paused=True`. That is upstream
issues #298 and #277 in their own right. So the patch fixes the hang and not
the experience.

### Decision

**Celluloid**, in `home/celluloid.nix`. GTK4/libadwaita, so the theming
argument that picked Showtime still holds, but mpv underneath, which ignores
the telemetry track entirely — verified live on the exact file that deadlocks
Showtime.

Rejected: keeping Showtime as-is (unusable on most of the operator's library);
carrying MR !96 as a local patch (would need an `overlays/` directory this
repo does not have, to buy a per-file "Try Anyway" click).

**Revisit condition**, also recorded at the top of `home/celluloid.nix`: this
is about one upstream bug, not about mpv vs. GStreamer. If !96 lands *and* a
GoPro clip plays without the missing-plugin prompt, Showtime is the better fit
for the rest of the session and this should be switched back.

Only the `video/*` half of Celluloid's desktop entry is claimed. Its ~60
`audio/*` types and its `x-scheme-handler/rtsp` family are left alone: no
module in this repo owns an audio default today, and making the video player
the system's music handler is a separate decision from "videos should open in
something".

Verified live on the desktop 2026-08-23: GoPro clips open and play through
`xdg-open`.

## An audio player, and why a desktop entry's `MimeType=` is not the list to claim

Decibels closes the last of the four file-type gaps (`home/loupe.nix` images,
`home/papers.nix` PDFs, `home/celluloid.nix` video). It is GNOME's own audio
player — GTK4/libadwaita, so it inherits the existing theming — and
deliberately a *single-file* player with no queue and no library, which is
exactly the handler role. `home/feishin.nix` stays the library/streaming
client; the two don't overlap. Amberol was the alternative: a queue player
that will play a folder through, but its desktop entry also claims
`inode/directory`, which would have had to be left unclaimed anyway so
Nautilus keeps owning folders.

The part worth remembering is the MIME list. Every previous module in this
family took the app's own packaged `MimeType=` line as the set to claim.
That would have quietly failed here. Decibels' entry is written almost
entirely in legacy aliases, and shared-mime-info at this flake's pin resolves
real files to the canonical names instead:

| file | entry claims | `globs2` actually returns |
| --- | --- | --- |
| `.flac` | `audio/x-flac` | `audio/flac` |
| `.mp3` | `audio/x-mp3`, `audio/x-mpg` | `audio/mpeg` |
| `.ogg` / `.oga` / `.opus` | `audio/x-vorbis+ogg`, `audio/x-opus+ogg` | `audio/ogg` |
| `.m4a` | `audio/x-m4a` | `audio/mp4` |
| `.aac` | `audio/x-aac` | `audio/aac` |
| `.wav` | `audio/wav`, `audio/x-pn-wav` | `audio/vnd.wave` |

So claiming the entry's list verbatim would have registered defaults under
names nothing on this system produces, and left most of a real music library
with no default at all — passing eval, passing activation, and only showing
up as "the music still opens in the browser". The list in `home/decibels.nix`
is built from `shared-mime-info`'s `globs2` instead, keeping the
specific-alias spellings (`audio/x-vorbis+ogg`, `audio/x-opus+ogg`,
`audio/x-wav`) that content sniffing can still return alongside the canonical
ones. A default set in `mimeapps.list` is honoured by GIO whether or not the
target entry declares that type, which is what makes claiming the canonical
names work.

`.m3u` (`audio/x-mpegurl`, `application/vnd.apple.mpegurl`) is deliberately
left unclaimed: Decibels has no playlist support, so it would open the first
track and silently drop the rest.

Verified live on the desktop 2026-08-23: music opens in Decibels.

**Generalisation for the next handler module:** read `MimeType=` to learn
what the app *can* open, then check what the files themselves resolve to
before deciding what to claim. The two lists are not the same document, and
the failure mode of trusting the first one is silent.

## The 2026-08-23 handler audit: what is claimed, and what is deliberately not

With images, PDFs, video and audio all handled, the remaining question was
what else a common file could be. Answered by method rather than memory:
resolve ~120 common extensions through `shared-mime-info`'s `globs2`, diff
the result against the defaults `home/xdg-mime-apps.nix` actually generates,
then check which *installed* apps already declare the leftovers in their own
desktop entries. Two of the gaps closed with no new package.

**Source files (`home/neovim.nix`).** Neovim owned 19 text types, but
shared-mime-info gives most languages a type of their own — so `.py`, `.c`
and `.tex` opened in an editor while `.rs`, `.go`, `.lua`, `.js`, `.css`,
`.scss`, `.sql`, `.php`, `.rb`, `.pl`, `.kt`, `.cs`, `.rst`, `.bib` and
`.patch`/`.diff` had no default. They never fell back to `text/plain`,
because they *do* match a glob; they simply matched a name nothing claimed.
Fifteen types added.

`.ts` is excluded on purpose and is worth knowing about: shared-mime-info
resolves it to `text/vnd.trolltech.linguist`, a Qt translation format, not
TypeScript. Claiming it would register the editor for the wrong thing.
TypeScript sources reach Neovim through `text/plain`, like `.nix` and
`.conf`.

**Archives (`home/nautilus.nix`).** `.zip`, `.tar`, `.gz`, `.7z`, `.rar`,
`.xz`, `.zst` had no default, and the reflex is to add an archive manager.
Not needed: Nautilus extracts archives itself via gnome-autoar and already
declares all 21 of those types in its packaged desktop entry. It was a
candidate handler the whole time with nothing pointing at it — the
declared-but-not-default gap again. Registering it adds nothing to the
closure. Opening an archive lands in Nautilus' extract flow, not a browsable
archive view; file-roller would be a separate decision and wasn't wanted.

Both verified live on the desktop 2026-08-23, and not by resolution alone —
`xdg-mime query filetype` was checked against real sample files for each new
type, then `xdg-open` was run and the resulting window confirmed in
`niri msg windows`. A `.rs` opened Neovim in Ghostty; `a.zip` extracted to a
sibling directory and opened it in Nautilus. Resolution being right is not
the same as a window appearing — that is the whole lesson of the Showtime
entry above.

**Left unhandled, deliberately.** Each of these needs an application this
repo does not install, so they are a "do you want this app" question rather
than a wiring gap. Recorded so the next audit doesn't re-derive the list:

| Types | Would need |
| --- | --- |
| `.docx .xlsx .pptx .odt .ods .odp .doc .xls .ppt .rtf` | LibreOffice (~1 GB closure) or OnlyOffice |
| `.epub .mobi .azw3` | Foliate — Papers is PDF/DjVu/comics only and cannot do ebooks |
| `.ttf .otf .woff .woff2` | `gnome-font-viewer` (small) |
| `.stl .3mf .step` | FreeCAD is installed and already declares `model/stl`, but is slow for a double-click preview |
| `.ics .vcf` | a calendar/contacts app; nothing in this stack is close |

Not flagged at all, and not worth revisiting: `.iso .deb .rpm .exe .msi
.apk .torrent .psd .xcf .blend .ai`. Either meaningless on NixOS or needing
an application well outside this stack.
