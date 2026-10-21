{ ... }:
{
  features = {
    snapshots = true;
    # Battery and Wi-Fi in Noctalia's bar (home/noctalia.nix).
    laptop = true;
    # The operator's own machines: their full terminal environment
    # (Ghostty, Git, Lazygit, Neovim, Yazi) belongs here. Off by default,
    # so a host where ol only holds an admin account — inotmac — gets
    # Zsh and Starship and nothing else.
    workstation = true;
    # The Noctalia desktop, on Umbriel rather than niri — for now, by the
    # operator's choice; switching back is these two lines plus swapping
    # modules/desktop/umbriel.nix for niri.nix in ./default.nix.
    desktop = true;
    umbriel = true;
    docker = true;
    tailscale = true;
    printing = true;
    kdeconnect = true;
    # The same tooling as the desktop: FreeCAD/KiCad, and IntelliJ IDEA,
    # Claude Code and gh on top of the workstation terminal stack.
    cad = true;
    development = true;
    # darktable (home/darktable.nix).
    photography = true;
    # gaming is left to profiles/gaming.nix's mkDefault rather than
    # restated here — a host's features.nix is for overriding a profile,
    # not for echoing it.
  };
}
