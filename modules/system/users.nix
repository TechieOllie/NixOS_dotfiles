{
  vars,
  config,
  lib,
  pkgs,
  ...
}:
{
  users.users = {
    ${vars.user.name} = {
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
  # Secondary, non-admin accounts — plain users with no Home Manager
  # profile and no wheel membership. `vars.extraUsers` is new, purely
  # additive data (a list of { name, fullName, uid }), read with `or []` so
  # every other host's variables.nix needs no change at all. This was
  # added for inotmac (a shared iMac with four real people using it, only
  # one of whom is the operator) rather than folding a whole second
  # Home-Manager-user mechanism into lib/mkHost.nix for accounts that
  # only want stock GNOME — see ARCHITECTURE.md's "introduce an
  # abstraction only once a pattern has repeated" rule. If a second
  # multi-user host ever needs real per-user dotfiles, that's the moment
  # to revisit this, not before.
  #
  # Each optionally gets its own hashedPasswordFile, the same
  # optionalAttrs shape as the primary user above, keyed off a
  # per-username secret name so hosts with no such secret declared still
  # evaluate (key-only login, same fallback as the primary user).
  // lib.listToAttrs (
    map (
      u:
      lib.nameValuePair u.name (
        {
          isNormalUser = true;
          description = u.fullName;
          # Pinned for the same reason the primary user's is, one layer
          # down: an allocated uid depends on account-creation order, so a
          # reinstall could hand one person's number to another and
          # silently mis-own every file restored from a backup. Cheap to
          # state, impossible to reconstruct after the fact.
          inherit (u) uid;
          shell = pkgs.zsh;
        }
        // lib.optionalAttrs (config.sops.secrets ? "password-hash-${u.name}") {
          hashedPasswordFile = config.sops.secrets."password-hash-${u.name}".path;
        }
      )
    ) (vars.extraUsers or [ ])
  );
}
