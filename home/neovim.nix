# Neovim itself is NOT configured here — ~/.config/nvim is an ordinary,
# manually-cloned git checkout of github:TechieOllie/neovim_dotfiles (the
# operator's real, actively-edited config, using lazy.nvim + Mason). This
# file only provides the base toolchain that config needs but can't
# provide for itself: the neovim binary, and prerequisites lazy.nvim's
# plugin build steps / Mason's installed tools shell out to.
#
# Deliberately NOT native Nix (no programs.neovim, no vimPlugins) — a
# full native port was planned and drafted in detail, then reversed:
# every finding added friction (nvim-treesitter's breaking main-branch
# API rewrite needing manual translation, one plugin needing vendoring
# via fetchFromGitHub, no native lazy-loading without hand-rolling
# optional/packadd triggers, and Noctalia's own official "neovim"
# community template needing a compatibility hack since it assumes
# lazy.nvim's directory layout). None of that buys anything once
# lazy.nvim/Mason are kept anyway, since plugins still git-clone/download
# at runtime either way — so the config is rewritten upstream instead
# (github:TechieOllie/neovim_dotfiles) and treated as a live, externally
# -sourced directory, the same way it already was before this repo
# touched Neovim at all.
{ pkgs, lib, ... }:
let
  # The file types Neovim should own. Everything here is a format the
  # operator edits as source or config, and every name was verified against
  # this repo's own shared-mime-info by running `xdg-mime query filetype`
  # on a real file of each kind — guessing them is how you get an entry
  # that silently never matches (.nix and .conf, for instance, are both
  # plain `text/plain`, not a type of their own).
  #
  # text/html is deliberately absent: that one belongs to the browser.
  editableTypes = [
    "text/plain" # also .nix, .conf, and most dotfiles
    "text/markdown"
    "text/csv"
    "text/x-log"
    "application/json"
    "application/toml"
    "application/yaml"
    "application/xml"
    "application/x-shellscript"
    "text/x-python"
    "text/x-makefile"
    "text/x-c"
    "text/x-csrc"
    "text/x-chdr"
    "text/x-c++"
    "text/x-c++src"
    "text/x-c++hdr"
    "text/x-java"
    "text/x-tex"

    # Second pass (2026-08-23), from an audit of every common extension
    # against shared-mime-info's globs2: these all have a MIME type of
    # their own, so they never fell back to text/plain and had no default
    # at all. Same silent-gap shape as home/decibels.nix's alias problem.
    "text/rust" # .rs
    "text/x-go" # .go
    "text/x-lua" # .lua
    "text/javascript" # .js
    "text/css" # .css
    "text/x-scss" # .scss
    "text/x-patch" # .patch, .diff
    "text/x-rst" # .rst
    "text/x-bibtex" # .bib
    "text/x-kotlin" # .kt
    "text/x-csharp" # .cs
    "application/sql" # .sql
    "application/x-php" # .php
    "application/x-ruby" # .rb
    "application/x-perl" # .pl
    # Verified live on the desktop 2026-08-23: a .rs opens in Neovim inside
    # Ghostty via xdg-open, and every type above resolves through
    # `xdg-mime query default` to nvim.desktop.
    #
    # .ts is NOT here on purpose: shared-mime-info resolves it to
    # text/vnd.trolltech.linguist, a Qt translation file, not TypeScript.
    # Claiming it would be claiming the wrong format. TypeScript sources
    # reach Neovim through text/plain like .nix and .conf do.
  ];
