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

          # Resolves the earlier "undocumented anywhere upstream" TODO —
          # confirmed by reading assets/templates/builtin.toml directly in
          # the noctalia flake input's source (the [catalog.*] entries are
          # the real builtin_ids). "ghostty" keeps
          # ~/.config/ghostty/themes/noctalia in sync with the wallpaper
          # (see home/ghostty.nix); "gtk3"/"gtk4"/"qt" close the GTK/Qt
          # theming gap open since Phase 3. Deliberately NOT including
          # "starship" — its template live-edits ~/.config/starship.toml
          # itself (sed-inserting a palette line + marked block), which
          # would conflict with programs.starship.settings' Nix-managed
          # store symlink the same way niri/noctalia.kdl once did; left
          # for its own separate session.
          templates.builtin_ids = [
            "ghostty"
            "gtk3"
            "gtk4"
            "qt"
          ];
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
