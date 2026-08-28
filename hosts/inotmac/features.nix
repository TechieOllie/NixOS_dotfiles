{ ... }:
{
  features = {
    gnome = true;
    printing = true;
    # snapshots left at its default (false): plain ext4 was chosen for this
    # host's disk (see disko.nix) — a spinning 2011-era SATA HDD shared by
    # four accounts, where btrfs's CoW overhead is real rather than the
    # "effectively free on NVMe" case ARCHITECTURE.md describes for the
    # desktop host. No btrfs, so no snapper.
  };
}
