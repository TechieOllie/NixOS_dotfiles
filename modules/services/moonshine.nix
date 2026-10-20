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
  pkgs,
  vars,
  moonshine,
  ...
}:
let
  # Box art for the entries below. Moonshine will guess one for an app that
  # declares none, but the guess can't work here for two independent reasons:
  # it looks the app's own lowercased title up in the XDG icon directories,
  # and (a) the moonshine daemon is a systemd *system* service, which on
  # NixOS gets no XDG_DATA_DIRS at all — so the lookup falls back to
  # /usr/local/share and /usr/share, neither of which exists here — and (b)
  # two of the four titles ("Desktop", "Shutdown") are not application names
  # and would match nothing even with the search path fixed. Declaring the
  # path outright sidesteps both, and pins which icon each entry gets rather
  # than leaving it to whatever the resolver scores highest.
  #
  # Papirus-Dark, the same theme home/gtk.nix sets for the session, so a
  # streamed machine looks like itself. It ships SVG only and Moonshine
  # decodes raster formats only (png/jpg/webp/bmp/ico — no SVG), so each icon
  # is rasterized here at build time. 600px square is Moonshine's own box art
  # *width*: it letterboxes anything that isn't 600x801 onto a transparent
  # canvas of that size, so rendering at the width means it centres the icon
  # without rescaling it.
  #
  # Interpolating the result into settings puts a store reference in the
  # generated config TOML, which is part of the system closure — so these
  # can't be garbage-collected out from under a running daemon.
  boxart =
    name: iconPath:
    pkgs.runCommand "moonshine-boxart-${name}.png" { nativeBuildInputs = [ pkgs.librsvg ]; } ''
      rsvg-convert -w 600 -h 600 \
        -o "$out" \
        ${pkgs.papirus-icon-theme}/share/icons/Papirus-Dark/${iconPath}
    '';

  # The Desktop entry's command: Umbriel, nested inside Moonshine's
  # per-stream compositor. Moonshine launches each app with WAYLAND_DISPLAY
  # and DISPLAY pointing at that compositor, and a plain `umbriel` started
  # that way picks wlroots' Wayland backend by itself and nests. In nested
  # mode it also leaves the systemd user environment alone (server.cpp runs
  # its session-sync command only `if (!m_nested)`), so it can never take
  # over a local login's session on its own.
  #
  # Not `start-umbriel` (the session's Exec): under a transient user unit it
  # takes its MANAGERPID branch and execs plain `umbriel` anyway, and its
  # other branch starts umbriel.service, the *local* session's unit, which a
  # stream has no business touching.
  #
  # So the session wiring that umbriel.service would otherwise do is done
  # here by hand, from Umbriel's own startup command (`umbriel -s <cmd>`)
  # rather than before it: the values to publish are the *nested* instance's
  # WAYLAND_DISPLAY and UMBRIEL_SOCKET, not Moonshine's, and they don't exist
  # until Umbriel is up. Umbriel exports them, plus XDG_CURRENT_DESKTOP, into
  # that child's environment (verified on theseus, 2026-10-20).
  #
  # Until 2026-10-20 this was a nested niri, which needed more of this by
  # hand (`niri --session` strips the very variables that make it nest, and
  # nested niri sets no XDG_CURRENT_DESKTOP); docs/decisions.md has that
  # history.

  # The variables Umbriel's own native session publishes
  # (sessionEnvironmentCommand() in server.cpp), verbatim. Publishing them
  # is what makes graphical-session.target's units — Noctalia above all —
  # attach to the streamed compositor instead of nothing.
  sessionEnv = "WAYLAND_DISPLAY DISPLAY XDG_CURRENT_DESKTOP XDG_SESSION_DESKTOP XDG_SESSION_TYPE XCURSOR_THEME XCURSOR_SIZE UMBRIEL_SOCKET";

  # Run inside the nested Umbriel, as its startup command, and only when the
  # wrapper below decided this stream owns the session (see there).
  desktopStartup = pkgs.writeShellScript "moonshine-desktop-startup" ''
    export PATH=/run/current-system/sw/bin:$PATH

    if [ "''${MOONSHINE_OWNS_SESSION:-}" != "1" ]; then
      echo "moonshine: graphical-session.target already belongs to a local" \
           "login; streaming a bare Umbriel without the shell. Log out locally" \
           "for a full desktop." >&2
      exit 0
    fi

    systemctl --user import-environment ${sessionEnv}

    # D-Bus's activation environment is separate from systemd's, and not
    # every activatable service is SystemdService=.
    dbus-update-activation-environment --systemd ${sessionEnv}

    # What a native Umbriel starts once its environment is published:
    # BindsTo= graphical-session.target, Wants= xdg-desktop-autostart.target.
    systemctl --user start umbriel-session.target
  '';

  desktopSession = pkgs.writeShellScript "moonshine-desktop" ''
    export PATH=/run/current-system/sw/bin:$PATH

    # Whether this stream is allowed to drive the session, decided *before*
    # Umbriel starts. graphical-session.target is per-user, not per-seat, so
    # a local login already owns it; taking it over would move Noctalia to
    # the stream, and tearing it down at the end of the stream would kill the
    # session on the physical screen. Neither is ours to do, so when it is
    # already active this degrades to a bare nested Umbriel — no shell, but
    # a compositor that renders, which is still a usable remote desktop.
    # Headless — the case lingering exists for — takes the other branch and
    # gets the full session.
    if systemctl --user -q is-active graphical-session.target; then
      export MOONSHINE_OWNS_SESSION=0
    else
      export MOONSHINE_OWNS_SESSION=1
      # Tear the session down when the stream ends, the way start-umbriel
      # does: umbriel-shutdown.target Conflicts= graphical-session.target, so
      # one job stops everything attached to it. Not `exec umbriel` below,
      # precisely so this trap still has a shell to run in.
      #
      # --no-block, unlike start-umbriel: this trap runs while Moonshine is
      # *stopping* this very unit, and a blocking start of that job waits on
      # a transaction that can't finish until this unit has stopped. Tested
      # on the desktop (2026-10-20), it hung until the 90-second stop timeout
      # SIGKILLed the trap, before it could unset the environment below.
      trap '
        systemctl --user start --no-block --job-mode=replace-irreversibly umbriel-shutdown.target || true
        systemctl --user unset-environment ${sessionEnv} || true
      ' EXIT
    fi

    umbriel -s ${desktopStartup}
  '';

  # Where the streamed user's per-launcher data lives. Read off the user
  # rather than written out, so this can't drift from modules/system/users.nix.
  # Moonshine does expand $HOME in these paths itself, but only because the
  # daemon happens to run as this user — the path is a fact about the config,
  # not about the process, so it is stated outright.
  homeDir = config.users.users.${vars.user.name}.home;

  # Steam is single-instance per user, so any steam:// URL handed to a Steam
  # that is already running is forwarded to *it* — the game opens on the
  # physical screen and the stream fails with a 503. Upstream's recommended
  # workaround (TIPS.md, issue #134): ask a running Steam to quit, then wait up
  # to ~30s for it to actually go away. Needed identically by the Big Picture
  # entry and by every game the Steam scanner finds, hence a binding.
  steamShutdown = [
    [
      "/run/current-system/sw/bin/bash"
      "-c"
      "if pgrep -x steam >/dev/null; then /run/current-system/sw/bin/steam -shutdown &>/dev/null; for i in $(seq 1 30); do ! pgrep -x steam >/dev/null && break; sleep 1; done; fi"
    ]
  ];

  # Heroic's counterpart, needed for the same reason and shaped differently
  # because Heroic gives less to work with. It is single-instance too — its
  # main process takes Electron's `requestSingleInstanceLock()` and the
  # `second-instance` handler forwards a later invocation's argv to the
  # running copy and shows its window (read out of 2.22.0's `app.asar`, not
  # assumed). So `heroic --console` or a `heroic://launch?...` URL sent while
  # a desktop Heroic is open acts on *that* instance: the launcher or the
  # game appears on the physical screen and the stream gets a compositor with
  # no client in it.
  #
  # Unlike Steam there is no `-shutdown` to ask politely with, so this asks
  # the main process with SIGTERM — the browser process handles it and shuts
  # down the way a window close would. Two guards around that, because the
  # thing being terminated may be doing real work:
  #
  #   * If any of Heroic's own helper binaries are running (`legendary`,
  #     `gogdl`, `nile`, `comet`) then something is downloading, installing,
  #     or actually playing — Heroic drives all four as child processes. This
  #     refuses rather than terminating, which is the case the old "close it
  #     by hand" note was really protecting.
  #   * Only the *main* process is signalled, identified as a `heroic`
  #     process whose parent is not itself one; the renderer, GPU and zygote
  #     children share the name and go away with it.
  #
  # Refusing means exiting non-zero, and that aborts the launch: Moonshine
  # builds pre-commands into the transient unit's ExecStartPre with the
  # ignore-failure flag off, so a failed one fails the unit and the app never
  # starts. That is the point — a visible failure on the client beats a game
  # silently starting on the machine's own screen.
  heroicShutdown = [
    [
      "${pkgs.writeShellScript "moonshine-heroic-shutdown" ''
        export PATH=/run/current-system/sw/bin:$PATH

        pgrep -x heroic >/dev/null || exit 0

        for helper in legendary gogdl nile comet; do
          if pgrep -x "$helper" >/dev/null; then
            echo "moonshine: Heroic is busy ($helper is running — a download," \
                 "install or game). Refusing to close it; finish or stop that" \
                 "first, or close Heroic by hand." >&2
            exit 1
          fi
        done

        # The main process is the one Electron holds the single-instance lock
        # in; its children (renderer, GPU, zygote) carry the same name, so
        # pick out the processes whose parent is not also a heroic.
        mains=""
        for pid in $(pgrep -x heroic); do
          ppid=$(ps -o ppid= -p "$pid" 2>/dev/null | tr -d ' ')
          [ -n "$ppid" ] || continue
          if [ "$(ps -o comm= -p "$ppid" 2>/dev/null | tr -d ' ')" != "heroic" ]; then
            mains="$mains $pid"
          fi
        done

        if [ -z "$mains" ]; then
          echo "moonshine: heroic processes are running but none looks like the" \
               "main process; not signalling anything." >&2
          exit 1
        fi

        kill -TERM $mains 2>/dev/null || true

        for _ in $(seq 1 30); do
          pgrep -x heroic >/dev/null || exit 0
          sleep 1
        done

        echo "moonshine: Heroic did not exit within 30s of SIGTERM. Not" \
             "escalating to SIGKILL — close it by hand." >&2
        exit 1
      ''}"
    ]
  ];
