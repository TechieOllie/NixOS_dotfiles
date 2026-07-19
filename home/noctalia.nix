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
          # TODO: builtin_ids for GTK/Qt app-theming templates aren't
          # documented as literal strings anywhere upstream — run
          # `noctalia theme --list-templates` once Noctalia is actually
          # built/running to find them, then fill in
          # theme.templates.builtin_ids here.
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
        # uses this module — see docs/wallpapers.md.
        wallpaper.directory = "/home/${vars.user.name}/.dotfiles/wallpapers";
      };
    };
  };
}
