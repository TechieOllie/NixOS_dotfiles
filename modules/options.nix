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
        bluetooth = lib.mkOption {
          type = lib.types.bool;
          default = false;
          description = "Enable the Bluetooth stack.";
        };
        sshAgentUnlock = lib.mkOption {
          type = lib.types.bool;
          default = false;
          description = "Unlock the SSH agent (via gpg-agent) at greetd login.";
        };
      };
    };
    default = { };
    description = "Feature flags controlling optional functionality. Every toggle a host or profile can set must be declared here.";
  };
}
