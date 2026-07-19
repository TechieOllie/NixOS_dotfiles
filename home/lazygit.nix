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
}
