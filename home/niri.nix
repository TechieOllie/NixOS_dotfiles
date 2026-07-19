# User half of Niri (keybindings, layout, appearance) — the system half
# (package, session entry, greetd) lives in modules/desktop/niri.nix. Ported
# from the operator's own working CachyOS niri config rather than invented
# from scratch. Self-gates on osConfig.features.niri the same way system
# modules gate on config.features.niri, so this can be unconditionally
# imported from home/default.nix regardless of which hosts actually use it.
{
  lib,
  config,
  osConfig,
  vars,
  ...
}:
let
  # Console keymaps (vars.system.keyMap) and XKB layout/variant pairs are
  # different naming schemes; only one mapping exists because only one
  # keymap value exists across all hosts so far.
  xkbLayouts = {
    "fr-pc" = {
      layout = "fr";
      variant = "azerty";
    };
  };
  xkb =
    xkbLayouts.${vars.system.keyMap}
      or (throw "home/niri.nix: no XKB mapping for keyMap '${vars.system.keyMap}' — add one to xkbLayouts.");

  # Static (non-templated) KDL files are symlinked straight to this repo's
  # own live clone at ~/.dotfiles instead of being copied into the Nix
  # store — same convention as wallpaper.directory in home/noctalia.nix,
  # see docs/live-dotfiles.md for why. Editing a keybind then just needs
  # niri to reload its config (Mod+Shift+/ or a niri restart), not a
  # nixos-rebuild switch. Requires ~/.dotfiles to exist — see that doc.
  dotfilesNiri = "/home/${vars.user.name}/.dotfiles/home/niri";
  mkLiveFile = relPath: config.lib.file.mkOutOfStoreSymlink "${dotfilesNiri}/${relPath}";
in
lib.mkIf osConfig.features.niri {
  xdg.configFile = {
    # force: niri creates its own built-in default config.kdl on first run
    # if none exists yet — which happens before Home Manager's first-ever
    # activation on any host, since niri gets used (via greetd) well before
    # a `nixos-rebuild switch` runs. Without force, HM refuses to clobber
    # that pre-existing unmanaged file. Still needed with an out-of-store
    # symlink — the clobber check is about the destination, not about
    # where the symlink ultimately points.
    "niri/config.kdl" = {
      source = mkLiveFile "config.kdl";
      force = true;
    };
    # niri/noctalia.kdl is deliberately NOT managed here, and no longer
    # exists in this repo at all (was home/niri/noctalia.kdl, v4-generated
    # colors, deleted). Confirmed live that Noctalia v5's own template
    # engine writes this file itself — "[WRN] [template_engine] failed to
    # open template output .../niri/noctalia.kdl" showed up in its log
    # until this stopped being a Nix-managed symlink into the read-only
    # store. config.kdl's `include "./noctalia.kdl"` stays — it's including
    # whatever Noctalia writes at runtime, not anything from this repo.
    "niri/cfg/animation.kdl".source = mkLiveFile "cfg/animation.kdl";
    "niri/cfg/display.kdl".source = mkLiveFile "cfg/display.kdl";
    "niri/cfg/keybinds.kdl".source = mkLiveFile "cfg/keybinds.kdl";
    "niri/cfg/layout.kdl".source = mkLiveFile "cfg/layout.kdl";
    "niri/cfg/misc.kdl".source = mkLiveFile "cfg/misc.kdl";
    "niri/cfg/rules.kdl".source = mkLiveFile "cfg/rules.kdl";

    "niri/cfg/input.kdl".text = ''
      // ────────────── Input Configuration ──────────────
      // https://github.com/YaLTeR/niri/wiki/Configuration:-Input

      input {
          keyboard {
              xkb {
                  layout "${xkb.layout}"
                  variant "${xkb.variant}"
              }
              numlock // Enable numlock on startup
          }

          touchpad {
              tap // Enable tap-to-click
              natural-scroll // Enable natural (macOS-style) scrolling
          }

          //focus-follows-mouse // Automatically focus windows under the mouse pointer
          workspace-auto-back-and-forth // Enable workspace back & forth switching
      }
    '';

    # No cfg/autostart.kdl / spawn-sh-at-startup here at all (dropped, along
    # with its include in config.kdl) — this repo's autostart convention is
    # systemd user services bound to graphical-session.target (matching
    # Noctalia's own systemd.enable + launch_apps_as_systemd_services
    # above), not niri's spawn-sh-at-startup: proper start/stop lifecycle,
    # restart-on-failure, journalctl logging, and no sleep-N race-condition
    # hacks. The file's only remaining content (a vesktop spawn) was
    # already inert — vesktop isn't packaged by this flake yet (Phase 5) —
    # so there was nothing left worth keeping the mechanism around for.
    # When each autostart app (Vesktop, Zen Browser, ...) gets its own
    # Home Manager module, add it there as
    # `systemd.user.services.<name> = { Unit.PartOf =
    # "graphical-session.target"; Unit.After = "graphical-session.target";
    # Install.WantedBy = [ "graphical-session.target" ]; ...  };` rather
    # than reviving this file.
  };
}
