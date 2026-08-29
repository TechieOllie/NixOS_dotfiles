# User-level Git config. No system half — pure user tool, own small file
# matching the home/starship.nix / home/lazygit.nix precedent. Ported from
# the operator's live ~/.gitconfig; the one entry NOT ported is a
# `[safe] directory` line scoped to a specific non-repo path irrelevant to
# any host this flake manages.
# Self-gates on osConfig.features.workstation: this is part of the
# operator's personal terminal environment, wanted only on machines they
# actually work on. inotmac is not one — ol holds an admin account there
# and nothing else — so the whole toolkit stays off it. Zsh and Starship
# are deliberately *not* on this flag: a login shell that behaves the way
# its owner expects is worth having even on a machine visited only to fix
# something.
{ lib, osConfig, ... }:
lib.mkIf osConfig.features.workstation {
  programs.git = {
    enable = true;

    settings = {
      user.name = "TechieOllie";
      user.email = "oliverwest06@outlook.com";
      init.defaultBranch = "main";
    };

    # Global gitignore, ported from ~/.config/git/ignore.
    ignores = [ "**/.claude/settings.local.json" ];

    # Auto-manages the [filter "lfs"] block already present in the
    # operator's live .gitconfig, rather than hand-copying it.
    lfs.enable = true;
  };
}
