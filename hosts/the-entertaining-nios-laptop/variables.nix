{
  system = {
    hostName = "the-entertaining-nios-laptop";
    timeZone = "Europe/Paris";
    keyMap = "fr-pc";
  };

  user = {
    name = "ol";
    fullName = "ol";
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
}
