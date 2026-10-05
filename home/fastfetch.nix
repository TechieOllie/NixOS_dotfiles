# fastfetch, the system-summary tool. Package only, no config.
#
# Noctalia's "fastfetch" community template is deliberately not enabled:
# its apply.sh merges colours into ~/.config/fastfetch/config.jsonc in
# place, the same conflict that rules out the official starship and lazygit
# templates — and it refuses to run at all without that file. Unconfigured,
# fastfetch draws with the terminal's ANSI palette, which Ghostty's template
# already keeps in step with the wallpaper, so nothing is lost.
#
# Self-gates on osConfig.features.workstation, like the rest of the
# operator's terminal environment.
{
  pkgs,
  lib,
  osConfig,
  ...
}:
lib.mkIf osConfig.features.workstation {
  home.packages = [ pkgs.fastfetch ];
}
