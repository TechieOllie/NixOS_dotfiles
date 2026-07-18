# User half of Noctalia Shell v5 (theming, wallpaper) — the system half
# (package, Bluetooth/UPower/power-profiles wiring, Cachix substituter)
# lives in modules/desktop/noctalia.nix. Self-gates on osConfig.features.niri
# the same way home/niri.nix does.
{ lib, osConfig, noctalia, ... }:
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

        wallpaper = {
          enabled = true;
          default.path = ../wallpapers/SPACE.webp;
        };
      };
    };
  };
}
