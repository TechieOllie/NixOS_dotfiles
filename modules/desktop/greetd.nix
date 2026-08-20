# Gated on config.features.niri rather than its own flag: greetd only
# exists to launch a graphical session, and niri is currently the only one
# this repo offers. Split this onto its own feature (or key it off "is any
# GUI compositor enabled") if a second compositor/DE is ever added.
{
  config,
  lib,
  noctalia-greeter,
  ...
}:
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
      # registers.
      greeter-args = "--session niri";
      # Cursor schema confirmed by reading the noctalia-greeter flake input's
      # own nix/nixos-module.nix (its documented example uses this shape).
      # modules/desktop/theming.nix installs the bibata-cursors package
      # system-wide so this greeter, which runs outside any user's Home
      # Manager profile, can find it by name.
      #
      # greeter.toml used to be *seeded* once via a systemd-tmpfiles C-type
      # rule, so a change here needed a manual rm + `systemd-tmpfiles
      # --create` + greetd restart to take effect. At the pinned revision the
      # upstream module uses an `L+` force-symlink to a store path, rebuilt
      # on every activation, so a plain `nixos-rebuild switch` is enough.
      # Re-check that rule if this input is ever bumped.
      #
      # Multi-monitor hosts also need `output.name` set — the greeter mirrors
      # onto every output by default, and amdgpu's Writeback-1 connector
      # counts as one, which crashes it before it draws. That's a per-machine
      # connector name, so it lives in the host, not here; see
      # hosts/the-entertaining-nios-desktop/default.nix.
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
