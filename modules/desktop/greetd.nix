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

    # Unlock the gnome-keyring login keyring with the password already typed
    # into the greeter. ARCHITECTURE.md claimed greetd's own NixOS module
    # turns this on whenever services.gnome.gnome-keyring.enable is set —
    # it does not, and never did: grepping nixpkgs, nothing but this line
    # sets it, and both hosts evaluated to `false`. programs.niri does enable
    # the keyring daemon itself (for the Secret portal), so the daemon has
    # been running all along with a keyring nothing ever unlocked.
    #
    # Symptom that found it: VS Code refusing the OS keyring and falling back
    # to its plaintext "basic text encryption" store. Anything else speaking
    # libsecret (Zen's saved logins, Nautilus remote mounts) has the same
    # dependency. The gcr ssh-agent that home/ssh relies on is the other side
    # of this — see docs/decisions.md.
    #
    # Here rather than in the host: every host that logs in through this
    # greeter wants it, and it is a property of the login path, not of one
    # machine's hardware.
    security.pam.services.greetd.enableGnomeKeyring = true;
  };
}
