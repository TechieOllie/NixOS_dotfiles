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
  moonshine,
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
  # host never pulls either into its closure. moonshine likewise, imported
  # by modules/services/moonshine.nix.
  specialArgs = {
    inherit
      vars
      noctalia-greeter
      noctalia
      chaotic
      millennium
      moonshine
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

      # Install home.packages into /etc/profiles/per-user/<name> — part of
      # the system generation, swapped atomically with it — rather than
      # into the user's own ~/.nix-profile via an activation side-effect.
      # This is what the repo's "one nixos-rebuild switch, one rollback"
      # premise actually asks for: the packages were always in the system
      # closure either way, but with this off their *visible location* was
      # a mutable per-user profile that home-manager-<name>.service had to
      # go and rewrite on every switch — one more activation step able to
      # half-fail, on a repo that already has an HM activation race in its
      # standing gotchas.
      #
      # It also gives system-level units a stable path to a Home Manager
      # package, which ~/.nix-profile never did: see the Heroic entry in
      # modules/services/moonshine.nix.
      #
      # Upstream's own flake templates set this, and its manual says it
      # "may become the default value in the future". It was off here only
      # because it defaults off and nothing ever set it.
      home-manager.useUserPackages = true;
      # zen-browser has no NixOS module (home-manager only) — passed through
      # here only, matching noctalia's own treatment. home/zen-browser.nix
      # imports zen-browser.homeModules.beta itself.
      home-manager.extraSpecialArgs = { inherit vars noctalia zen-browser; };
      home-manager.users.${vars.user.name} = import ../home;
    }
  ];
}
