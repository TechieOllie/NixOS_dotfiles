{ vars, ... }:
{
  sops = {
    defaultSopsFile = ./secrets/secrets.yaml;
    age.keyFile = "/var/lib/sops-nix/key.txt";

    secrets.password-hash = {
      # Needed early: user creation (activation) requires the hash to
      # already be decrypted, before the rest of sops-nix's normal
      # (later) secret-decryption phase would otherwise run it.
      neededForUsers = true;
    };

    # SSH agent auto-unlock at login, same mechanism as the VM's: the
    # gnome-keyring/GCR agent that programs.niri already pulls in is
    # PAM-unlocked at greetd login and picks this up as an identity, so no
    # module or features.* flag is involved — declaring the secret here is
    # the whole signal (see docs/decisions.md's Phase 3 note).
    #
    # Unlike the VM's, this is a *real* key, generated for this machine
    # (`ol@the-entertaining-nios-desktop`) and intended to be added to
    # GitHub. It's per-host on purpose: one key per machine can be revoked
    # from GitHub without disturbing any other host, and the operator's
    # bootstrap key in variables.nix stays a separate identity used only to
    # reach installers.
    #
    # It has no passphrase. What actually guards it is this host's age key
    # at /var/lib/sops-nix/key.txt, which is root-only and staged in by
    # `nixos-anywhere --extra-files` — anyone who can read that can decrypt
    # the key regardless of a passphrase, and a passphrase can't be stored
    # declaratively anyway. If that trade is ever unwanted, regenerate with
    # `ssh-keygen -p` and re-encrypt; nothing here needs to change.
    secrets."ssh-private-key" = {
      path = "/home/${vars.user.name}/.ssh/id_ed25519";
      owner = vars.user.name;
      mode = "0400";
    };
  };

  # sops-install-secrets creates ~/.ssh itself if missing, but as
  # root:root 0755 — fine for the key file it places (which gets its own
  # correct owner/mode above), but leaves the directory not owned by the
  # user, unable to add anything else there (known_hosts, config) without
  # sudo. Declaring it here first means it already exists with the right
  # ownership by the time sops-install-secrets runs.
  systemd.tmpfiles.rules = [
    "d /home/${vars.user.name}/.ssh 0700 ${vars.user.name} users - -"
  ];
}
