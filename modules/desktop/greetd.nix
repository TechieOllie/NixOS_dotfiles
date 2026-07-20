# Gated on config.features.niri rather than its own flag: greetd only
# exists to launch a graphical session, and niri is currently the only one
# this repo offers. Split this onto its own feature (or key it off "is any
# GUI compositor enabled") if a second compositor/DE is ever added.
{ config, lib, noctalia-greeter, ... }:
{
  # Only pulled in for hosts that import this file, unlike disko/sops-nix
  # which every host needs — keeps mkHost itself feature-agnostic.
  imports = [ noctalia-greeter.nixosModules.default ];

  config = lib.mkIf config.features.niri {
    # noctalia-greeter's NixOS module enables and configures services.greetd
    # itself once this is turned on — no separate services.greetd.* wiring
    # needed here.
    programs.noctalia-greeter = {
      enable = true;
      # Session name matches the Wayland session entry programs.niri.enable
      # registers; verify with `noctalia-greeter sessions` after first boot.
      greeter-args = "--session niri";
      # Resolves the standing cursor-theme TODO (Theming phase) — schema
      # confirmed by reading the noctalia-greeter flake input's own
      # nix/nixos-module.nix (its documented example uses this exact shape).
      # modules/desktop/theming.nix installs the bibata-cursors package
      # system-wide so this greeter, which runs outside any user's Home
      # Manager profile, can find it by name. Note: greeter.toml is only
      # ever *seeded* once (systemd-tmpfiles C-type rule) and never
      # overwritten afterward — on an already-booted host, this change needs
      # `sudo rm /var/lib/noctalia-greeter/greeter.toml && sudo
      # systemd-tmpfiles --create && sudo systemctl restart greetd` to
      # actually take effect.
      settings = {
        cursor = {
          theme = "Bibata-Modern-Classic";
          size = 22;
        };
        keyboard = {
            layout = "fr";
        };
      };
    };
  };
}
