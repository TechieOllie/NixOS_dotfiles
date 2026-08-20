# GitHub CLI. A git companion, but it rides features.development rather than
# sitting next to home/git.nix ungated: git is how every host talks to this
# repo's own remote, whereas `gh` (PRs, issues, releases) is only useful on
# the machine where work actually gets done — the same axis home/jetbrains.nix
# and home/claude-code.nix vary along.
#
# Package plus settings only. Authentication is deliberately left to the app:
# `gh auth login` writes a real OAuth token into ~/.config/gh/hosts.yml, which
# is runtime state carrying a secret (see home/claude-code.nix). Home Manager
# would clobber that file if this module managed it, so it doesn't.
{
  lib,
  osConfig,
  ...
}:
lib.mkIf osConfig.features.development {
  programs.gh = {
    enable = true;

    settings = {
      # The per-host SSH key is already registered on GitHub, so cloning and
      # pushing go over SSH; without this `gh repo clone` would hand back an
      # https remote that has no credential helper behind it.
      git_protocol = "ssh";
    };
  };
}
