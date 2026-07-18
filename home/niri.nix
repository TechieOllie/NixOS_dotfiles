# User half of Niri (keybindings, layout, appearance) — the system half
# (package, session entry, greetd) lives in modules/desktop/niri.nix. Ported
# from the operator's own working CachyOS niri config rather than invented
# from scratch. Self-gates on osConfig.features.niri the same way system
# modules gate on config.features.niri, so this can be unconditionally
# imported from home/default.nix regardless of which hosts actually use it.
{ lib, osConfig, vars, ... }:
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
in
lib.mkIf osConfig.features.niri {
  xdg.configFile = {
    # force: niri creates its own built-in default config.kdl on first run
    # if none exists yet — which happens before Home Manager's first-ever
    # activation on any host, since niri gets used (via greetd) well before
    # a `nixos-rebuild switch` runs. Without force, HM refuses to clobber
    # that pre-existing unmanaged file.
    "niri/config.kdl" = {
      source = ./niri/config.kdl;
      force = true;
    };
    "niri/noctalia.kdl".source = ./niri/noctalia.kdl;
    "niri/cfg/animation.kdl".source = ./niri/cfg/animation.kdl;
    "niri/cfg/display.kdl".source = ./niri/cfg/display.kdl;
    "niri/cfg/keybinds.kdl".source = ./niri/cfg/keybinds.kdl;
    "niri/cfg/layout.kdl".source = ./niri/cfg/layout.kdl;
    "niri/cfg/misc.kdl".source = ./niri/cfg/misc.kdl;
    "niri/cfg/rules.kdl".source = ./niri/cfg/rules.kdl;

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

    "niri/cfg/autostart.kdl".text =
      ''
        // ────────────── Startup Applications ──────────────
        // https://github.com/YaLTeR/niri/wiki/Configuration:-Miscellaneous#spawn-sh-at-startup

            spawn-sh-at-startup "qs -c noctalia-shell"
            spawn-sh-at-startup "systemctl --user start niri-session.target"
            spawn-sh-at-startup "sleep 3 && vesktop"
      ''
      # VM-only: syncs cursor/clipboard/resolution with the SPICE client (see
      # CLAUDE.md's Phase 3 note) — niri doesn't autostart XDG session helpers
      # the way a full DE would, so this has to be spawned explicitly.
      + lib.optionalString osConfig.services.spice-vdagentd.enable
        "    spawn-sh-at-startup \"spice-vdagent\"\n";
  };
}
