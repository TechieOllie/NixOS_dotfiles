# User-level Starship prompt config. No system half — pure user tool,
# hence its own small file (one responsibility per module) rather than
# folded into home/zsh.nix; home/lazygit.nix gets the same treatment for
# the same reason. Zsh integration (`eval "$(starship init zsh)"`) is NOT
# hand-written here — programs.starship.enableZshIntegration defaults to
# true once both programs.zsh.enable and programs.starship.enable are
# true, and home-manager adds the eval line to .zshrc itself.
#
# The `settings` below carry an *inverted* gate, which is the only one of
# its kind in home/: they apply where Noctalia is **not**.
#
# On a niri host, home/noctalia.nix's custom "starship" user template is
# the sole owner of ~/.config/starship.toml, re-rendering the whole file
# on every wallpaper/palette change — so declaring settings here would be
# Home Manager and Noctalia's template engine fighting over one path, the
# conflict class this repo has already had to fix once for
# niri/noctalia.kdl. Hence nothing was declared here at all.
#
# That left a hole nobody noticed until inotmac: a host with no Noctalia
# gets no template pass, so ~/.config/starship.toml was never written by
# anything and Starship silently fell back to its built-in default prompt.
# Nothing is broken on such a host — the package is installed and the zsh
# eval line is present — which is exactly why it reads as "my theme isn't
# working" rather than as a missing file.
#
# So: the same prompt, defined twice, in the only two places that can
# reach their respective hosts. Keep the two in sync by hand if the shape
# changes; the palette deliberately does not match, since the whole point
# of the Noctalia copy is that its colours track the wallpaper and the
# whole point of this one is that it needs no such machinery.
{ lib, osConfig, ... }:
{
  programs.starship.enable = true;

  # Ported from home/noctalia-templates/starship.toml.tmpl, with its two
  # {{colors.*.hex}} placeholders replaced by static named colours —
  # nothing here can read a Noctalia palette, and a hardcoded hex would
  # only be one wallpaper's accent frozen in place.
  programs.starship.settings = lib.mkIf (!osConfig.features.niri) {
    format = ''
      [┌─ ](bold blue)$username$directory $git_branch$python
      [└─$character ](blue bold) '';

    git_branch.format = "[$symbol$branch(:$remote_branch) ]($style)";

    python = {
      format = ''[via ''${symbol} (\($virtualenv\)) ]($style)'';
      symbol = "";
    };

    character.disabled = false;
    username.show_always = true;

    directory = {
      format = "[$path](cyan bold)";
      truncation_length = 8;
      truncation_symbol = "…/";
    };
  };
}
