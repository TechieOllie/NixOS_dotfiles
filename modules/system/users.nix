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

  # Per-account GNOME session language, for any extraUser that named one.
  #
  # There is no NixOS option for this and no way to fully declare it: GDM
  # and gnome-session read the language from AccountsService, whose store is
  # a plain ini file per user under /var/lib/AccountsService/users that the
  # daemon owns and rewrites whenever anything changes — the same
  # app-owned-mutable-state shape as Noctalia's settings sidecar and Zen's
  # xulstore.json. So this *seeds* rather than declares.
  #
  # `f` deliberately, not `f+`: create-if-absent. The same file also holds
  # keys the daemon learned on its own (Icon, Session, XSession,
  # SystemAccount), so rewriting it on every boot would throw those away and
  # would also stomp the person's own choice the moment they used Settings →
  # Region & Language. The cost of that is the usual seed-once cost: an
  # account that has *already* logged in has a file, so this does nothing
  # for it and the language has to be set once by hand — either in Settings
  # or with `sudo loginctl`/`chsh`-style direct edit of the same file.
  #
  # The \\n are literal backslash-n in the generated rule, not real
  # newlines — systemd-tmpfiles parses one rule per line and un-escapes the
  # argument field itself, so a real newline here would split the rule in
  # two and leave `Language=...` sitting on its own as an unparseable
  # second rule. Which is exactly what the first version of this did;
  # caught by reading the evaluated rule rather than by the build, which
  # was perfectly green.
  #
  # Note the mode and owner: root:root 0600, matching what accountsservice
  # itself writes. The directory is declared too, at the 0700 root:root the
  # daemon creates it with — without it systemd-tmpfiles would create the
  # parent implicitly at 0755.
  systemd.tmpfiles.rules =
    let
      localised = builtins.filter (u: (u.language or null) != null) (vars.extraUsers or [ ]);
    in
    lib.optionals (localised != [ ]) (
      [ "d /var/lib/AccountsService/users 0700 root root -" ]
      ++ map (
        u: "f /var/lib/AccountsService/users/${u.name} 0600 root root - [User]\\nLanguage=${u.language}\\n"
      ) localised
    );

  # A language nobody generated is a language GNOME silently falls back out
  # of — glibc has no fr_FR.UTF-8 unless it is built, and the session then
  # comes up in the default locale with no error anywhere. Derived from the
  # same list rather than stated separately so the two can't drift.
  i18n.extraLocales = lib.unique (
    map (u: "${u.language}/UTF-8") (
      builtins.filter (u: (u.language or null) != null) (vars.extraUsers or [ ])
    )
  );
}
