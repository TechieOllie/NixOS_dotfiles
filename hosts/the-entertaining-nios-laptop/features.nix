{ ... }:
{
  features = {
    # The operator's own machines: their full terminal environment
    # (Ghostty, Git, Lazygit, Neovim, Yazi) belongs here. Off by default,
    # so a host where ol only holds an admin account — inotmac — gets
    # Zsh and Starship and nothing else.
    workstation = true;
    snapshots = true;
    docker = true;
    tailscale = true;
    printing = true;
  };
}
