# Replay buffer ("save the last minute"), started automatically while a game
# is open and also driven by niri keybinds, rather than by GPU Screen
# Recorder's own overlay. The overlay (gsr-ui) was tried first and dropped
# the same day, before it ever ran: to catch its Alt+Z hotkey on Wayland it
# grabs every physical keyboard and re-emits input through a virtual one,
# which is a lot to keep running in front of the keyboard all session when
# niri can bind the two keys itself.
#
#   replay toggle   start the buffer on the focused monitor, or stop it
#   replay save     write the buffer out to ~/Videos/Replays
#   replay watch    follow niri's window events and start the buffer when
#                   a game window opens, stopping it once the last one has
#                   been gone for a grace period (the replay-auto unit)
#
# The recorder runs as a transient user unit (gsr-replay), so "is it
# running" is a systemctl question rather than a pidfile, its output lands
# in `journalctl --user -u gsr-replay`, and stopping it is systemd's job.
# KillSignal is SIGINT because that is the recorder's own "stop" — in
# replay mode it stops without writing anything.
#
# The monitor is asked of niri at start time rather than named here: a
# connector name is host cabling (see the greeter's output pin), and "the
# monitor the game is on" is whichever one has focus when it starts.
# Bound in home/niri/cfg/keybinds.kdl; the capture helper's capability
# wrapper is modules/programs/gpu-screen-recorder.nix.
{
  pkgs,
  lib,
  osConfig,
  ...
}:
let
  # A game is recognised by its window's app_id alone, because that is all
  # niri can say about an X11 window: every client of xwayland-satellite
  # reports the satellite's own pid, so the game's environment can't be
  # inspected. Proton names a game's window class `steam_app_<SteamAppId>`,
  # and umu passes Heroic's games SteamAppId 0, so DEATH STRANDING through
  # Heroic is `steam_app_0` (seen live). `.exe` catches Wine run without
  # Proton's naming, whose default WM_CLASS is the executable name. A native
  # Linux game matches neither and needs Alt+Shift+F10.
  gamePattern = ''^steam_app_[0-9]+$|\.exe$'';

  replay = pkgs.writeShellApplication {
    name = "replay";
    runtimeInputs = with pkgs; [
      gpu-screen-recorder
      jq
      libnotify
      systemd
      coreutils
    ];
    # niri itself deliberately isn't a runtimeInput: `niri msg` has to be
    # the same build as the running compositor, which is the one on the
    # session's PATH.
    text = ''
      unit=gsr-replay
      dir="$HOME/Videos/Replays"

      running() { systemctl --user -q is-active "$unit"; }

      start() {
        output=$(niri msg --json focused-output | jq -r .name)
        mkdir -p "$dir"
        # 60 s at 60 fps, kept in RAM (the recorder's default storage;
        # disk mode would write to the NVMe continuously). Desktop audio
        # only, no microphone.
        systemd-run --user --quiet --collect --unit="$unit" \
          -p KillSignal=SIGINT \
          gpu-screen-recorder -w "$output" -f 60 -r 60 \
            -a default_output -c mp4 -o "$dir"
        notify-send -i media-record "Replay buffer on" "Recording $output — Alt+F10 saves the last minute"
      }

      stop() {
        systemctl --user stop "$unit"
        notify-send -i media-record "Replay buffer stopped"
      }

      watch() {
        # One line per event that matters, so the loop below stays plain
        # bash: "reset" plus the current game windows on the initial
        # snapshot, then "game"/"other"/"closed" with a window id. Single
        # quotes on purpose: the $pattern and \(…) in it are jq's, not bash's.
        # shellcheck disable=SC2016
        filter='
          def game: (.app_id // "") | test($pattern; "i");
          if .WindowsChanged then
            "reset", (.WindowsChanged.windows[] | select(game) | "game \(.id)")
          elif .WindowOpenedOrChanged then
            .WindowOpenedOrChanged.window
            | if game then "game \(.id)" else "other \(.id)" end
          elif .WindowClosed then
            "closed \(.WindowClosed.id)"
          else empty end'

        declare -A games=()
        ours=0      # did this watcher start the buffer? never stop one it didn't
        deadline=0  # when to stop, once the last game window has gone
        grace=15    # launchers often close one window just before the game's opens

        while true; do
          if (( deadline )); then
            wait_for=$(( deadline - $(date +%s) ))
            if (( wait_for <= 0 )); then
              if (( ours )) && running; then stop; fi
              ours=0 deadline=0
              continue
            fi
            rc=0
            read -r -t "$wait_for" event id || rc=$?
            if (( rc > 128 )); then
              continue  # timed out: re-check the deadline
            elif (( rc )); then
              break     # niri has gone away
            fi
          else
            read -r event id || break
          fi

          case "$event" in
            reset) games=() ;;
            game) games[$id]=1 ;;
            other | closed) unset "games[$id]" ;;
          esac

          if (( ''${#games[@]} )); then
            deadline=0
            if ! running; then start; ours=1; fi
          elif (( ours )) && (( ! deadline )); then
            deadline=$(( $(date +%s) + grace ))
          fi
        done < <(niri msg --json event-stream | jq --unbuffered -r --arg pattern '${gamePattern}' "$filter")
      }

      case "''${1:-}" in
        toggle)
          if running; then stop; else start; fi
          ;;
        save)
          if ! running; then
            notify-send -i dialog-warning "Replay buffer is off" "Alt+Shift+F10 starts it"
            exit 1
          fi
          # The main process only: by default systemctl signals the whole
          # unit, and gsr-kms-server (the capture helper, in the same
          # cgroup) has no SIGUSR1 handler, so it died on the first save and
          # every later save came out empty.
          systemctl --user kill --kill-whom=main -s SIGUSR1 "$unit"
          notify-send -i media-record "Replay saved" "$dir"
          ;;
        watch)
          watch
          ;;
        *)
          echo "usage: replay toggle|save|watch" >&2
          exit 2
          ;;
      esac
    '';
  };
in
lib.mkIf (osConfig.features.gaming && osConfig.features.niri) {
  home.packages = [ replay ];

  # The watcher only reads niri's event stream; it holds no device and
  # records nothing until a game window appears. `systemctl --user stop
  # replay-auto` turns automatic starts off for the session.
  systemd.user.services.replay-auto = {
    Unit = {
      Description = "Start the replay buffer while a game is open";
      PartOf = [ "graphical-session.target" ];
      After = [ "graphical-session.target" ];
    };
    Service = {
      ExecStart = "${lib.getExe replay} watch";
      Restart = "on-failure";
    };
    Install.WantedBy = [ "graphical-session.target" ];
  };
}
