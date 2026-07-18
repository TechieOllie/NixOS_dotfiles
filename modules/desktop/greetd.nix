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
      # TODO: settings.cursor = { theme = "Bibata-Modern-Classic"; ... } once
      # cursor theming is tackled repo-wide (greeter + niri + GTK + Qt) —
      # see CLAUDE.md's Phase 3 note.
      settings = {
        keyboard = {
            layout = "fr";
        };
      };
    };
  };
}
