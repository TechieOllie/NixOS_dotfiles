{ vars, config, lib, ... }:
{
  users.users.${vars.user.name} =
    {
      isNormalUser = true;
      description = vars.user.fullName;
      extraGroups = [ "wheel" ];
    }
    # Only set a local-console password if a host has wired up a
    # `password-hash` sops secret (see hosts/*/secrets.nix); a host that
    # hasn't gets no password at all, i.e. key-only login.
    // lib.optionalAttrs (config.sops.secrets ? password-hash) {
      hashedPasswordFile = config.sops.secrets.password-hash.path;
    };
}
