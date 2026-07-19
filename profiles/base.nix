{ ... }:
{
  # Universal foundation, not a role: every host needs these regardless of
  # whether it ends up a workstation, server, or anything else. Role-specific
  # profiles (desktop.nix, server.nix, ...) import this rather than
  # duplicating it.
  imports = [
    ../modules/system/boot.nix
    ../modules/system/nix.nix
    ../modules/system/networking.nix
    ../modules/system/users.nix
    ../modules/system/ssh.nix
    ../modules/system/shell.nix
    ../modules/system/fonts.nix
    ../modules/system/nix-ld.nix
  ];
}
