# Region screenshot: slurp picks the area, grim captures it, the PNG is
# saved to ~/Pictures/Screenshots and copied to the clipboard, and a
# notification offers to open it in Satty. Ported from the operator's
# shell_dotfiles `scripts/screenshot`; replaces Noctalia's own
# `screenshot-region` IPC (and the `shell.screenshot` settings that fed it).
#
# Checked against Noctalia v5's notification daemon (flake input source:
# src/dbus/notification, src/shell/notification) — see the comments on the
# notify-send call for the two ways it differs from v4.
#
# Packaged with writeShellApplication so every tool is on the script's PATH
# by construction rather than whatever the session happens to export.
# Bound to Mod+Shift+S in home/niri/cfg/keybinds.kdl.
#
# Self-gates on osConfig.features.niri: slurp/grim are Wayland-only.
{
  pkgs,
  lib,
  osConfig,
  ...
}:
let
  screenshot = pkgs.writeShellApplication {
    name = "screenshot";
    runtimeInputs = with pkgs; [
      slurp
      grim
      wl-clipboard
      libnotify
      satty
      coreutils
      gnugrep
    ];
    text = ''
      dir="$HOME/Pictures/Screenshots"
      mkdir -p "$dir"

      file="$dir/Screenshot_$(date +'%Y-%m-%d_%H-%M-%S').png"

      # Escape during selection cancels quietly.
      geometry=$(slurp -o) || exit 0

      grim -g "$geometry" "$file"
      wl-copy < "$file"

      # `default` is the freedesktop "clicked the notification body" action.
      # Noctalia v5 draws every *other* action key as a button and only
      # fires `default` from a click on the toast itself, so a custom key
      # like `edit` would not match the "Click to edit" text below.
      #
      # v5 also holds back NotificationClosed for an expired notification
      # that carries actions until it is dismissed from history, which would
      # leave notify-send waiting indefinitely; timeout bounds that.
      timeout 60 notify-send -i satty \
        "Screenshot saved" \
        "Click to edit with Satty" \
        --action="default=Edit" | grep -q default \
        && satty --filename "$file"
    '';
  };
in
lib.mkIf osConfig.features.niri {
  home.packages = [ screenshot ];
}
