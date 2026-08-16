{
  vars,
  pkgs,
  ...
}:
{
  imports = [
    ./features.nix
    ./disko.nix
    ./hardware-configuration.nix
    ./secrets.nix
    ../../profiles/base.nix
    ../../modules/desktop/niri.nix
    ../../modules/desktop/greetd.nix
    ../../modules/desktop/noctalia.nix
    ../../modules/desktop/theming.nix
    ../../modules/desktop/nautilus.nix
  ];

  networking.hostName = vars.system.hostName;
  time.timeZone = vars.system.timeZone;
  console.keyMap = vars.system.keyMap;

  # QEMU/SPICE guest tooling — belongs directly on this host rather than a
  # shared module, since it's only relevant because this host *is* a VM, not
  # a general capability another host would ever opt into. Syncs cursor
  # (fixes SPICE's own duplicate cursor overlay against niri's), clipboard,
  # and display resolution with the SPICE client.
  services.spice-vdagentd.enable = true;

  # ── Non-interactive testing ─────────────────────────────────────────────
  #
  # Everything below exists so this host can be driven end-to-end over SSH
  # with no keyboard at its console and no password prompt. It is scoped to
  # this host's own default.nix on purpose and must never move into a
  # module or profile: each item trades away a real security property, and
  # that trade is only acceptable because this VM is disposable, holds
  # nothing, is reachable only on a host-local libvirt network, and only
  # ever gets a throwaway test SSH key (see CLAUDE.md's host table).
  #
  # Without these, verifying a change meant a human typing a sudo password
  # for every `nixos-rebuild switch` and logging in at the greeter before
  # any GUI could be tested at all — which made "eval passing is not
  # verification" expensive enough to skip, the exact failure this repo
  # keeps rediscovering.

  # Lets `ssh ol@<vm> sudo nixos-rebuild switch --flake ...` run unattended.
  # Blast radius is the whole wheel group, not just nixos-rebuild: an
  # allow-list of one command sounds tighter but isn't, since rebuilding to
  # an arbitrary flake is already full root by another name.
  security.sudo.wheelNeedsPassword = false;

  # Autologin straight into niri at boot, so a graphical session exists to
  # test against without anyone reaching the console. greetd's
  # `initial_session` runs only for the *first* login after boot and falls
  # back to `default_session` (the Noctalia greeter, from
  # modules/desktop/greetd.nix) on logout — so the greeter itself is still
  # testable by logging out, and only upstream's `default_session.command`
  # is set there, at mkDefault, so this merges rather than conflicts.
  services.greetd.settings.initial_session = {
    command = "niri-session";
    user = vars.user.name;
  };

  # An ad-hoc SSH shell has no graphical session context — NIRI_SOCKET,
  # WAYLAND_DISPLAY and friends live in the session's own systemd --user
  # manager (a standing gotcha in CLAUDE.md). This wrapper imports that
  # environment and then execs, turning the two-step dance into
  # `ssh ol@<vm> in-session niri msg windows`.
  environment.systemPackages = [
    (pkgs.writeShellScriptBin "in-session" ''
      set -eu
      if [ "$#" -eq 0 ]; then
        echo "usage: in-session <command> [args...]" >&2
        exit 64
      fi
      # `systemctl --user show-environment` emits KEY=value lines; export
      # them into this shell before handing control to the command. Only the
      # graphical variables are taken — importing the whole environment
      # would clobber PATH and SSH_AUTH_SOCK with the session's own.
      # Fed by process substitution, not a pipe: a pipe would run the loop
      # in a subshell and the exports would die with it.
      while IFS= read -r line; do
        case "$line" in
          WAYLAND_DISPLAY=* | NIRI_SOCKET=* | DISPLAY=* | XDG_RUNTIME_DIR=* | XDG_SESSION_TYPE=* | XDG_CURRENT_DESKTOP=*)
            export "''${line}"
            ;;
        esac
      done < <(systemctl --user show-environment)
      exec "$@"
    '')
  ];

  # Pinned nixpkgs (nixos-unstable) is currently tracking the 26.11 branch,
  # i.e. 26.05 is the latest released stable version — stateVersion should
  # reference a real release, not the in-development one. Once set, this
  # value should not be bumped on later upgrades; it only marks the
  # compatibility baseline from this host's first install.
  system.stateVersion = "26.05";
}