in
{
  # git and yazi are deliberately NOT listed here even though
  # lazy.nvim/Mason need them (git for lazy.nvim's own bootstrap clone;
  # yazi for yazi.nvim) -- both are already installed by their own
  # dedicated modules (home/git.nix's programs.git.enable already pulls
  # in pkgs.git; home/yazi.nix installs yazi itself and carries its
  # Noctalia theming). Putting them here too would be a redundant second
  # place declaring the same package, for a tool this file doesn't
  # actually own. Everything below stays here because its only reason
  # for existing in this repo *is* Neovim/Mason's own needs -- if a
  # future phase adds general-purpose Python/Node/Go/PHP tooling on its
  # own merits, move the relevant entry to that phase's own module
  # instead of leaving it here as a coincidental side effect.
  home.packages = with pkgs; [
    neovim
    gnumake # telescope-fzf-native.nvim / LuaSnip jsregexp build steps
    gcc # nvim-treesitter's runtime parser compilation
    tree-sitter # the CLI itself -- the new main-branch nvim-treesitter
    # shells out to `tree-sitter build`, confirmed live ("ENOENT: no
    # such file or directory (cmd): 'tree-sitter'" without this); a C
    # compiler alone isn't enough for this rewritten version.
    ripgrep # Telescope live_grep / grep_string -- also on this repo's
    # planned general terminal-tool stack, but has no configuration of
    # its own to warrant a dedicated file (unlike yazi); fine here until
    # that changes.
    python3 # Mason's debugpy installer needs a python3 on PATH to build
    # its own venv (confirmed live: "Unable to find python3 installation
    # in PATH" without this) -- also just generally needed to run/debug
    # the Python code this config's LSP/DAP support is for in the first
    # place.

    # Mason's own installer prerequisites -- Mason downloads/builds most
    # LSP servers itself rather than us packaging each one directly (the
    # whole point of keeping Mason instead of going full-native Nix), but
    # its installers still shell out to these. All three confirmed live:
    # clangd needs unzip, pyright needs npm, sqls needs go.
    unzip
    nodejs # provides npm
    go
    php # phpactor and php-cs-fixer are themselves PHP applications --
    # confirmed live: "exec: php: not found" without this.
  ];

  # ── Default text editor ─────────────────────────────────────────────────

  # The CLI half. Lives here rather than in home/zsh.nix (where it used to)
  # because EDITOR is a fact about Neovim, not about one shell -- and
  # programs.zsh.sessionVariables only exports into interactive zsh, so a
  # bash shell, a script, or anything else invoking $EDITOR saw nothing set
  # at all. home.sessionVariables reaches every shell through
  # hm-session-vars.sh.
  home.sessionVariables = {
    EDITOR = "nvim";
    VISUAL = "nvim";
  };

  # The GUI half. Neovim's own packaged nvim.desktop is `Terminal=true`,
  # which delegates "find a terminal to run this in" to whatever does the
  # launching -- and in a bare niri session nothing does. glib looks for a
  # terminal from a hardcoded list (xterm, gnome-terminal, konsole, ...);
  # Ghostty isn't on it and there's no desktop environment to answer for
  # it. Confirmed live before writing this, and the failure is silent
  # rather than an error: `xdg-open somefile.txt` with text/plain already
  # resolving to nvim.desktop opened *Zen Browser*.
  #
  # So spawn the terminal explicitly instead of asking for one. This
  # deliberately reuses the `nvim` entry id, shadowing the package's own
  # copy (xdg.desktopEntries writes into ~/.local/share/applications, which
  # takes precedence over the profile's share/applications) rather than
  # adding a second, near-identical "Neovim" beside it in the launcher.
  # Same override-an-existing-entry pattern as home/vesktop.nix.
  xdg.desktopEntries.nvim = {
    name = "Neovim";
    genericName = "Text Editor";
    comment = "Edit text files";
    # -e must come last: Ghostty treats everything after it as the command.
    exec = "ghostty -e nvim %F";
    icon = "nvim";
    terminal = false;
    categories = [
      "Utility"
      "TextEditor"
      "Development"
    ];
    mimeType = editableTypes;
    settings.StartupNotify = "false";
  };

  # Advertising the types above only makes Neovim *a* handler for them.
  # Being the default is a separate statement, and it's this one that makes
  # a .txt from Nautilus open in an editor instead of falling to the
  # browser (application/json and text/plain are both in the zen-browser
  # flake's own list, at mkDefault, so these override cleanly). Needs
  # home/xdg-mime-apps.nix to be enabled to reach disk at all.
  xdg.mimeApps.defaultApplications = lib.genAttrs editableTypes (_: "nvim.desktop");
}
