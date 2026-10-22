# fastfetch, the system-summary tool, shown at the top of every new Ghostty
# window.
#
# Laid out for a half-size Ghostty window, which is how terminals usually
# sit in a column here: on theseus that is 83x53 cells side by side and about
# half the rows stacked. Hence the small NixOS logo (15 columns, 7 rows)
# rather than the 40-column default, and short formats that keep the widest
# line under 70 columns and the whole thing at 17 rows. fastfetch truncates
# a line that still doesn't fit rather than wrapping it.
#
# Hierarchy, not hue. Noctalia derives the ANSI palette from the wallpaper,
# and a muted one gives colours 2-6 nearly the same grey, so anything that
# leans on several ANSI colours reads as flat (it did, 2026-10-22). Instead
# the lines are grouped — system, this repo's generation and commit, then
# hardware — under dim rules, keys are bold in the accent, and usage gets a
# thin two-tone bar plus its percentage. The bars have one fixed colour:
# fastfetch's default shades each bar by position, green to red, which on a
# 64% battery puts a red stub at the left that reads as a warning. No
# `colors` row either: on a muted palette it is seven greys and a red.
# CPU is read from /proc/cpuinfo rather than the cpu module, to drop the
# (R)/(TM) marks and AMD's "6-Core Processor" suffix.
#
# The two `command` modules are what this repo adds over the stock list: the
# running system generation (what `nixos-rebuild switch --rollback` steps
# back from) and the ~/.dotfiles commit it was presumably built from, with
# `*` when the clone has uncommitted changes. Battery and the desktop's
# /mnt/storage disk are listed everywhere; fastfetch hides a module that
# finds nothing (theseus has no /mnt/storage, the desktop no battery).
#
# The logo is `nixos_old_small`, plain ASCII: fastfetch 2.69's
# `nixos_small` is drawn in Unicode sextants (U+1FB00 block), which
# JetBrainsMono Nerd Font doesn't carry (Nerd Fonts patches in icons, not
# that block), so it renders broken in Ghostty too.
# Every key icon is a Material Design Nerd glyph (U+F0000 and up); the
# older BMP private-use ones get stripped on the way into this file.
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
  pkgs,
  osConfig,
  ...
}:
let
  # The logo the Ghostty hook below shows: the BB from the repo's own
  # wallpaper, cropped below the title at build time, its black background
  # made transparent so it sits on whatever background the theme gives
  # Ghostty. Drawn through the kitty graphics protocol, which Ghostty speaks.
  # 20x7 cells keeps the image's ~1.4:1 shape (a cell is about 1:2).
  logo = {
    image = pkgs.runCommand "fastfetch-logo.png" { nativeBuildInputs = [ pkgs.imagemagick ]; } ''
      magick ${../wallpapers/wallpaper_BB_1920x1080.jpg} \
        -crop 920x640+510+285 +repage -fuzz 5% -transparent black -resize 460x320 $out
    '';
    width = 20;
    height = 7;
  };
  dots = "${config.home.homeDirectory}/.dotfiles";
  system = "/nix/var/nix/profiles/system";
  rule = {
    type = "custom";
    format = lib.concatStrings (lib.replicate 38 "─");
    outputColor = "90";
  };
in
lib.mkIf osConfig.features.workstation {
  programs.fastfetch = {
    enable = true;
    settings = {
      logo = {
        source = "nixos_old_small";
        padding = {
          top = 2;
          left = 2;
          right = 4;
        };
      };
      display = {
        separator = "  ";
        key.width = 12;
        color = {
          keys = "blue";
          title = "bold_blue";
        };
        duration = {
          abbreviation = true;
          spaceBeforeUnit = "never";
        };
        size.ndigits = 1;
        # Without "bar" here, {percentage-bar} renders empty.
        percent.type = [
          "bar"
          "num"
        ];
        bar = {
          char = {
            elapsed = "━";
            total = "─";
          };
          border = {
            left = "";
            right = "";
          };
          width = 12;
          color = {
            elapsed = "37";
            total = "90";
          };
        };
      };
      modules = [
        "title"
        rule
        {
          type = "os";
          key = "󱄅  os";
          format = "{pretty-name}";
        }
        {
          type = "kernel";
          key = "󰌽  kernel";
          format = "{release}";
        }
        {
          type = "uptime";
          key = "󰔟  uptime";
        }
        {
          type = "packages";
          key = "󰏖  pkgs";
          format = "{nix-system} system · {nix-user} user";
        }
        rule
        {
          # The profile link's own mtime is when it was switched to; the
          # store path it points at is always dated 1970.
          type = "command";
          key = "󰑓  gen";
          text = "echo \"$(readlink ${system} | tr -dc 0-9) · $(date -d @$(stat -c %Y ${system}) '+%b %d %H:%M')\"";
        }
        {
          type = "command";
          key = "󰊢  dots";
          text = "echo \"$(git -C ${dots} log -1 --format='%h · %cr')$(git -C ${dots} diff --quiet HEAD || echo ' *')\"";
        }
        rule
        {
          type = "wm";
          key = "󰍹  wm";
          format = "{pretty-name} {version}";
        }
        {
          type = "command";
          key = "󰘚  cpu";
          text = "echo \"$(awk -F': ' '/^model name/{print $2; exit}' /proc/cpuinfo | sed -E 's/[(][^)]*[)]//g; s/ [0-9]+-Core Processor//; s/ +/ /g') ($(nproc))\"";
        }
        {
          type = "gpu";
          key = "󰢮  gpu";
          format = "{name}";
        }
        {
          type = "memory";
          key = "󰍛  mem";
          format = "{percentage-bar} {percentage}  {used} / {total}";
        }
        {
          type = "disk";
          key = "󰋊  disk";
          folders = "/:/mnt/storage";
          format = "{size-percentage-bar} {size-percentage}  {size-used} / {size-total}";
        }
        {
          type = "battery";
          key = "󰁹  bat";
          format = "{capacity-bar} {capacity}  {status}";
        }
      ];
    };
  };

  # Once per Ghostty window, with the image logo above in place of the
  # config's ASCII one — the config is also what a bare `fastfetch` uses in
  # a terminal that can't draw images (VS Code's), so its default stays text.
  # The variable is exported, so anything started from that shell (a nested
  # zsh, `nix develop`, Neovim's :terminal) inherits it and stays quiet,
  # while a new window starts from Ghostty's own environment and shows it
  # again. Not over SSH, where Ghostty's
  # ssh-env would otherwise carry TERM_PROGRAM along, and not in a window
  # too short to hold it without scrolling the prompt away. The lazygit
  # scratchpad runs no shell at all.
  programs.zsh.initContent = lib.mkOrder 1500 ''
    if [[ $TERM_PROGRAM == ghostty && -z $FASTFETCH_SHOWN && -z $SSH_CONNECTION ]] && (( LINES >= 20 && COLUMNS >= 50 )); then
      export FASTFETCH_SHOWN=1
      fastfetch --logo-type kitty-direct --logo ${logo.image} \
        --logo-width ${toString logo.width} --logo-height ${toString logo.height}
    fi
  '';
}
