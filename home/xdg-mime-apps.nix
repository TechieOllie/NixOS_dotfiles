# Owns `~/.config/mimeapps.list` — the file that decides which application
# handles which MIME type and URL scheme, and therefore what `xdg-open` (so:
# a link clicked in Vesktop, Obsidian, VS Code or Nautilus) actually launches.
#
# This exists because of a trap in home-manager's `xdg.mimeApps`: modules can
# populate `defaultApplications` freely whether or not the module is enabled,
# and nothing warns when it isn't — the associations are simply computed and
# discarded. home/zen-browser.nix's `setAsDefaultBrowser = true` hit exactly
# that. It routes through the zen-browser flake's own
# hm-module/default-browser.nix, which sets fifteen correct
# `xdg.mimeApps.defaultApplications` entries (http, https, text/html, ...)
# pointing at zen-beta.desktop, but never sets `xdg.mimeApps.enable`. With it
# false, home-manager writes no mimeapps.list at all, so all fifteen were
# inert and only the `BROWSER` environment variable — which most GUI apps
# ignore in favour of xdg-open — actually took effect.
#
# It looked like it worked. `xdg-settings get default-web-browser` on the VM
# reported zen-beta.desktop even with no association on disk, because with no
# explicit default xdg falls back to scanning mimeinfo.cache and Zen was the
# only registered http handler. That fallback is incidental, not a setting:
# it depends on what else happens to be installed, so it would quietly pick a
# different browser the moment a second one landed, and it never applied to a
# freshly-provisioned host in a predictable way.
#
# `enable` lives here rather than in home/zen-browser.nix on purpose. It is
# not a browser setting — it's the switch that decides whether *any* module's
# mime associations reach disk (Vesktop's discord scheme handler goes through
# the same file). Buried in one app's module it would be a landmine for the
# next one. Same reasoning and same shape as home/xdg-user-dirs.nix.
#
# Note that enabling this makes home-manager take ownership of a file that
# was previously app-owned mutable state — the recurring shape in this repo's
# gotchas. On an already-provisioned host `~/.config/mimeapps.list` already
# exists as a plain file that Vesktop and `xdg-settings` wrote themselves,
# and home-manager's own module does *not* mark it `force` (checked in
# modules/misc/xdg/mime-apps.nix at the pinned revision — it only sets
# `.source`), so the first activation would abort with the familiar
# "existing file would be clobbered". Forced below rather than left to a
# one-off manual `rm`, so a rebuild converges on every host without a
# documented hand step.
#
# Anything only recorded in that file at runtime is lost when it's replaced,
# which is why the discord handler is restated below rather than inherited
# from whatever Vesktop happened to write.
#
# Self-gates on osConfig.features.niri, same convention as
# home/xdg-user-dirs.nix — default applications only matter where there are
# GUI applications to launch.
#
# This module owns the *file*; each application owns its own *associations*
# and declares them in its own module — Zen's arrive from the zen-browser
# flake's hm-module (at `lib.mkDefault`, so they stay overridable),
# Neovim's from home/neovim.nix, Vesktop's from home/vesktop.nix. Nothing
# app-specific belongs here, or this turns back into the central list that
# every module has to be kept in sync with.
{ lib, osConfig, ... }:
lib.mkIf osConfig.features.niri {
  xdg.mimeApps.enable = true;

  # See the note above: home-manager won't overwrite the pre-existing
  # unmanaged file on its own. Only ~/.config/mimeapps.list needs this — the
  # module also writes the deprecated ~/.local/share/applications/mimeapps.list
  # location, but nothing had ever created that one.
  xdg.configFile."mimeapps.list".force = true;
}
