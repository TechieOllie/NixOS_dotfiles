# Console keymap name -> XKB layout/variant, for the compositors' own
# keyboard config (home/niri.nix's input.kdl, home/umbriel.nix's
# input.toml). Console keymaps (vars.system.keyMap) and XKB layout/variant
# pairs are different naming schemes; only one mapping exists because only
# one keymap value exists across all hosts so far. Extracted once the second
# compositor needed the same table.
keyMap:
let
  xkbLayouts = {
    "fr-pc" = {
      layout = "fr";
      variant = "azerty";
    };
  };
in
xkbLayouts.${keyMap}
  or (throw "lib/xkb.nix: no XKB mapping for keyMap '${keyMap}' — add one to xkbLayouts.")
