# Tailscale mesh VPN.
#
# Enabling the daemon is all Nix can do here: joining a tailnet needs an
# interactive `sudo tailscale up` (or an auth key) once per machine, and
# the resulting node state lives in /var/lib/tailscale, outside this
# repo. A rebuilt host is therefore *ready* to join, not joined — see
# docs/bootstrapping-a-host.md.
{ config, lib, ... }:
lib.mkIf config.features.tailscale {
  services.tailscale = {
    enable = true;

    # "client" is the right default for a workstation: it declines to
    # advertise routes or act as an exit node, which would need
    # IP forwarding and sysctl changes this repo has no reason to make.
    useRoutingFeatures = "client";

    # Opens the UDP port Tailscale actually listens on, taken from the
    # service's own config rather than hardcoded, so a port change upstream
    # can't leave a stale hole (or a closed one) behind.
    openFirewall = true;
  };

  # Traffic arriving over the tailnet is already authenticated and
  # encrypted by Tailscale itself, so the host firewall doesn't need to
  # filter it a second time. Without this, every service reachable over
  # the tailnet would need its own per-port firewall exception.
  networking.firewall.trustedInterfaces = [ "tailscale0" ];
}
