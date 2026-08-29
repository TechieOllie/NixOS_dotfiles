{
  system = {
    hostName = "inotmac";
    # Matches the operator's other real hosts; change if this machine
    # should actually live in a different zone/layout — not verified
    # against the physical machine's location, just inherited as a
    # reasonable default.
    timeZone = "Europe/Paris";
    keyMap = "fr-pc";
  };

  user = {
    name = "ol";
    fullName = "ol";
    # The operator's own bootstrap/login key — the same one every other
    # real host's variables.nix carries (see hosts/the-entertaining-nios-{vm,
    # laptop}/variables.nix and hosts/installer/variables.nix). This is what
    # lets the operator SSH into `ol`'s own account; it is distinct from a
    # per-host GitHub deploy key, which (if this host wants one) belongs in
    # secrets.nix instead, same shape as the desktop's ssh-private-key.
    sshPublicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIATBdWsHaaYkSYrvxuIyjAlRO5Un1cDcOcI9RUXu9LTH oliverwest06@outlook.com";

    # This host is administered remotely from the desktop, which holds only
    # its own per-host identity (~/.ssh/id_ed25519, provisioned by that
    # host's secrets.nix) and not the bootstrap key's private half. Without
    # this the desktop cannot SSH in at all — the exact gap that appeared on
    # inotmac's first boot, and the same reason hosts/installer/variables.nix
    # already lists this key.
    extraSshPublicKeys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAINK969JoQS2K7NuxD5TYEP+2QXevdSdwpc6BAb/lAWRt ol@the-entertaining-nios-desktop"
    ];
  };

  # Three additional, non-admin accounts sharing this machine — see
  # modules/system/users.nix, which reads this with `or []` so every other
  # host's variables.nix needs no change. Each uid is pinned rather than
  # left to be allocated, for the same reason ol's is: an allocated uid
  # depends on account-creation order, so a reinstall could hand liz's
  # number to regis and silently mis-own every restored file. None of
  # these get Home Manager
  # (see that module's comment) or wheel; each optionally gets its own
  # sops-backed password hash (hosts/inotmac/secrets.nix).
  extraUsers = [
    {
      name = "liz";
      fullName = "Liz";
      uid = 1001;
    }
    {
      name = "regis";
      fullName = "Regis";
      uid = 1002;
    }
    {
      name = "jolan";
      fullName = "Jolan";
      uid = 1003;
    }
  ];
}