in
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
        # The Desktop entry is gated for the same reason the two launcher
        # entries below are: features.moonshine and features.umbriel are
        # independent flags, and a streaming host with no compositor would
        # otherwise advertise a card whose command isn't installed.
        application =
          lib.optionals config.features.umbriel [
            {
              # The full remote desktop: Umbriel, nested. A wlroots
              # compositor, so it renders into Moonshine's compositor through
              # the Wayland backend, which is what makes it a fit for
              # Moonshine's isolated-compositor model. GNOME is not an option
              # here: Mutter grabs the DRM device rather than nesting, and
              # GNOME 49 removed --nested outright.
              #
              # See desktopSession above for why this is a wrapper rather
              # than the session's own start-umbriel, and for the guard that
              # keeps a stream from taking over a local login: the two share
              # one user manager, so only a headless stream — the case
              # lingering exists for — gets the full session.
              title = "Desktop";
              # Umbriel ships no icon of its own. Papirus' generic
              # devices/video-display is the obvious stand-in but is a
              # near-black monitor on a transparent background, which
              # disappears into Moonlight's own dark app grid; this one says
              # "remote desktop" and is legible there.
              boxart = boxart "desktop" "64x64/apps/preferences-desktop-remote-desktop.svg";
              # The AppId= argument is not for the wrapper, which ignores its
              # arguments: it is what lets the keyboard reach the stream.
              # Moonshine's compositor runs with steam_mode on (its default,
              # and server-wide, so turning it off would change the Steam and
              # Heroic streams too), which makes focus Steam-controlled: only
              # a window with a Steam game id is a focus candidate. Moonshine
              # finds that id by walking the window's process tree and
              # scanning each command line for `AppId=<N>`
              # (scan_cmdline_for_app_id), and the nested Umbriel's parent is
              # this wrapper. Without it the log reads `No focus candidates;
              # clearing focus`, keyboard focus is never set, and every key
              # is dropped while the mouse — routed by position — still
              # works. The number only has to be non-zero and not Steam's own
              # (769 is Big Picture); this one is deliberately no real app.
              command = [
                "${desktopSession}"
                "AppId=2000000000"
              ];
              stdout = "journal";
              stderr = "journal";
            }
          ]
          ++ lib.optionals config.features.gaming [
            {
              title = "Steam";
              boxart = boxart "steam" "64x64/apps/steam.svg";
              command = [
                "/run/current-system/sw/bin/steam"
                "steam://open/bigpicture"
              ];
              # See steamShutdown above for why this is needed.
              pre_command = steamShutdown;
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
              boxart = boxart "heroic" "64x64/apps/heroic.svg";
              command = [
                "/etc/profiles/per-user/${vars.user.name}/bin/heroic"
                "--console"
              ];
              # See heroicShutdown above: without this, a Heroic already open
              # on the physical screen swallows this invocation and the stream
              # gets an empty compositor.
              pre_command = heroicShutdown;
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
              boxart = boxart "shutdown" "64x64/apps/system-shutdown.svg";
              command = [
                "/run/current-system/sw/bin/systemctl"
                "poweroff"
                "-i"
              ];
              stdout = "journal";
              stderr = "journal";
            }
          ];

        # The entries above are the two launchers' own front ends — Big
        # Picture and Heroic's console mode — which are what you want when
        # you don't know yet what you're playing. These scanners add the
        # library itself: one Moonlight card per installed game, launched
        # directly, so a stream can start in the game rather than three
        # menus away from it. Moonshine merges scanned entries into the
        # static list at startup and de-duplicates on (title, command), so
        # the two can't collide.
        #
        # Gated on features.gaming for the same reason the launcher entries
        # are: on a host streaming without the gaming stack these would
        # point at binaries that were never installed.
        #
        # Scanning happens in the daemon at startup, not at build time — the
        # generated TOML names the libraries, and installing or removing a
        # game changes the app list on the next `systemctl restart
        # moonshine`, with no rebuild.
        application_scanner = lib.optionals config.features.gaming [
          {
            type = "steam";

            # One entry covers both libraries on this machine: steamlocate
            # reads libraryfolders.vdf from the library named here and then
            # walks every library it lists, so the games on /mnt/storage are
            # found too. Box art is deliberately still looked up under
            # *this* path (appcache/librarycache), which is where Steam
            # caches art for every library, so the second one needs nothing.
            library = "${homeDir}/.local/share/Steam";

            # -bigpicture alongside the game, as upstream's own example
            # does: without it Steam brings up the desktop client window in
            # the stream's compositor next to the game, and the two compete
            # for focus. {game_id} is substituted per app by the scanner.
            command = [
              "/run/current-system/sw/bin/steam"
              "-bigpicture"
              "steam://rungameid/{game_id}"
            ];
            pre_command = steamShutdown;
            stdout = "journal";
            stderr = "journal";
          }
          {
            type = "heroic";

            # Explicit rather than left to the default. Upstream's default
            # picks between the native and Flatpak config directories by
            # probing which exists, from the daemon's own process context —
            # a runtime guess where this repo can state the answer.
            config_dir = "${homeDir}/.config/heroic";

            # --no-gui plus a heroic:// URL is Heroic's own launch protocol:
            # it starts the game without ever drawing the library window.
            # {app_name} is Heroic's internal game id and {runner} the store
            # it came from (legendary/gog/nile/sideload), both substituted
            # per app. Same per-user profile path as the Heroic entry above,
            # and for the same reason.
            #
            # Same single-instance problem Steam has, so the same shape of
            # answer: a heroic:// URL handed to a Heroic that is already
            # running is forwarded to *it*, and the game starts on the
            # physical screen while the stream shows an empty compositor. See
            # heroicShutdown above for why this asks with SIGTERM and why it
            # refuses outright when Heroic is mid-download.
            command = [
              "/etc/profiles/per-user/${vars.user.name}/bin/heroic"
              "--no-gui"
              "heroic://launch?appName={app_name}&runner={runner}"
            ];
            pre_command = heroicShutdown;
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
