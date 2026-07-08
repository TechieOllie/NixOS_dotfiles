{
  description = "NixOS configuration";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    disko = {
      url = "github:nix-community/disko";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    { nixpkgs, disko, sops-nix, ... }:
    let
      system = "x86_64-linux";
      vars = import ./hosts/the-entertaining-nios-vm/variables.nix;
    in
    {
      # Phase 1: a single host, wired directly. A mkHost helper belongs in
      # lib/ once a second real host makes the pattern worth extracting —
      # not before.
      nixosConfigurations.the-entertaining-nios-vm = nixpkgs.lib.nixosSystem {
        inherit system;
        specialArgs = { inherit vars; };
        modules = [
          disko.nixosModules.disko
          sops-nix.nixosModules.sops
          ./modules/options.nix
          ./hosts/the-entertaining-nios-vm
        ];
      };
    };
}
