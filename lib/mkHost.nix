# Extracted once a second real nixosConfigurations entry needed the exact
# same disko/sops-nix/options/home-manager wiring as the first — see
# flake.nix for the call sites.
{ nixpkgs, disko, sops-nix, home-manager, noctalia-greeter }:
{ system, hostPath }:
let
  vars = import (hostPath + "/variables.nix");
in
nixpkgs.lib.nixosSystem {
  inherit system;
  # noctalia-greeter is passed through, not imported here: unlike
  # disko/sops-nix it's desktop-specific and opt-in, so its nixosModule is
  # imported by modules/desktop/greetd.nix itself (the same file that
  # actually uses it), keeping mkHost feature-agnostic.
  specialArgs = { inherit vars noctalia-greeter; };
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
