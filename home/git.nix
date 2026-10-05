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
{
  config,
  pkgs,
  lib,
  osConfig,
  ...
}:
let
  # delta's colours, rendered by Noctalia on every palette change into a
  # file of their own and pulled into git's config with include.path — the
  # same separate-output-file shape as the lazygit and starship templates,
  # since ~/.config/git/config is a Home Manager store symlink.
  #
  # syntax-theme names the tmTheme Noctalia's "bat" template writes; delta
  # reads bat's theme cache directly (delta 0.19 and bat 0.26 share the
  # cache format), and that template's own hook rebuilds the cache.
  #
  # The added/removed line backgrounds keep the palette's own green and red
  # hues and only drop their lightness to background level (set_lightness is
  # 0-100), brighter for the changed words inside a line. Tuned for a dark
  # palette, which home/noctalia.nix pins with theme.mode = "dark".
  deltaThemePath = "${config.xdg.configHome}/git/noctalia-delta.gitconfig";
  deltaTemplate = pkgs.writeText "noctalia-delta.gitconfig.tmpl" ''
    [delta]
    	syntax-theme = noctalia
    	minus-style = syntax "{{colors.terminal_normal_red.default.hex | set_lightness 15}}"
    	minus-emph-style = syntax "{{colors.terminal_normal_red.default.hex | set_lightness 28}}"
    	plus-style = syntax "{{colors.terminal_normal_green.default.hex | set_lightness 13}}"
    	plus-emph-style = syntax "{{colors.terminal_normal_green.default.hex | set_lightness 25}}"
  '';
in
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

    # git skips a missing include silently, so before Noctalia's first
    # template pass delta just keeps its defaults. Includes come after the
    # main settings, so the rendered [delta] keys win over programs.delta's.
    includes = lib.optional osConfig.features.niri { path = deltaThemePath; };
  };

  # delta as git's pager: syntax-highlighted diffs, with `n`/`N` jumping
  # between files. A separate programs.* module since Home Manager split it
  # out of programs.git, and the git hookup now has to be asked for. Colours
  # come from the Noctalia-rendered include above; without Noctalia (the
  # laptop) delta keeps its defaults. lazygit uses it too: home/lazygit.nix.
  programs.delta = {
    enable = true;
    enableGitIntegration = true;
    options.navigate = true;
  };

  programs.noctalia.settings.theme.templates.user.delta = lib.mkIf osConfig.features.niri {
    input_path = deltaTemplate;
    output_path = [ deltaThemePath ];
  };
}
