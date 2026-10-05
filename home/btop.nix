# btop, the resource monitor.
#
# On a niri host, color_theme names the theme file Noctalia's builtin "btop"
# template writes to ~/.config/btop/themes/noctalia.theme. Declaring it here
# is load-bearing, not cosmetic: that template's apply.sh otherwise rewrites
# btop.conf in place to select the theme, which would fail against this
# module's read-only store symlink. With the exact line already present the
# script takes its no-op branch and only signals a running btop to reload.
# Without Noctalia (the laptop) there is no such file, so the line is left
# out and btop keeps its built-in default.
#
# Self-gates on osConfig.features.workstation, like the rest of the
# operator's terminal environment.
{ lib, osConfig, ... }:
lib.mkIf osConfig.features.workstation {
  programs.btop = {
    enable = true;
    settings = {
      # btop otherwise tries to write its settings back to btop.conf on exit,
      # which is a store symlink here; changes made in the UI last only for
      # that session.
      save_config_on_exit = false;
    }
    // lib.optionalAttrs osConfig.features.niri {
      color_theme = "noctalia";
    };
  };
}
