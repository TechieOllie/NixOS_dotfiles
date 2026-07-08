{ vars, ... }:
{
  users.users.${vars.user.name} = {
    isNormalUser = true;
    description = vars.user.fullName;
    extraGroups = [ "wheel" ];
    # Test VM convenience only — replace with sops-nix managed auth
    # (or an SSH-key-only setup) before this module is used on a real host.
    initialPassword = "changeme";
  };
}
