{
  system = {
    hostName = "inotmac";
    # Matches the operator's other real hosts; change if this machine
    # should actually live in a different zone/layout — not verified
    # against the physical machine's location, just inherited as a
    # reasonable default.
    timeZone = "Europe/Paris";
    keyMap = "fr-pc";
    # The same physical keyboard, named again in xkb's namespace rather than
    # the console's — "fr-pc" is a console keymap file and means nothing to
    # X11/Wayland, which needs the two-letter xkb layout. Both have to be
    # stated; neither can be derived from the other.
    #
    # Not cosmetic: without it the graphical stack silently defaults to "us"
    # while the console is French, so a password typed correctly at GDM
    # produces different characters than the same password typed over SSH.
    # That is exactly how this host locked its own operator out — sudo
    # worked, GDM did not, and the journal showed a plain PAM auth failure
    # with no hint that the keyboard was the reason.
    xkbLayout = "fr";
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
    sshPublicKeys = [
      # The operator's bootstrap/login key, carried by every host here and
      # by hosts/installer/variables.nix.
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIATBdWsHaaYkSYrvxuIyjAlRO5Un1cDcOcI9RUXu9LTH oliverwest06@outlook.com"
      # The desktop's own per-host identity (its ~/.ssh/id_ed25519, from
      # that host's secrets.nix). Present on every host, not just the one
      # being administered at the time: the desktop is where this repo is
      # edited and where remote rebuilds are driven from, and discovering
      # it could not reach a machine only after that machine was installed
      # is exactly how inotmac's first boot went.
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
  #
  # `language` is optional and also read with `or null`. It sets that one
  # account's GNOME session language, which is a per-person property and
  # not a machine one: this iMac sits in France, but ol administers it in
  # English while regis and jolan want a French desktop, and liz has not
  # said. So i18n.defaultLocale stays en_US.UTF-8 for the system and only
  # the accounts that asked get something else. See modules/system/users.nix
  # for how it is applied, and why it can only be *seeded* rather than
  # fully declared.
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
      language = "fr_FR.UTF-8";
    }
    {
      name = "jolan";
      fullName = "Jolan";
      uid = 1003;
      language = "fr_FR.UTF-8";
    }
  ];
}
