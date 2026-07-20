# User half of Noctalia Shell v5 (theming, wallpaper) — the system half
# (package, Bluetooth/UPower/power-profiles wiring, Cachix substituter)
# lives in modules/desktop/noctalia.nix. Self-gates on osConfig.features.niri
# the same way home/niri.nix does.
{ lib, osConfig, vars, noctalia, ... }:
{
  imports = [ noctalia.homeModules.default ];

  config = lib.mkIf osConfig.features.niri {
    programs.noctalia = {
      enable = true;
      # Supervised (restart-on-failure, journalctl logging) rather than a
      # niri spawn-at-startup line — paired with launch_apps_as_systemd_services
      # below, per upstream's own recommendation for this combination.
      systemd.enable = true;

      settings = {
        shell = {
          launch_apps_as_systemd_services = true;
        };

        theme = {
          mode = "dark";
          source = "wallpaper";
          wallpaper_scheme = "m3-content";

          templates = {
            # Resolves the earlier "undocumented anywhere upstream" TODO —
            # confirmed by reading assets/templates/builtin.toml directly
            # in the noctalia flake input's source (the [catalog.*]
            # entries are the real builtin_ids). "ghostty" keeps
            # ~/.config/ghostty/themes/noctalia in sync with the
            # wallpaper (see home/ghostty.nix); "gtk3"/"gtk4"/"qt" close
            # the GTK/Qt theming gap open since Phase 3. Deliberately NOT
            # "starship" here — its official template live-edits
            # ~/.config/starship.toml directly (sed-inserting a palette
            # line + marked block); replaced by our own custom user
            # template below instead, which avoids that conflict by
            # design (see templates.user.starship).
            builtin_ids = [
              "ghostty"
              "gtk3"
              "gtk4"
              "qt"
            ];

            # "neovim" fetched from the separate community catalog
            # (github:noctalia-dev/community-templates), not
            # builtin_ids — writes ~/.config/nvim/lua/matugen.lua at
            # runtime (nvim-base16 sub-template), which is exactly the
            # mechanism the operator's own neovim_dotfiles config already
            # uses (confirmed: same output filename, same
            # RRethy/base16-nvim plugin already in their lazy-lock.json).
            # Deliberately NOT "lazygit" — its community template
            # rewrites ~/.config/lazygit/config.yml directly via `mv`,
            # conflicting with the Nix-managed home/lazygit.nix from
            # Phase 4 the same way starship's builtin template would;
            # replaced by our own custom user template below instead.
            #
            # "yazi" only — not a separate "yazi-syntax" entry too.
            # Confirmed by reading template_apply_service.cpp directly:
            # communityIds entries key a *cached catalog directory*
            # (community-templates' own yazi/template.toml), fetched and
            # then fully processed as one file — and that one file
            # happens to define both [templates.yazi] (flavor colors) and
            # [templates.yazi-syntax] (tmTheme), both applied together
            # once "yazi" is cached. "yazi-syntax" isn't its own
            # fetchable catalog entry; listing it separately would just
            # produce a "not cached yet" warning, the same one seen
            # earlier for "lazygit" before that was dropped in favor of
            # the custom template. Both outputs land in a clean, separate
            # directory (~/.config/yazi/flavors/noctalia.yazi/) — no
            # conflict, since home/yazi.nix doesn't manage any yazi config
            # with Nix at all.
            # "papirus-icons" (Theming phase): recolors Papirus' folder
            # icons to the nearest papirus-folders preset for the current
            # wallpaper accent (HSV-nearest match against
            # colors.source_color, confirmed by reading the template's own
            # apply.sh). Its fallback `cp -r /usr/share/icons/Papirus` path
            # doesn't exist on NixOS — home/gtk.nix seeds a writable
            # $HOME/.local/share/icons/Papirus copy itself so that check
            # always finds the directory already present and this fallback
            # never triggers.
            community_ids = [
              "neovim"
              "yazi"
              "papirus-icons"
            ];

            # Custom templates, written and checked into this repo
            # (home/noctalia-templates/), for the two cases where the
            # official (builtin/community) template would conflict with
            # a file Home Manager already manages. Since we control
            # input_path/output_path/post_hook completely here — unlike
            # the official templates, which must stay compatible with an
            # arbitrary pre-existing user file via in-place sed/mv edits
            # — these render their *entire* output file fresh each time,
            # the same way ghostty/gtk/qt/niri's own templates already
            # behave, sidestepping the conflict entirely rather than
            # working around it.
            user = {
              starship = {
                input_path = ./noctalia-templates/starship.toml.tmpl;
                # No post_hook needed: Starship re-reads its config file
                # on every new prompt render, no daemon/signal to
                # restart. home/starship.nix deliberately has no
                # `settings` — this template is the sole owner of the
                # whole file.
                output_path = [ "$XDG_CONFIG_HOME/starship.toml" ];
              };

              lazygit = {
                input_path = ./noctalia-templates/lazygit-theme.yml.tmpl;
                # Deliberately a SEPARATE file from home/lazygit.nix's
                # Nix-managed config.yml (nerdFontsVersion,
                # notARepository) — merged at invocation time via
                # LG_CONFIG_FILE (see home/lazygit.nix's
                # home.sessionVariables), not by overwriting config.yml.
                # Keeps the already-completed Phase 4 home/lazygit.nix
                # completely untouched.
                output_path = [ "$XDG_CONFIG_HOME/lazygit/themes/noctalia.yml" ];
              };
            };
          };
        };

        # Deliberately no default.path/enabled here — confirmed live that
        # Noctalia only ever reads the *active* wallpaper from its own
        # ~/.local/state/noctalia/settings.toml (set via `noctalia msg
        # wallpaper-set` or its own UI), never from config.toml. Setting a
        # default here would either do nothing, or (via an autostart
        # workaround) permanently re-pin the wallpaper on every login,
        # overwriting any choice made through Noctalia's own UI. Instead,
        # just point the picker at this repo's wallpapers/ directory.
        #
        # Deliberately a plain string, NOT a Nix path (e.g. ../wallpapers) —
        # a path literal gets copied into the Nix store as its own
        # derivation output the moment it's stringified, doubling storage
        # (repo checkout + store copy) and requiring a full rebuild+switch
        # just to pick up a newly added wallpaper file. Pointing at the
        # repo's own on-disk clone instead means: one copy of the files,
        # and dropping a new wallpaper in just works with no rebuild.
        # Requires this repo to be cloned to ~/.dotfiles on every host that
        # uses this module — see docs/live-dotfiles.md.
        wallpaper.directory = "/home/${vars.user.name}/.dotfiles/wallpapers";
      };
    };
  };
}
