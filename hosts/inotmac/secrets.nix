# See docs/secrets.md for the full onboarding runbook and this commit's own
# top-level note for the exact copy-pasteable commands still needed before
# this host can actually decrypt anything. hosts/inotmac/secrets/secrets.yaml
# does NOT exist yet — it has to be created by the operator (age keypair,
# .sops.yaml recipient, `sops` edit for four password hashes), not invented
# here with placeholder hashes.
{ vars, ... }:
{
  sops = {
    defaultSopsFile = ./secrets/secrets.yaml;
    age.keyFile = "/var/lib/sops-nix/key.txt";

    secrets = {
      password-hash = {
        neededForUsers = true;
      };

      # The Wi-Fi PSK, as a NetworkManager environment file — its decrypted
      # content is the single line `WIFI_PSK=<the password>`, not a bare
      # password, because ensureProfiles substitutes it by variable name.
      # Deliberately NOT neededForUsers: that flag is what makes sops-nix
      # read a secrets file at *eval* time (see CLAUDE.md), and this one is
      # only wanted at activation, when NetworkManager writes the profile.
      wifi-env = { };
    }
    # One optional secret per extra account, same shape as the primary
    # user's — modules/system/users.nix already handles either being
    # absent (key-only login) via `config.sops.secrets ? "..."`, so
    # nothing here is required for eval to succeed; it's just what makes
    # each extraUsers entry's hashedPasswordFile line up once the real
    # secrets.yaml exists.
    // builtins.listToAttrs (
      map (u: {
        name = "password-hash-${u.name}";
        value = {
          neededForUsers = true;
        };
      }) vars.extraUsers
    );
  };
}
