{ ... }:
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
  };
}
