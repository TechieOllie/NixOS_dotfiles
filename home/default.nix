# Machine-agnostic entry point: every host's Home Manager user points here
# (see lib/mkHost.nix). Every home/*.nix module is imported from here; the
# modules themselves self-gate where they need to (osConfig.features.niri).
{ vars, ... }:
{
  imports = [
    ./niri.nix
    ./noctalia.nix
    ./cursor.nix
    ./gtk.nix
    ./qt.nix
    ./zsh.nix
    ./starship.nix
    ./neovim.nix
    ./lazygit.nix
    ./git.nix
    ./ghostty.nix
    ./yazi.nix
    ./vscode.nix
    ./zen-browser.nix
    ./vesktop.nix
    ./nautilus.nix
    ./loupe.nix
    ./papers.nix
    ./celluloid.nix
    ./decibels.nix
    ./xdg-user-dirs.nix
    ./xdg-mime-apps.nix
    ./feishin.nix
    ./obsidian.nix
    ./heroic.nix
    ./prismlauncher.nix
    ./kdeconnect.nix
    ./freecad.nix
    ./kicad.nix
    ./jetbrains.nix
    ./claude-code.nix
    ./gh.nix

    # GNOME-host app set (features.gnome) — only what GNOME does *not*
    # already ship. Its default install covers the document viewer, camera,
    # scanner, image viewer, audio player, video player and calculator, so
    # declaring those here bought a second copy of each and nothing else.
    # Chrome is wanted by all four accounts on that host, not just ol, so it
    # is system-level instead: modules/programs/chrome.nix.
    ./picard.nix
    ./whipper.nix
  ];

  home.username = vars.user.name;
  home.homeDirectory = "/home/${vars.user.name}";

  # Pinned at first Home Manager activation, same rule as system.stateVersion
  # in each host's default.nix: leave untouched after this.
  home.stateVersion = "26.05";

  programs.home-manager.enable = true;
}
