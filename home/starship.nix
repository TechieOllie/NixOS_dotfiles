# User-level Starship prompt config. No system half — pure user tool,
# hence its own small file (one responsibility per module) rather than
# folded into home/zsh.nix; home/lazygit.nix gets the same treatment for
# the same reason. Zsh integration (`eval "$(starship init zsh)"`) is NOT
# hand-written here — programs.starship.enableZshIntegration defaults to
# true once both programs.zsh.enable and programs.starship.enable are
# true, and home-manager adds the eval line to .zshrc itself.
{
  programs.starship = {
    enable = true;

    # Ported verbatim from the operator's starship.toml.
    settings = {
      "$schema" = "https://starship.rs/config-schema.json";

      format = ''
        [┌─ ](bold green)$username$directory $git_branch$python
        [└─$character ](green bold) '';

      git_branch.format = "[$symbol$branch(:$remote_branch) ]($style)";

      python = {
        # `${symbol}` here is literal Starship template syntax, not Nix
        # interpolation — escaped as `\${symbol}` so Nix doesn't try to
        # resolve a `symbol` variable that isn't in scope. `\(`/`\)` are
        # Starship's own literal-parenthesis escapes, doubled (`\\(`,
        # `\\)`) so Nix emits a literal backslash instead of consuming it
        # as an escape of the following character.
        format = "[via \${symbol} (\\($virtualenv\\)) ]($style)";
        symbol = ""; # deliberately empty — operator's own choice, no icon
      };

      character.disabled = false;

      username.show_always = true;

      directory = {
        format = "[$path](blue bold)";
        truncation_length = 8;
        truncation_symbol = "…/";
      };
    };
  };
}
