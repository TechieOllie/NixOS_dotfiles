# Moonshine: a headless Moonlight-compatible game/desktop streaming server.
#
# Unlike Sunshine, Moonshine does not capture an existing session — every
# stream gets its own isolated compositor, spun up fresh, and what Moonlight
# lists as an "app" is just a command Moonshine runs inside it. So a full
# remote *desktop* is not a special mode: it's an app entry whose command
# happens to be a compositor session launcher.
#
# This is the system half only, and deliberately has no home/ counterpart:
# upstream's module generates the TOML into the store and passes it to the
# daemon as argv, and Moonshine only ever writes a config of its own when
# the given path doesn't exist. A Home-Manager-managed
# ~/.config/moonshine/config.toml would be read by nothing.
{
  config,
  lib,
  vars,
  moonshine,
  ...
}:
{
  imports = [
    # Imported here, in the one module that consumes it, rather than in
    # lib/mkHost.nix — the same rule modules/programs/steam.nix follows for
    # chaotic/millennium and modules/desktop/noctalia.nix for noctalia. A
    # host that never sets features.moonshine doesn't carry the flake.
    moonshine.nixosModules.moonshine
  ];

  config = lib.mkIf config.features.moonshine {
    services.moonshine = {
      enable = true;

      # The user whose applications get streamed. Upstream's module enables
      # lingering for this user itself (users.users.<user>.linger), which is
      # what makes the whole thing work with nobody logged in locally: the
      # user's systemd instance and session D-Bus — which Moonshine needs to
      # launch apps as transient units — come up at boot rather than at
      # graphical login. No `loginctl enable-linger` step to run by hand.
      user = vars.user.name;

      # uid is left to the module's own default, which reads
      # users.users.<user>.uid. modules/system/users.nix pins that to 1000
      # precisely so this resolves; the module asserts rather than guesses.

      # Silences the WARN logged for every dropped TLS probe. A Moonlight
      # client sitting idle on its Computers screen polls the HTTPS port
      # every 5s, which otherwise fills the journal with "TLS handshake
      # failed" for a client that is behaving perfectly normally.
      logFilter = "moonshine=info,moonshine_core::tls=error";

      # Deliberately left off. modules/services/tailscale.nix already puts
      # tailscale0 in networking.firewall.trustedInterfaces, so Moonshine is
      # reachable over the tailnet — authenticated and encrypted — without
      # opening the GameStream ports to the LAN. Upstream is explicit that
      # Moonshine is not designed for untrusted networks. Flip this to true
      # only to stream from a client that can't be on the tailnet.
      openFirewall = false;

      settings = {
        name = "Moonshine";

        # Split rather than one flat list: the two game launchers only exist
        # when features.gaming is on, and features.moonshine is an
        # independent flag. A host that streamed without the gaming stack
        # would otherwise advertise two entries in Moonlight whose commands
        # point at binaries that were never installed — an app that fails
        # with no diagnostics, which is exactly the failure mode the
        # stdout/stderr settings below exist to avoid.
        application = [
          {
            # The full remote desktop. niri is a Smithay compositor with a
            # supported nested (Winit) backend, which is what makes it a fit
            # for Moonshine's isolated-compositor model — it auto-detects
            # nesting with no flag. GNOME is not an option here: Mutter
            # grabs the DRM device rather than nesting, and GNOME 49 removed
            # --nested outright.
            #
            # niri-session rather than bare niri: launched as one of
            # Moonshine's transient units it detects that and execs
            # `niri --session`, which does the systemd/D-Bus session setup a
            # display manager would normally provide. greetd never sees this
            # session, so nothing else would do it.
            #
            # Note the consequence: `niri --session` drives
            # graphical-session.target in the *same* user manager as a local
            # login. Streaming the desktop while also logged in at the
            # machine means two niri instances contending over that target
            # and over WAYLAND_DISPLAY. Headless — the case lingering exists
            # for — is clean.
            title = "Desktop";
            command = [ "/run/current-system/sw/bin/niri-session" ];
            stdout = "journal";
            stderr = "journal";
          }
        ]
        ++ lib.optionals config.features.gaming [
          {
            title = "Steam";
            command = [
              "/run/current-system/sw/bin/steam"
              "steam://open/bigpicture"
            ];
            # Steam is single-instance per user, so with a desktop Steam
            # already running the steam:// URL is forwarded to *it* and Big
            # Picture opens on the physical screen while the stream fails
            # with a 503. Upstream's recommended workaround (TIPS.md, issue
            # #134): ask any running Steam to quit and wait up to ~30s for
            # it to actually go away before launching ours.
            pre_command = [
              [
                "/run/current-system/sw/bin/bash"
                "-c"
                "if pgrep -x steam >/dev/null; then /run/current-system/sw/bin/steam -shutdown &>/dev/null; for i in $(seq 1 30); do ! pgrep -x steam >/dev/null && break; sleep 1; done; fi"
              ]
            ];
            stdout = "journal";
            stderr = "journal";
          }
          {
            # The other half of the library — Epic, GOG and Amazon, which
            # Steam doesn't cover. `--console` is Heroic's console mode: a
            # controller-driven, TV-shaped UI that replaces the normal
            # sidebar layout with a full-viewport one, which is what you
            # want on the end of a stream. Verified as a real CLI flag
            # rather than assumed — Heroic's main process reads it as
            # `process.argv.includes("--console")`, alongside `--fullscreen`
            # and `--no-gui`. Add `--fullscreen` here too if the window ever
            # comes up smaller than the stream.
            #
            # A different profile from the entries above, not a different
            # kind of path. Heroic is a Home Manager package
            # (home/heroic.nix), so it isn't in `environment.systemPackages`
            # and never appears in /run/current-system/sw/bin —
            # /etc/profiles/per-user is where `home.packages` land, which is
            # true only because lib/mkHost.nix sets
            # `home-manager.useUserPackages`. With that off this would have
            # to be a store path, since the packages would live in the
            # user's own ~/.nix-profile and no system unit could name it.
            title = "Heroic";
            command = [
              "/etc/profiles/per-user/${vars.user.name}/bin/heroic"
              "--console"
            ];
            stdout = "journal";
            stderr = "journal";
          }
        ]
        ++ [
          {
            # Remote poweroff, so the machine doesn't have to be left on
            # after a session. -i is not optional here: without it systemd
            # refuses while any other session is logged in or holding an
            # inhibitor ("Please retry after closing inhibitors"). The
            # polkit rule below is a separate matter — it grants the
            # *authorization*; -i governs whether other sessions block it.
            title = "Shutdown";
            command = [
              "/run/current-system/sw/bin/systemctl"
              "poweroff"
              "-i"
            ];
            stdout = "journal";
            stderr = "journal";
          }
        ];
      };
    };

    # Two groups, for two unrelated reasons:
    #
    # `input` — streamed games read the virtual gamepad/keyboard/mouse that
    # Moonshine creates through inputtino. With an active local session the
    # seat's ACLs would cover that, but the headless case (the point of
    # lingering) has no active seat, and upstream's module deliberately
    # doesn't grant it.
    #
    # `moonshine` — the group upstream's own polkit rule is scoped to, which
    # is what lets Moonshine hold a block-type sleep inhibitor for the
    # duration of a stream. Without it streaming still works, but the host
    # may suspend mid-session.
    users.users.${vars.user.name}.extraGroups = [
      "input"
      "moonshine"
    ];

    # Authorization for the Shutdown app above. Moonshine launches apps from
    # a service context that polkit does not consider an active, interactive
    # session, so `systemctl poweroff` fails with
    # InteractiveAuthorizationRequired. Scoped to the one user and the two
    # power-off actions rather than granted wholesale.
    #
    # security.polkit.extraConfig, not a file dropped in /etc: nixpkgs builds
    # polkit with its rules directory under /run/current-system/sw/share, so
    # an /etc/polkit-1/rules.d drop — what a non-NixOS host would use — is
    # read by nothing.
    security.polkit.extraConfig = ''
      polkit.addRule(function(action, subject) {
        if ((action.id == "org.freedesktop.login1.power-off" ||
             action.id == "org.freedesktop.login1.power-off-multiple-sessions") &&
            subject.user == "${vars.user.name}") {
          return polkit.Result.YES;
        }
      });
    '';
  };
}
