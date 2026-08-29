{ vars, ... }:
{
  services.openssh = {
    enable = true;
    settings = {
      PasswordAuthentication = false;
      PermitRootLogin = "no";
    };
  };

  # The operator's bootstrap key, plus any host-specific additions. The
  # extras exist for the same reason hosts/installer/variables.nix carries a
  # second key: the machine that administers a host over SSH is not always
  # holding the bootstrap key. inotmac is the live case — it is managed from
  # the desktop, which has only its own per-host identity.
  #
  # `or [ ]` so no other host's variables.nix needs to change, the same
  # shape vars.extraUsers uses in modules/system/users.nix.
  users.users.${vars.user.name}.openssh.authorizedKeys.keys = [
    vars.user.sshPublicKey
  ]
  ++ (vars.user.extraSshPublicKeys or [ ]);
}
