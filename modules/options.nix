{ lib, ... }:
{
  options.features = lib.mkOption {
    type = lib.types.submodule {
      options = {
        docker = lib.mkOption {
          type = lib.types.bool;
          default = false;
          description = "Enable Docker Engine + Compose.";
        };
        steam = lib.mkOption {
          type = lib.types.bool;
          default = false;
          description = "Enable Steam + gaming stack.";
        };
        gamemode = lib.mkOption {
          type = lib.types.bool;
          default = false;
          description = "Enable Feral GameMode.";
        };
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
      };
    };
    default = { };
    description = "Feature flags controlling optional functionality. Every toggle a host or profile can set must be declared here.";
  };
}
