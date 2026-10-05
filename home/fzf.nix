# fzf, plus its zsh key bindings: Ctrl-R fuzzy history, Ctrl-T to insert a
# file path, Alt-C to cd into a subdirectory. Home Manager sources the
# bindings after oh-my-zsh (initContent order 910), so they win over it.
#
# fd is the file source throughout — it respects .gitignore and skips .git,
# where fzf's default `find` walk would list every object in a repo. The
# previews use bat and eza, which ride the same flag as this module.
#
# Colours come from Noctalia's "fzf" community template (home/noctalia.nix),
# which writes a shell snippet appending --color options to
# FZF_DEFAULT_OPTS. It is sourced from .zshrc rather than once per login so
# a new shell picks up a palette change; the variable is reset first because
# it is exported, and appending in every nested shell would pile up copies.
# That makes .zshrc the owner of FZF_DEFAULT_OPTS — put any base options in
# the reset line below, not in programs.fzf.defaultOptions, which it would
# discard. On a host without Noctalia the snippet never exists and fzf keeps
# its default colours.
#
# Self-gates on osConfig.features.workstation, like the rest of the
# operator's terminal environment.
{
  config,
  pkgs,
  lib,
  osConfig,
  ...
}:
let
  fd = lib.getExe pkgs.fd;
  findFiles = "${fd} --type f --hidden --exclude .git";
in
lib.mkIf osConfig.features.workstation {
  programs.fzf = {
    enable = true;

    defaultCommand = findFiles;

    fileWidget = {
      command = findFiles;
      options = [
        "--preview '${lib.getExe pkgs.bat} --color=always --style=numbers --line-range=:300 {}'"
      ];
    };

    changeDirWidget = {
      command = "${fd} --type d --hidden --exclude .git";
      options = [
        "--preview '${lib.getExe pkgs.eza} --tree --level=2 --color=always --icons=always {}'"
      ];
    };
  };

  home.packages = [ pkgs.fd ];

  programs.zsh.initContent = ''
    FZF_DEFAULT_OPTS=""
    if [[ -r "${config.xdg.configHome}/fzf/themes/noctalia.sh" ]]; then
      source "${config.xdg.configHome}/fzf/themes/noctalia.sh"
    fi
  '';
}
