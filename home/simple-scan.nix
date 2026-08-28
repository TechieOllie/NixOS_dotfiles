# Document Scanner (simple-scan) — GNOME's own scanning app, no real
# alternative considered. Needs modules/services/printing.nix's
# hardware.sane.enable (features.printing-gated, NixOS-level) for the SANE
# backends; this module is just the GUI package. See that module's own
# comment for the "needs users.users.<name>.extraGroups to include
# scanner/lp" caveat — hardware.sane.enable does not grant group membership
# on its own, so hosts/inotmac/default.nix adds it for every account on
# this host.
{
  pkgs,
  lib,
  osConfig,
  ...
}:
lib.mkIf osConfig.features.gnome {
  home.packages = [ pkgs.simple-scan ];
}
