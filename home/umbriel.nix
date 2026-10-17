# User half of Umbriel (keybindings, layout, rules, appearance) — the system
# half (package, session entry, portal) lives in modules/desktop/umbriel.nix.
# Ported from home/niri/ rather than started from Umbriel's example config,
# and built the same way as home/niri.nix: self-gates on
# osConfig.features.umbriel, so home/default.nix can import it everywhere.
#
# Upstream's own Home Manager module (programs.umbriel.settings) is
# deliberately not used: it writes config.toml into the read-only store,
# which would take away the edit-and-it-reloads workflow below.
{
  lib,
  config,
  osConfig,
  vars,
  ...
}:
let
  xkb = import ../lib/xkb.nix vars.system.keyMap;

  # Static TOML files are symlinked straight to this repo's own live clone at
  # ~/.dotfiles instead of being copied into the Nix store — same convention
  # as home/niri.nix, see docs/live-dotfiles.md. Umbriel watches its config
  # and every include, through the symlinks, so a saved edit applies at once.
  dotfilesUmbriel = "/home/${vars.user.name}/.dotfiles/home/umbriel";
  mkLiveFile = relPath: config.lib.file.mkOutOfStoreSymlink "${dotfilesUmbriel}/${relPath}";
in
lib.mkIf osConfig.features.umbriel {
  xdg.configFile = {
    # force: Noctalia's builtin "umbriel" template creates a config.toml of
    # its own (just the include line) if none exists when it first runs, and
    # Home Manager refuses to clobber an unmanaged file without this.
    "umbriel/config.toml" = {
      source = mkLiveFile "config.toml";
      force = true;
    };
    # umbriel/noctalia.toml is deliberately NOT managed here: Noctalia's
    # template engine writes it, for the same reason home/niri.nix leaves
    # niri/noctalia.kdl alone. umbriel/style.toml comes from
    # home/noctalia.nix, next to the `style` block it renders.
    "umbriel/cfg/keybinds.toml".source = mkLiveFile "cfg/keybinds.toml";
    "umbriel/cfg/layout.toml".source = mkLiveFile "cfg/layout.toml";
    "umbriel/cfg/animation.toml".source = mkLiveFile "cfg/animation.toml";
    "umbriel/cfg/rules.toml".source = mkLiveFile "cfg/rules.toml";
    "umbriel/cfg/scratchpad.toml".source = mkLiveFile "cfg/scratchpad.toml";
    "umbriel/cfg/misc.toml".source = mkLiveFile "cfg/misc.toml";

    # Generated rather than live, because the keyboard layout comes from
    # vars — the same split as niri's cfg/input.kdl.
    "umbriel/cfg/input.toml".text = ''
      [input.keyboard]
      layout = "${xkb.layout}"
      variant = "${xkb.variant}"
      numlock_toggle = true

      [input.touchpad]
      natural_scroll = true

      [input.focus]
      follows_mouse = true
    '';
  };
}
