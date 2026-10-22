# Lazydocker, the Docker TUI — lazygit's sibling for containers. User-level
# only: the engine it talks to is modules/services/docker.nix.
#
# Self-gates on osConfig.features.docker rather than .workstation: it is
# useless without a daemon, and every docker host is a workstation anyway.
# Talking to the socket is enough to wake the socket-activated daemon, so
# opening it is also how Docker gets started on a laptop.
#
# No settings. 0.25's defaults already drive Compose as `docker compose`
# (the v2 plugin docker.nix installs), and its theme is ANSI colour names,
# which follow Ghostty's Noctalia palette with no template of its own —
# unlike lazygit's hex theme (home/noctalia.nix's "lazygit" user template).
{
  lib,
  osConfig,
  ...
}:
lib.mkIf osConfig.features.docker {
  programs.lazydocker.enable = true;

  # `lg` for lazygit lives in home/zsh.nix; `ld` would shadow the linker.
  programs.zsh.shellAliases.lzd = "lazydocker";
}
