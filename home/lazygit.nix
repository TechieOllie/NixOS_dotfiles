# User-level Lazygit config. No system half — same reasoning as
# home/starship.nix for why this is its own small file.
{ config, ... }:
{
  programs.lazygit = {
    enable = true;
    settings = {
      gui.nerdFontsVersion = "3";
      notARepository = "skip";
    };
  };

  # Merges this Nix-managed base config with Noctalia's separately
  # rendered theme-only file (home/noctalia.nix's custom "lazygit" user
  # template) at invocation time — native lazygit behavior
  # (comma-separated LG_CONFIG_FILE), not a Noctalia-specific mechanism.
  # Session-wide (not baked into the `lg` shell alias) so it applies to
  # any invocation of lazygit — a direct terminal call, Neovim's own
  # lazygit.nvim plugin shelling out to it, etc. — not just one alias.
  #
  # Deliberately uses ${config.xdg.configHome} (resolved by Nix at eval
  # time) rather than a literal "$XDG_CONFIG_HOME" in the value — that
  # variable isn't actually guaranteed to be set in the shell environment
  # home.sessionVariables gets sourced into, and confirmed live it
  # wasn't: the generated value resolved to the empty string, leaving
  # "/lazygit/config.yml" (missing the home directory entirely) and
  # breaking lazygit's config lookup both standalone and from Neovim's
  # lazygit.nvim plugin.
  home.sessionVariables.LG_CONFIG_FILE =
    "${config.xdg.configHome}/lazygit/config.yml,${config.xdg.configHome}/lazygit/themes/noctalia.yml";
}
