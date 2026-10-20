# Moonlight — the client half of game streaming, for playing the desktop's
# games from another machine over the tailnet (the desktop runs Moonshine,
# modules/services/moonshine.nix). Rides features.gaming like
# home/prismlauncher.nix, minus the host that *is* the streaming server: a
# Moonshine host streaming to itself has no use for the client.
#
# Package only. Paired hosts and their certificates live under
# ~/.config/Moonlight Game Streaming Project/, written by the client during
# pairing — runtime state, not a preference.
{
  pkgs,
  lib,
  osConfig,
  ...
}:
lib.mkIf (osConfig.features.gaming && !osConfig.features.moonshine) {
  home.packages = [ pkgs.moonlight-qt ];
}
