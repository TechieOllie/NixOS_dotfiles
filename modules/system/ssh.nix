{ vars, ... }:
{
  services.openssh = {
    enable = true;
    settings = {
      PasswordAuthentication = false;
      PermitRootLogin = "no";
    };
  };

  # Every key the operator can log in with, listed per host in its own
  # variables.nix — the same plural shape hosts/installer/variables.nix has
  # always used. Required rather than optional: a host that authorizes no
  # key is one nobody can reach, and with PasswordAuthentication off above
  # there is no fallback. Making it non-optional means a host that forgets
  # it fails at eval instead of after install.
  users.users.${vars.user.name}.openssh.authorizedKeys.keys = vars.user.sshPublicKeys;
}
