# Not a real host — this folder holds only the operator identity needed by
# the installer-iso package (flake.nix), so that package doesn't have to
# reach into one specific real host's variables.nix. Deliberately no
# features.nix/disko.nix/hardware-configuration.nix/secrets.nix here, and no
# nixosConfigurations entry — unlike every other directory under hosts/.
#
# One operator today ("ol", administrator of every host). If this ever needs
# to cover multiple administrators with different keys, extend `user` here
# (e.g. a list) rather than inventing a second mechanism.
{
  user = {
    name = "ol";
    fullName = "ol";
    sshPublicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIATBdWsHaaYkSYrvxuIyjAlRO5Un1cDcOcI9RUXu9LTH oliverwest06@outlook.com";
  };
}
