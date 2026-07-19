# User-level Lazygit config. No system half — same reasoning as
# home/starship.nix for why this is its own small file.
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
  home.sessionVariables.LG_CONFIG_FILE =
    "$XDG_CONFIG_HOME/lazygit/config.yml,$XDG_CONFIG_HOME/lazygit/themes/noctalia.yml";
}
