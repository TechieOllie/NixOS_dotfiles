# jq, for reading JSON: `nix eval --json`, Heroic's GamesConfig, Noctalia
# exports. Package only, no config.
#
# Self-gates on osConfig.features.workstation, like the rest of the
# operator's terminal environment.
{ lib, osConfig, ... }:
lib.mkIf osConfig.features.workstation {
  programs.jq.enable = true;
}
