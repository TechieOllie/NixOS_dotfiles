{ vars, ... }:
{
  services.openssh = {
    enable = true;
    settings = {
      PasswordAuthentication = false;
      PermitRootLogin = "no";
    };
  };

  users.users.${vars.user.name}.openssh.authorizedKeys.keys = [
    vars.user.sshPublicKey
  ];
}
