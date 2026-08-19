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

    noctalia-greeter = {
      url = "github:noctalia-dev/noctalia-greeter";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Deliberately not following this repo's nixpkgs (would disable
    # Noctalia's Cachix binary cache) and deliberately pinned to the
    # `cachix` branch rather than `main` — per upstream's own docs, `main`
    # may point at a commit CI hasn't finished caching yet, while `cachix`
    # always points at the latest commit that's already been built and
    # pushed to the cache. Tracking `main` cost a ~20min from-source build
    # of this native Wayland/OpenGL project before this was caught.
    noctalia.url = "github:noctalia-dev/noctalia/cachix";

    # Zen Browser isn't in nixpkgs at all (confirmed via nix eval against
    # this repo's pinned nixpkgs revision) — this community flake provides
    # the package + a home-manager module (programs.zen-browser). Follows
    # this repo's nixpkgs/home-manager, unlike noctalia above: no separate
    # binary cache to lose by doing so.
    zen-browser = {
      url = "github:0xc000022070/zen-browser-flake";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.home-manager.follows = "home-manager";
    };

    # CachyOS's Proton fork and gaming kernel (Phase 7). Neither exists in
    # nixpkgs — confirmed against this repo's pinned revision, where the
    # only "cachy" attribute is `ananicy-rules-cachyos`. Deliberately does
    # **not** follow this repo's nixpkgs, on upstream's own instruction:
    # following it produces hash mismatches against their prebuilt cache,
    # which for `linuxPackages_cachyos` means compiling a kernel from
    # source. Same tradeoff already accepted for `noctalia` above. The
    # substituter is wired in by `chaotic.nixosModules.default` itself, so
    # unlike noctalia there's no nix.settings block of our own to keep in
    # sync.
    chaotic.url = "github:chaotic-cx/nyx/nyxpkgs-unstable";

    # Millennium (Steam client mod framework) is likewise absent from
    # nixpkgs — there's an open packaging request, and upstream ships this
    # flake instead. It pins its own nixpkgs on purpose (its Bun
    # fixed-output derivation is version-sensitive and breaks when the
    # revision moves), so following ours is not an option either. The cost
    # is a third nixpkgs in the closure and a Steam that trails ours by a
    # patch release.
    millennium = {
      url = "github:SteamClientHomebrew/Millennium?dir=packages/nix";
    };
  };

  outputs =
    {
      self,
      nixpkgs,
      home-manager,
      disko,
      sops-nix,
      noctalia-greeter,
      noctalia,
      zen-browser,
      chaotic,
      millennium,
      ...
    }:
    let
      system = "x86_64-linux";
      inherit (nixpkgs) lib;
      pkgs = nixpkgs.legacyPackages.${system};
      installerVars = import ./hosts/installer/variables.nix;
      mkHost = import ./lib/mkHost.nix {
        inherit
          nixpkgs
          disko
          sops-nix
          home-manager
          noctalia-greeter
          noctalia
          zen-browser
          chaotic
          millennium
          ;
      };

      # A repo-wide lint/format check as a derivation, so `nix flake check`
      # is the one command that gates a commit both locally and in CI
      # (ARCHITECTURE.md, "Validation and CI") rather than a second script
      # CI would have to reimplement.
      mkLint =
        name: deps: script:
        pkgs.runCommandLocal "check-${name}" { nativeBuildInputs = deps; } ''
          cd ${self}
          ${script}
          touch $out
        '';

      # Every hand-written .nix file. hardware-configuration.nix is excluded
      # throughout: nixos-generate-config writes it, so making it satisfy a
      # formatter or a linter would be undone the next time a host is
      # regenerated. (statix reads the same exclusion from statix.toml.)
      handWrittenNix = "$(find . -name '*.nix' -not -name 'hardware-configuration.nix')";
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

      # Wired in before the machine has ever been installed, deliberately:
      # the `checks` attribute below is derived from this set, so an entry
      # here is what makes CI build this host's closure — and this is the
      # only host that imports profiles/gaming.nix, so until now the entire
      # Phase 7 gaming stack was never built by anything.
      nixosConfigurations.the-entertaining-nios-desktop = mkHost {
        inherit system;
        hostPath = ./hosts/the-entertaining-nios-desktop;
      };

      # Bootstrap tool, not a host: a minimal installer ISO with the
      # operator's key pre-authorized for root, so nixos-anywhere can SSH in
      # without any manual console step. Reads hosts/installer/variables.nix
      # (operator identity only, not a real host — see that file's own
      # comment) rather than any one real host's variables.nix.
      packages.${system}.installer-iso =
        (nixpkgs.lib.nixosSystem {
          inherit system;
          modules = [
            "${nixpkgs}/nixos/modules/installer/cd-dvd/installation-cd-minimal.nix"
            {
              users.users.root.openssh.authorizedKeys.keys = [ installerVars.user.sshPublicKey ];
            }
          ];
        }).config.system.build.isoImage;

      # `nix fmt`. This is the RFC 166 style formerly packaged as
      # nixfmt-rfc-style, which nixpkgs has since made plain `nixfmt` (the
      # old attribute is now an alias that warns). Chosen over
      # ARCHITECTURE.md's original alejandra suggestion because the repo was
      # already hand-written in this style — adopting alejandra would have
      # reformatted every .nix file to gain nothing. See docs/decisions.md.
      formatter.${system} = pkgs.nixfmt;

      # `nix develop` — the tools this repo is maintained with, so a fresh
      # clone needs nothing installed globally. direnv (already part of the
      # terminal stack) picks this up automatically.
      devShells.${system}.default = pkgs.mkShell {
        packages = with pkgs; [
          just
          nixfmt
          statix
          deadnix
          nixd
          nil
          sops
          age
        ];
      };

      checks.${system} = {
        format = mkLint "format" [ pkgs.nixfmt ] "nixfmt --check ${handWrittenNix}";
        statix = mkLint "statix" [ pkgs.statix ] "statix check .";
        deadnix = mkLint "deadnix" [ pkgs.deadnix ] "deadnix --fail ${handWrittenNix}";
      }
      # `nix flake check` already *evaluates* every nixosConfigurations
      # entry; these go one step further and build each host's real system
      # closure, which is what catches a module that evaluates fine but
      # fails to build. Derived from self.nixosConfigurations rather than
      # listed by hand, so a new host can't be added without also being
      # checked.
      // lib.mapAttrs' (
        name: host: lib.nameValuePair "build-${name}" host.config.system.build.toplevel
      ) self.nixosConfigurations;
    };
}
