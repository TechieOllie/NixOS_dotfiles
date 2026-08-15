# The first actual *role* profile, and purely additive: it says what a
# gaming machine has *on top of* the baseline, and deliberately does not
# import base.nix. Every host imports base.nix itself, so a role profile
# reaching for it too would mean the same foundation arrives by two
# different routes depending on which profile a host happens to use — and
# a host's own default.nix would stop showing that it has a bootloader.
# (This is not the "don't duplicate base" rule in ARCHITECTURE.md: not
# mentioning base is not restating it.)
#
# The import list and the mkDefault below are one atomic edit: an import
# without its matching default is inert code in the closure with the
# feature switched off.
{ lib, ... }:
{
  imports = [
    ../modules/programs/steam.nix
    ../modules/hardware/controllers.nix
  ];

  # mkDefault, not a plain value: a host's own features.nix sets normal
  # priority and so always wins, which is how a machine importing this
  # profile could still turn the stack off.
  features.gaming = lib.mkDefault true;
}
