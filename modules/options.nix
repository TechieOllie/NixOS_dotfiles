{ lib, ... }:
{
  options.features = lib.mkOption {
    type = lib.types.submodule {
      options = {
        snapshots = lib.mkOption {
          type = lib.types.bool;
          default = false;
          description = "Enable automatic btrfs snapshots (snapper) of / and /home.";
        };
        niri = lib.mkOption {
          type = lib.types.bool;
          default = false;
          description = "Enable the Niri Wayland compositor (system package + session entry only; user config lives in home/niri.nix).";
        };
        gaming = lib.mkOption {
          type = lib.types.bool;
          default = false;
          description = "Enable the gaming stack: Steam (Millennium-patched) with proton-cachyos, Xbox controller drivers, and Heroic on the Home Manager side.";
        };
        docker = lib.mkOption {
          type = lib.types.bool;
          default = false;
          description = "Enable the Docker daemon and Compose, with the primary user in the docker group.";
        };
        tailscale = lib.mkOption {
          type = lib.types.bool;
          default = false;
          description = "Enable the Tailscale daemon and trust the tailscale0 interface in the firewall.";
        };
        printing = lib.mkOption {
          type = lib.types.bool;
          default = false;
          description = "Enable CUPS printing and Avahi-based network printer/scanner discovery.";
        };
      };
    };
    default = { };
    description = "Feature flags controlling optional functionality. Every toggle a host or profile can set must be declared here.";
  };
}
