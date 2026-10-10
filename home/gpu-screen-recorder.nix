# Replay buffer ("save the last minute") on demand, driven by niri keybinds
# rather than GPU Screen Recorder's own overlay. The overlay (gsr-ui) was
# tried first and dropped the same day, before it ever ran: to catch its
# Alt+Z hotkey on Wayland it grabs every physical keyboard and re-emits
# input through a virtual one, which is a lot to keep running in front of
# the keyboard all session when niri can bind the two keys itself.
#
#   replay toggle   start the buffer on the focused monitor, or stop it
#   replay save     write the buffer out to ~/Videos/Replays
#
# The recorder runs as a transient user unit (gsr-replay), so "is it
# running" is a systemctl question rather than a pidfile, its output lands
# in `journalctl --user -u gsr-replay`, and stopping it is systemd's job.
# KillSignal is SIGINT because that is the recorder's own "stop" — in
# replay mode it stops without writing anything.
#
# The monitor is asked of niri at start time rather than named here: a
# connector name is host cabling (see the greeter's output pin), and "the
# monitor the game is on" is whichever one has focus when you press the key.
# Bound in home/niri/cfg/keybinds.kdl; the capture helper's capability
# wrapper is modules/programs/gpu-screen-recorder.nix.
{
  pkgs,
  lib,
  osConfig,
  ...
}:
let
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

      case "''${1:-}" in
        toggle)
          if systemctl --user -q is-active "$unit"; then
            systemctl --user stop "$unit"
            notify-send -i media-record "Replay buffer stopped"
            exit 0
          fi

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
          ;;
        save)
          if ! systemctl --user -q is-active "$unit"; then
            notify-send -i dialog-warning "Replay buffer is off" "Alt+Shift+F10 starts it"
            exit 1
          fi
          systemctl --user kill -s SIGUSR1 "$unit"
          notify-send -i media-record "Replay saved" "$dir"
          ;;
        *)
          echo "usage: replay toggle|save" >&2
          exit 2
          ;;
      esac
    '';
  };
in
lib.mkIf (osConfig.features.gaming && osConfig.features.niri) {
  home.packages = [ replay ];
}
