# User-level Starship prompt config. No system half — pure user tool,
# hence its own small file (one responsibility per module) rather than
# folded into home/zsh.nix; home/lazygit.nix gets the same treatment for
# the same reason. Zsh integration (`eval "$(starship init zsh)"`) is NOT
# hand-written here — programs.starship.enableZshIntegration defaults to
# true once both programs.zsh.enable and programs.starship.enable are
# true, and home-manager adds the eval line to .zshrc itself.
#
# The prompt is defined ONCE, as `prompt` below — a function of a colour
# set — and reaches each kind of host by a different route:
#
#   - niri hosts: Noctalia's template engine owns ~/.config/starship.toml
#     outright, re-rendering it on every wallpaper/palette change, so Home
#     Manager must not manage that path (the conflict class this repo
#     already fixed once for niri/noctalia.kdl). `prompt` is called with
#     Noctalia's {{colors.*}} placeholders as its colours, rendered to TOML
#     at build time, and registered as a custom user template — the same
#     generate-the-template-input shape as niriStyleTemplate in
#     home/noctalia.nix.
#   - every other host (inotmac, the laptop): no template pass ever runs,
#     so without Home Manager writing the file Starship silently falls back
#     to its built-in default prompt. `prompt` is called with static named
#     colours and becomes programs.starship.settings.
#
# This replaced a hand-synced pair (a checked-in .tmpl plus a static copy
# here), which had already drifted once: the port lost the Python glyph
# from both. The palettes deliberately still differ — the Noctalia copy
# tracks the wallpaper, this one needs no such machinery.
#
# Layout: line 1 is *where* you are on the left (user always, @host over SSH,
# path, git, nix shell) and *which toolchain* applies on the right, split
# by $fill; the right side of the input line is the last command's outcome
# (exit status, duration, background jobs), via right_format. Language and
# web-tooling modules are Starship's built-ins only — no `custom.*`
# modules, each of which would fork a process per prompt.
#
# Glyphs are Nerd Font codepoints from `starship preset nerd-font-symbols`,
# except Python's, which is the operator's original from shell_dotfiles.
{
  lib,
  pkgs,
  osConfig,
  ...
}:
let
  prompt = c: {
    format = lib.concatStrings [
      "[┌─ ](bold ${c.frame})"
      "($username$hostname in )"
      "$directory"
      "$git_branch$git_status$git_state"
      "$nix_shell"
      "$fill"
      "$python$rust$golang$nodejs$bun$deno$java$c$cmake$php$package"
      "$line_break"
      "[└─](bold ${c.frame})$character"
    ];
    right_format = "$status$cmd_duration$jobs";

    fill.symbol = " ";

    # Username always (`ol in …`, as the original prompt had it — without
    # it a local prompt read as too bare); hostname only over SSH, so a
    # remote shell is still unmistakable. The `@` lives in hostname's
    # format so a local shell reads `ol`, not `ol@`.
    username = {
      show_always = true;
      format = "[$user]($style)";
      style_user = "bold ${c.accent}";
    };
    hostname = {
      format = "[@$hostname]($style)";
      style = "bold ${c.accent}";
    };

    directory = {
      format = "[$path]($style)[$read_only]($read_only_style) ";
      style = "bold ${c.path}";
      read_only = " 󰌾";
      truncation_length = 8;
      truncation_symbol = "…/";
    };

    git_branch = {
      format = "[$symbol$branch(:$remote_branch)]($style) ";
      symbol = " ";
    };
    git_status.format = "([\\[$all_status$ahead_behind\\]]($style) )";

    nix_shell = {
      format = "[$symbol$state( \\($name\\))]($style) ";
      symbol = " ";
    };

    python = {
      format = "[$symbol($version )(\\($virtualenv\\) )]($style)";
      symbol = " ";
    };
    rust = {
      format = "[$symbol($version )]($style)";
      symbol = "󱘗 ";
    };
    golang = {
      format = "[$symbol($version )]($style)";
      symbol = " ";
    };
    nodejs = {
      format = "[$symbol($version )]($style)";
      symbol = " ";
    };
    bun = {
      format = "[$symbol($version )]($style)";
      symbol = " ";
    };
    deno = {
      format = "[$symbol($version )]($style)";
      symbol = " ";
    };
    java = {
      format = "[$symbol($version )]($style)";
      symbol = " ";
    };
    c = {
      format = "[$symbol($version(-$name) )]($style)";
      symbol = " ";
    };
    cmake = {
      format = "[$symbol($version )]($style)";
      symbol = " ";
    };
    php = {
      format = "[$symbol($version )]($style)";
      symbol = " ";
    };
    package = {
      format = "[$symbol$version]($style) ";
      symbol = "󰏗 ";
    };

    # Off by default in Starship; non-zero exits only.
    status = {
      disabled = false;
      # Words, not a glyph: git_status already uses ✘ for deleted files.
      format = "[exit $status]($style) ";
      style = "bold ${c.error}";
    };
    cmd_duration = {
      format = "[$duration]($style) ";
      style = c.muted;
    };
    jobs.style = "bold ${c.accent}";
  };

  # Noctalia's Material You roles, matching the frame/path pairing the
  # template used before (primary/secondary).
  noctaliaTemplate = (pkgs.formats.toml { }).generate "starship.toml.tmpl" (prompt {
    frame = "{{colors.primary.default.hex}}";
    path = "{{colors.secondary.default.hex}}";
    accent = "{{colors.tertiary.default.hex}}";
    muted = "{{colors.outline.default.hex}}";
    error = "{{colors.error.default.hex}}";
  });
in
{
  programs.starship.enable = true;

  programs.starship.settings = lib.mkIf (!osConfig.features.niri) (prompt {
    frame = "blue";
    path = "cyan";
    accent = "purple";
    muted = "bright-black";
    error = "red";
  });

  # No post_hook needed: Starship re-reads its config file on every
  # prompt, no daemon/signal to restart. Gated on the same flag as
  # home/noctalia.nix's whole config, since the option only means
  # something where Noctalia runs.
  programs.noctalia.settings.theme.templates.user.starship = lib.mkIf osConfig.features.niri {
    input_path = noctaliaTemplate;
    output_path = [ "$XDG_CONFIG_HOME/starship.toml" ];
  };
}
