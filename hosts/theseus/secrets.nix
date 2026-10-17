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

    # This machine's own GitHub identity (`ol@theseus`), the same mechanism
    # as the desktop's — see that host's secrets.nix for the reasoning in
    # full. Unlocked into the gcr SSH agent at login by the password typed
    # at the greeter, which is the other reason modules/desktop/greetd.nix
    # keeps the fingerprint off that one prompt.
    #
    # Per-host so it can be revoked from GitHub without touching any other
    # machine. No passphrase: what guards it is the age key at
    # /var/lib/sops-nix/key.txt, root-only, on a LUKS-encrypted disk.
    secrets."ssh-private-key" = {
      path = "/home/${vars.user.name}/.ssh/id_ed25519";
      owner = vars.user.name;
      mode = "0400";
    };
  };

  # sops-install-secrets creates ~/.ssh itself if missing, but as
  # root:root 0755 — so it is declared first, owned by the user, as on the
  # desktop.
  systemd.tmpfiles.rules = [
    "d /home/${vars.user.name}/.ssh 0700 ${vars.user.name} users - -"
  ];
}
