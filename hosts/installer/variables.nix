# Not a real host — this folder holds only the operator identity needed by
# the installer-iso package (flake.nix), so that package doesn't have to
# reach into one specific real host's variables.nix. Deliberately no
# features.nix/disko.nix/hardware-configuration.nix/secrets.nix here, and no
# nixosConfigurations entry — unlike every other directory under hosts/.
#
# One operator today ("ol", administrator of every host), but more than one
# key: the ISO authorizes every key that might need to reach an installer
# over SSH. Real hosts carry the same plural `sshPublicKeys` list, so this
# file no longer differs from them in shape — only in which keys it lists.
# Add a key here when a new machine has to be able to drive
# `nixos-anywhere`.
{
  user = {
    name = "ol";
    fullName = "ol";
    sshPublicKeys = [
      # The bootstrap key, shared with every real host's variables.nix.
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIATBdWsHaaYkSYrvxuIyjAlRO5Un1cDcOcI9RUXu9LTH oliverwest06@outlook.com"
      # The desktop's own per-host key (~/.ssh/id_ed25519), so the machine
      # running nixos-anywhere can reach the installer as itself.
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAINK969JoQS2K7NuxD5TYEP+2QXevdSdwpc6BAb/lAWRt ol@the-entertaining-nios-desktop"
    ];
  };
}
