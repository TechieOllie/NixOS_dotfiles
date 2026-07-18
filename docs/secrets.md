# Secrets (sops-nix)

Day-to-day sops-nix operations for this repo. For why a standalone per-host
age key is used instead of deriving one from the host's SSH key, see
`ARCHITECTURE.md`'s "Secrets Management" section.

## Onboarding a new host's secrets

1. Generate a standalone age keypair for the host, kept locally by the
   operator and never committed:

   ```bash
   age-keygen -o ~/.config/sops/age/<host>.txt
   ```

2. Add its public key to `.sops.yaml`, as both a `keys:` anchor and a
   `creation_rules:` entry scoped to that host's secrets only:

   ```yaml
   keys:
     - &<host> age1...

   creation_rules:
     - path_regex: hosts/<host>/secrets/.*\.yaml$
       key_groups:
         - age:
             - *<host>
   ```

3. Write and encrypt `hosts/<host>/secrets/secrets.yaml`:

   ```bash
   sops hosts/<host>/secrets/secrets.yaml
   ```

   With no existing file, this creates one, opens it in `$EDITOR` as
   plaintext YAML, and encrypts it on save against whatever recipients
   `.sops.yaml` resolves for that path.

   For a password hash specifically, generate the hash first so the
   plaintext password itself never needs to be typed into the encrypted
   file or shown to anyone else reviewing it:

   ```bash
   mkpasswd -m sha-512
   ```

   Paste only the resulting hash into the `sops` editor session as the
   secret's value.

4. Add a matching entry in `hosts/<host>/secrets.nix`:

   ```nix
   sops = {
     defaultSopsFile = ./secrets/secrets.yaml;
     age.keyFile = "/var/lib/sops-nix/key.txt";

     secrets.<name> = {
       # Only needed if this secret must be decrypted before user creation
       # at activation time (e.g. a password hash referenced by
       # users.users.<name>.hashedPasswordFile) — see below.
       neededForUsers = true;
     };
   };
   ```

5. Provision the *private* key onto the target during install — this only
   happens once, during bootstrapping. See `bootstrapping-a-host.md` step 6.

## Adding a secret to an already-installed host

```bash
sops hosts/<host>/secrets/secrets.yaml
```

Opens the file decrypted in `$EDITOR`; add the new key, save, and it's
re-encrypted automatically. Add the matching `secrets.<name>` entry in that
host's `secrets.nix`, then `nixos-rebuild switch`.

## Adding a recipient or rotating a key

After changing `.sops.yaml` (new recipient, or a host's key rotated), the
already-encrypted file needs to be re-encrypted against the updated
recipient list — editing `.sops.yaml` alone does not retroactively
re-encrypt anything:

```bash
sops updatekeys hosts/<host>/secrets/secrets.yaml
```

## `neededForUsers`

Normal sops-nix secrets are decrypted during system activation, after users
have already been created. A secret referenced by
`users.users.<name>.hashedPasswordFile` needs to exist *before* that point,
so it has to be decrypted earlier — that's what `neededForUsers = true`
does. Only set it on secrets actually consumed by user creation; everything
else should stay on the normal (later) decryption path.
