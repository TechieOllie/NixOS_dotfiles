# Extracted once a second real nixosConfigurations entry needed the exact
# same disko/sops-nix/options/home-manager wiring as the first — see
# flake.nix for the call sites.
{ nixpkgs, disko, sops-nix, home-manager }:
{ system, hostPath }:
let
  vars = import (hostPath + "/variables.nix");
in
nixpkgs.lib.nixosSystem {
  inherit system;
  specialArgs = { inherit vars; };
  modules = [
    disko.nixosModules.disko
    sops-nix.nixosModules.sops
    ../modules/options.nix
    hostPath
    home-manager.nixosModules.home-manager
    {
      # Share the system's pkgs instance instead of evaluating a second one
      # for Home Manager.
      home-manager.useGlobalPkgs = true;
      home-manager.extraSpecialArgs = { inherit vars; };
      home-manager.users.${vars.user.name} = import ../home;
    }
  ];
}
