{
  vars,
  config,
  lib,
  pkgs,
  ...
}:
{
  users.users.${vars.user.name} = {
    isNormalUser = true;
    description = vars.user.fullName;
    # Pinned rather than left to be allocated. This is the value the first
    # normal user gets on every host here anyway, so stating it changes
    # nothing on disk — but it makes the uid *declared*, which is what
    # services.moonshine reads to locate /run/user/<uid> and order itself
    # after user@<uid>.service. Without it that module's own assertion
    # fires. See modules/services/moonshine.nix.
    uid = 1000;
    extraGroups = [ "wheel" ];
    # Registered in /etc/shells by modules/system/shell.nix
    # (programs.zsh.enable); this just assigns it as the login shell.
    shell = pkgs.zsh;
  }
  # Only set a local-console password if a host has wired up a
  # `password-hash` sops secret (see hosts/*/secrets.nix); a host that
  # hasn't gets no password at all, i.e. key-only login.
  // lib.optionalAttrs (config.sops.secrets ? password-hash) {
    hashedPasswordFile = config.sops.secrets.password-hash.path;
  };
}
