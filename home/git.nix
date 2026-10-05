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

      # A pull that can't fast-forward stops and says so, rather than
      # silently creating a merge commit (git's default) or rewriting local
      # commits (pull.rebase). Diverged branches get an explicit choice.
      pull.ff = "only";
      # The first `git push` of a new branch sets its upstream itself.
      push.autoSetupRemote = true;
      # Remember how a conflict was resolved and replay it next time the
      # same one appears (a re-run rebase, a reverted-and-redone merge).
      rerere.enabled = true;
      # Lines that were moved rather than changed get their own colour.
      diff.colorMoved = "default";
    };

    # Global gitignore, ported from ~/.config/git/ignore.
    ignores = [ "**/.claude/settings.local.json" ];

    # Auto-manages the [filter "lfs"] block already present in the
    # operator's live .gitconfig, rather than hand-copying it.
    lfs.enable = true;
  };

  # delta as git's pager: syntax-highlighted diffs, with `n`/`N` jumping
  # between files. A separate programs.* module since Home Manager split it
  # out of programs.git, and the git hookup now has to be asked for. Theme
  # left to delta's own default — it reads bat's theme only through
  # BAT_THEME, which nothing here sets (see home/bat.nix for why bat's
  # config file belongs to Noctalia). lazygit uses it too: home/lazygit.nix.
  programs.delta = {
    enable = true;
    enableGitIntegration = true;
    options.navigate = true;
  };
}
