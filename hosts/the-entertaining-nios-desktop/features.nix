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
    # Phone integration. Desktop-only for now on availability, not on
    # principle: the laptop would want it too once it's installed.
    kdeconnect = true;
    # FreeCAD, and the workstation tooling (IntelliJ IDEA, Claude Code)
    # that sits on top of the terminal stack every host already gets.
    cad = true;
    development = true;
    # gaming is left to profiles/gaming.nix's mkDefault rather than
    # restated here — a host's features.nix is for overriding a profile,
    # not for echoing it.
  };
}
