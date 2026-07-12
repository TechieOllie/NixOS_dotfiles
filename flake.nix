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
    { nixpkgs, home-manager, disko, sops-nix, ... }:
    let
      system = "x86_64-linux";
      vars = import ./hosts/the-entertaining-nios-vm/variables.nix;
      mkHost = import ./lib/mkHost.nix { inherit nixpkgs disko sops-nix home-manager; };
    in
    {
      nixosConfigurations.the-entertaining-nios-vm = mkHost {
        inherit system;
        hostPath = ./hosts/the-entertaining-nios-vm;
      };

      nixosConfigurations.the-entertaining-nios-laptop = mkHost {
        inherit system;
        hostPath = ./hosts/the-entertaining-nios-laptop;
      };

      # Bootstrap tool, not a host: a minimal installer ISO with the
      # operator's key pre-authorized for root, so nixos-anywhere can SSH in
      # without any manual console step. Reuses this host's vars for now
      # since there's only one operator/key in play; once bootstrapping
      # needs to be host-independent (multiple operators, multiple hosts),
      # this should read from its own flake-level identity instead of
      # reaching into one host's variables.nix.
      packages.${system}.installer-iso =
        (nixpkgs.lib.nixosSystem {
          inherit system;
          modules = [
            "${nixpkgs}/nixos/modules/installer/cd-dvd/installation-cd-minimal.nix"
            {
              users.users.root.openssh.authorizedKeys.keys = [ vars.user.sshPublicKey ];
            }
          ];
        }).config.system.build.isoImage;
    };
}
