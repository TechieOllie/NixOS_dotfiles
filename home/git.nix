# User-level Git config. No system half — pure user tool, own small file
# matching the home/starship.nix / home/lazygit.nix precedent. Ported from
# the operator's live ~/.gitconfig; the one entry NOT ported is a
# `[safe] directory` line scoped to a specific non-repo path irrelevant to
# any host this flake manages.
{
  programs.git = {
    enable = true;
    userName = "TechieOllie";
    userEmail = "oliverwest06@outlook.com";

    settings.init.defaultBranch = "main";

    # Global gitignore, ported from ~/.config/git/ignore.
    ignores = [ "**/.claude/settings.local.json" ];

    # Auto-manages the [filter "lfs"] block already present in the
    # operator's live .gitconfig, rather than hand-copying it.
    lfs.enable = true;
  };
}
