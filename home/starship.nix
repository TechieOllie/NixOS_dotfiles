# User-level Starship prompt config. No system half — pure user tool,
# hence its own small file (one responsibility per module) rather than
# folded into home/zsh.nix; home/lazygit.nix gets the same treatment for
# the same reason. Zsh integration (`eval "$(starship init zsh)"`) is NOT
# hand-written here — programs.starship.enableZshIntegration defaults to
# true once both programs.zsh.enable and programs.starship.enable are
# true, and home-manager adds the eval line to .zshrc itself.
#
# Deliberately no `settings` here — home/noctalia.nix's custom "starship"
# user template is the sole owner of ~/.config/starship.toml, rendering
# the whole file fresh on every wallpaper/palette change (see that file's
# theme.templates.user.starship for the actual config content, ported
# from what used to live here verbatim). `enable` alone still installs
# the package and adds the zsh-integration eval line; that's unrelated to
# the config file's content and unaffected by this.
{
  programs.starship.enable = true;
}
