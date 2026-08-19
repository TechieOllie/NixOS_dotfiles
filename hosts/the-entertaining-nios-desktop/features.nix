{ ... }:
{
  features = {
    snapshots = true;
    niri = true;
    docker = true;
    tailscale = true;
    printing = true;
    # Remote streaming. Only this host: it's the machine with the GPU and
    # the games, and it's the one that's worth reaching when away from it.
    moonshine = true;
    # gaming is left to profiles/gaming.nix's mkDefault rather than
    # restated here — a host's features.nix is for overriding a profile,
    # not for echoing it.
  };
}
