{ ... }:
{
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  # Each generation's boot entry also copies its kernel and initrd onto the
  # ESP, so an unbounded menu eventually fills that small partition and
  # makes a switch fail mid-install. nix.gc already drops generations after
  # two weeks; this caps the menu independently of that, at more rollback
  # points than a bad switch would ever need.
  boot.loader.systemd-boot.configurationLimit = 15;
}
