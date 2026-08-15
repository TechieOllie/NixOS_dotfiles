# Extracted once a second real nixosConfigurations entry needed the exact
# same disko/sops-nix/options/home-manager wiring as the first — see
# flake.nix for the call sites.
{
  nixpkgs,
  disko,
  sops-nix,
  home-manager,
  noctalia-greeter,
  noctalia,
  zen-browser,
  chaotic,
  millennium,
}:
{ system, hostPath }:
let
  vars = import (hostPath + "/variables.nix");
in
nixpkgs.lib.nixosSystem {
  inherit system;
  # noctalia-greeter/noctalia are passed through, not imported here: unlike
  # disko/sops-nix they're desktop-specific and opt-in, so their nixosModules
  # are imported by modules/desktop/{greetd,noctalia}.nix themselves (the
  # files that actually use them), keeping mkHost feature-agnostic.
  # chaotic/millennium get the identical treatment for the gaming stack:
  # modules/programs/steam.nix imports them, so a host that isn't a gaming
  # host never pulls either into its closure.
  specialArgs = {
    inherit
      vars
      noctalia-greeter
      noctalia
      chaotic
      millennium
      ;
  };
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
      # zen-browser has no NixOS module (home-manager only) — passed through
      # here only, matching noctalia's own treatment. home/zen-browser.nix
      # imports zen-browser.homeModules.beta itself.
      home-manager.extraSpecialArgs = { inherit vars noctalia zen-browser; };
      home-manager.users.${vars.user.name} = import ../home;
    }
  ];
}
