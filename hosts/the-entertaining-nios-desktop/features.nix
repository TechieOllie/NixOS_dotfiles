{ ... }:
{
  features = {
    snapshots = true;
    niri = true;
    docker = true;
    tailscale = true;
    printing = true;
    # gaming is left to profiles/gaming.nix's mkDefault rather than
    # restated here — a host's features.nix is for overriding a profile,
    # not for echoing it.
  };
}
