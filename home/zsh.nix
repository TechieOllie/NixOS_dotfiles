# User half of Zsh (aliases, plugins, prompt hookup) — the system half
# (registering zsh in /etc/shells) lives in modules/system/shell.nix; the
# user's login shell assignment lives in modules/system/users.nix. Not
# gated on any osConfig.features.* flag — every real host wants a
# terminal environment (see ARCHITECTURE.md's "Features" section).
#
# Migrated off Antidote entirely onto native Home Manager mechanisms:
#   - rupa/z                          -> programs.zoxide.enable
#   - zdharma-continuum/fast-syntax-highlighting
#                                     -> programs.zsh.fastSyntaxHighlighting.enable
#     (built-in HM option; wires to pkgs.zsh-fast-syntax-highlighting)
#   - zsh-users/zsh-autosuggestions   -> programs.zsh.autosuggestion.enable
#     (built-in HM option; wires to pkgs.zsh-autosuggestions)
#   - zsh-users/zsh-history-substring-search and zsh-users/zsh-completions:
#     no built-in HM option for either, wired manually via
#     programs.zsh.plugins against plain nixpkgs packages.
#   - getantidote/use-omz + ohmyzsh/ohmyzsh path:lib + the three
#     path:plugins/* entries -> programs.zsh.oh-my-zsh.enable with
#     plugins = [...] below; enabling oh-my-zsh always sources the whole
#     of its lib/*.zsh as part of its own init, matching what "use-omz"
#     was doing.
#   - mattmc3/ez-compinit: NOT ported. nixpkgs doesn't package it, and
#     once oh-my-zsh is enabled, Home Manager's own enableCompletion
#     -triggered compinit call is skipped (oh-my-zsh calls compinit
#     itself, avoiding running it twice) — oh-my-zsh's own compinit call
#     already only rebuilds $ZSH_COMPDUMP when needed, covering the same
#     goal ez-compinit served.
{ pkgs, ... }:
{
  # Replaces rupa/z. Zsh integration (`zoxide init zsh`) is added
  # automatically once both this and programs.zsh.enable are true.
  programs.zoxide.enable = true;

  programs.zsh = {
    enable = true;
    enableCompletion = true;

    autosuggestion.enable = true; # zsh-users/zsh-autosuggestions
    fastSyntaxHighlighting.enable = true; # zdharma-continuum/fast-syntax-highlighting

    oh-my-zsh = {
      enable = true;
      plugins = [
        "colored-man-pages"
        "command-not-found"
        "extract"
      ];
    };

    # No built-in HM option covers either of these two — wired directly
    # against plain nixpkgs packages.
    plugins = [
      {
        # Antidote's `kind:fpath path:src` — fpath-only, nothing to
        # source. pkgs.zsh-completions ships only
        # share/zsh/site-functions/*, no *.plugin.zsh file; `file` is
        # left at its default (which doesn't exist in this package) —
        # harmless, home-manager's plugin-sourcing loop silently skips a
        # missing file. The site-functions dir is added to fpath
        # automatically by home-manager's plugin loader, which is all
        # this plugin needs to contribute.
        name = "zsh-completions";
        src = pkgs.zsh-completions;
      }
      {
        name = "zsh-history-substring-search";
        src = pkgs.zsh-history-substring-search;
        file = "share/zsh/plugins/zsh-history-substring-search/zsh-history-substring-search.plugin.zsh";
      }
    ];

    # zsh-history-substring-search does nothing by itself — it needs
    # these bindings to actually take over the up/down arrows (confirmed
    # by reading the plugin's own source: it contains no bindkey calls at
    # all). Not present in the operator's original .zshrc either, so this
    # plugin may have been inert there too; added here since it's clearly
    # what the plugin needs to function and is harmless either way.
    initContent = ''
      bindkey "$terminfo[kcuu1]" history-substring-search-up
      bindkey "$terminfo[kcud1]" history-substring-search-down
    '';

    shellAliases = {
      l = "ls --color=auto";
      ll = "ls -l --color=auto";
      la = "ls -a --color=auto";
      grep = "grep --color=auto";
      lg = "lazygit";
      q = "exit";
      cl = "clear";
      nv = "nvim";
      # `here="explorer.exe ."` dropped: WSL-only, not relevant on NixOS.
    };

    sessionVariables = {
      EDITOR = "nvim";
      VISUAL = "nvim";
      # Kept from the operator's original setup — harmless, matches real
      # desktop expectations. The qt6ct *package* is NOT added in this
      # phase; Qt/GTK theming is already a separate, tracked Phase 3 /
      # Noctalia TODO, so this is a no-op env var until that lands.
      QT_QPA_PLATFORMTHEME = "qt6ct";
      # Deliberately dropped, not ported:
      #   - WSL detection branch (not relevant on NixOS)
      #   - hardcoded opencode PATH line (/home/ol/... — operator-machine
      #     -specific, not portable)
      #   - NVM_DIR export + nvm sourcing (out of Phase 4 scope)
      #   - `register-python-argcomplete pipx` eval (out of Phase 4 scope,
      #     and unguarded — would error at shell start without pipx)
      #   - explicit SSH_AUTH_SOCK override (redundant with Phase 3's
      #     gcr-ssh-agent auto-export)
    };
  };

  # Not a programs.zsh option — home.sessionPath is the general Home
  # Manager mechanism (applies across shells/tools, not zsh-specific).
  home.sessionPath = [
    "$HOME/.local/bin"
    "$HOME/go/bin"
  ];
}
