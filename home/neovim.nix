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
{ pkgs, ... }:
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
}
