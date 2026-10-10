# dust, a du replacement that draws where disk space went as a tree of
# the largest directories. Package only; there is no config to set.
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
  home.packages = [ pkgs.dust ];
}
