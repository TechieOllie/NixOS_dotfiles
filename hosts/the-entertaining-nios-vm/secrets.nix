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

    # SSH agent auto-unlock at login: gnome-keyring/GCR (already enabled by
    # niri's own upstream module, PAM-unlocked at greetd login with no
    # extra config here) picks this up as an ssh-agent identity. A
    # throwaway test key for this host only, not the operator's real key —
    # see CLAUDE.md's Phase 3 note. Whether a host wants this feature at
    # all is expressed entirely by whether this block exists in its
    # secrets.nix; no separate features.* flag, since nothing else needs
    # to react to it conditionally.
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
