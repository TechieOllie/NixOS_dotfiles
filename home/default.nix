# Machine-agnostic entry point: every host's Home Manager user points here
# (see lib/mkHost.nix). Every home/*.nix module is imported from here; the
# modules themselves self-gate where they need to (osConfig.features.desktop,
# or .niri/.umbriel for the compositor-specific ones).
{ vars, ... }:
{
  imports = [
    ./niri.nix
    ./umbriel.nix
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
    ./eza.nix
    ./bat.nix
    ./btop.nix
    ./fzf.nix
    ./ripgrep.nix
    ./fastfetch.nix
    ./nix-index.nix
    ./vscode.nix
    ./zen-browser.nix
    ./vesktop.nix
    ./nautilus.nix
    ./screenshot.nix
    ./wl-mirror.nix
    ./loupe.nix
    ./papers.nix
    ./celluloid.nix
    ./decibels.nix
    ./simple-scan.nix
    ./xdg-user-dirs.nix
    ./xdg-mime-apps.nix
    ./feishin.nix
    ./obsidian.nix
    ./heroic.nix
    ./prismlauncher.nix
    ./moonlight.nix
    ./kdeconnect.nix
    ./freecad.nix
    ./kicad.nix
    ./slicers.nix
    ./jetbrains.nix
    ./claude-code.nix
    ./gh.nix
    ./direnv.nix
    ./nh.nix
    ./jq.nix
    ./tealdeer.nix
    ./dust.nix
    ./gpu-screen-recorder.nix
    ./obs-studio.nix

    # No GNOME-host app modules live here. GNOME ships its own viewer set,
    # and the apps it lacks (Chrome, Picard, Rhythmbox) are wanted by
    # every account on that shared host rather than just ol — so they are
    # system-level, in modules/programs/.
  ];

  home.username = vars.user.name;
  home.homeDirectory = "/home/${vars.user.name}";

  # Pinned at first Home Manager activation, same rule as system.stateVersion
  # in each host's default.nix: leave untouched after this.
  home.stateVersion = "26.05";

  programs.home-manager.enable = true;
}
