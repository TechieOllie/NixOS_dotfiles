{ ... }:
{
  features = {
    # The operator's own machines: their full terminal environment
    # (Ghostty, Git, Lazygit, Neovim, Yazi) belongs here. Off by default,
    # so a host where ol only holds an admin account — inotmac — gets
    # Zsh and Starship and nothing else.
    workstation = true;
    snapshots = false;
    # The Noctalia desktop, on niri. desktop is the stack, niri only picks
    # its compositor — modules/options.nix asserts the two together.
    desktop = true;
    niri = true;
  };
}
