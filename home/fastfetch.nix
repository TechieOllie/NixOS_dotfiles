# fastfetch, the system-summary tool, shown at the top of every new Ghostty
# window.
#
# Laid out for a half-size Ghostty window, which is how terminals usually
# sit in a column here: on theseus that is 83x53 cells side by side and about
# half the rows stacked. Hence the small NixOS logo (16 columns, 7 rows)
# rather than the 40-column default, and short formats that keep the widest
# line under 60 columns and the whole thing at 16 rows. fastfetch truncates
# a line that still doesn't fit rather than wrapping it.
#
# The two `command` modules are what this repo adds over the stock list: the
# running system generation (what `nixos-rebuild switch --rollback` steps
# back from) and the ~/.dotfiles commit it was presumably built from, with
# `*` when the clone has uncommitted changes. Battery and the desktop's
# /mnt/storage disk are listed everywhere; fastfetch hides a module that
# finds nothing (theseus has no /mnt/storage, the desktop no battery).
#
# Noctalia's "fastfetch" community template is deliberately not enabled:
# its apply.sh merges colours into ~/.config/fastfetch/config.jsonc in
# place, the same conflict that rules out the official starship and lazygit
# templates — and that file is a Home Manager symlink now. Every colour
# below is an ANSI name instead, so it follows Ghostty's palette, which
# Noctalia's ghostty template keeps in step with the wallpaper.
#
# Self-gates on osConfig.features.workstation, like the rest of the
# operator's terminal environment.
{
  config,
  lib,
  osConfig,
  ...
}:
let
  dots = "${config.home.homeDirectory}/.dotfiles";
  system = "/nix/var/nix/profiles/system";
in
lib.mkIf osConfig.features.workstation {
  programs.fastfetch = {
    enable = true;
    settings = {
      logo = {
        source = "nixos_small";
        padding = {
          top = 1;
          left = 1;
          right = 3;
        };
      };
      display = {
        separator = "  ";
        key.width = 11;
        duration = {
          abbreviation = true;
          spaceBeforeUnit = "never";
        };
        size.ndigits = 1;
      };
      modules = [
        "title"
        {
          type = "os";
          key = "󱄅 os";
          format = "{pretty-name}";
        }
        {
          type = "kernel";
          key = " kernel";
          format = "{release}";
        }
        {
          # The profile link's own mtime is when it was switched to; the
          # store path it points at is always dated 1970.
          type = "command";
          key = "󰑓 gen";
          text = "echo \"$(readlink ${system} | tr -dc 0-9) · $(date -d @$(stat -c %Y ${system}) '+%b %d %H:%M')\"";
        }
        {
          type = "command";
          key = " dots";
          text = "echo \"$(git -C ${dots} log -1 --format='%h · %cr')$(git -C ${dots} diff --quiet HEAD || echo ' *')\"";
        }
        {
          type = "packages";
          key = "󰏖 pkgs";
          format = "{nix-system} system · {nix-user} user";
        }
        {
          type = "uptime";
          key = "󰔟 uptime";
        }
        {
          type = "wm";
          key = " wm";
          format = "{pretty-name} {version}";
        }
        {
          type = "cpu";
          key = " cpu";
          format = "{name} ({cores-logical})";
        }
        {
          type = "gpu";
          key = "󰢮 gpu";
          format = "{name}";
        }
        {
          type = "memory";
          key = " mem";
        }
        {
          type = "disk";
          key = "󰋊 disk";
          folders = "/:/mnt/storage";
          format = "{size-used} / {size-total} ({size-percentage})";
        }
        {
          type = "battery";
          key = "󰁹 bat";
          format = "{capacity} · {status}";
        }
        "break"
        {
          type = "colors";
          symbol = "circle";
          paddingLeft = 2;
        }
      ];
    };
  };

  # Once per Ghostty window. The variable is exported, so anything started
  # from that shell (a nested zsh, `nix develop`, Neovim's :terminal)
  # inherits it and stays quiet, while a new window starts from Ghostty's
  # own environment and shows it again. Not over SSH, where Ghostty's
  # ssh-env would otherwise carry TERM_PROGRAM along, and not in a window
  # too short to hold it without scrolling the prompt away. The lazygit
  # scratchpad runs no shell at all.
  programs.zsh.initContent = lib.mkOrder 1500 ''
    if [[ $TERM_PROGRAM == ghostty && -z $FASTFETCH_SHOWN && -z $SSH_CONNECTION ]] && (( LINES >= 20 && COLUMNS >= 50 )); then
      export FASTFETCH_SHOWN=1
      fastfetch
    fi
  '';
}
