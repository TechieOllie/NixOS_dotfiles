# Icon theme (Papirus-Dark) and GTK3 shape theme (adw-gtk3) — self-gates on
# osConfig.features.niri, same convention as home/niri.nix/home/cursor.nix.
#
# GTK4 has no theme set here on purpose: GTK4 apps already render rounded,
# libadwaita-style widgets by default, and home-manager's own gtk4 module
# notes that setting gtk.gtk4.theme is an unofficial "@import" workaround
# being deprecated per stateVersion — nothing to gain by using it. Noctalia's
# existing gtk3/gtk4 builtin_ids color templates (home/noctalia.nix) are
# untouched and layer their palette on top of adw-gtk3/libadwaita exactly as
# they already do today.
{
  pkgs,
  lib,
  osConfig,
  ...
}:
lib.mkIf osConfig.features.niri {
  gtk = {
    enable = true;

    iconTheme = {
      package = pkgs.papirus-icon-theme;
      name = "Papirus-Dark"; # confirmed real folder name via a live build
    };

    gtk3.theme = {
      package = pkgs.adw-gtk3;
      name = "adw-gtk3-dark"; # confirmed real folder name via a live build
    };
  };

  # Noctalia's official "papirus-icons" community template (see
  # home/noctalia.nix's community_ids) recolors Papirus' folder icons live,
  # tracking the wallpaper's accent color. Its own apply.sh only does this
  # in place against $HOME/.local/share/icons/Papirus, falling back to `cp -r
  # /usr/share/icons/Papirus` if that directory doesn't exist yet — a path
  # that never exists on NixOS (nothing installs there). Seeding a writable
  # copy ourselves means that check always finds the directory already
  # present, so the incompatible fallback never triggers.
  #
  # Must be a real, writable copy (not a symlink into the read-only Nix
  # store) since papirus-folders rewrites the SVGs in place. Re-seeded (and
  # therefore reset to Papirus' default blue) on every Home Manager
  # activation — accepted trade-off: folder colors go back to default after
  # every nixos-rebuild switch until Noctalia's next automatic re-theme pass
  # repaints them.
  home.activation.seedPapirusIcons = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    run rm -rf "$HOME/.local/share/icons/Papirus"
    run mkdir -p "$HOME/.local/share/icons"
    run cp -r "${pkgs.papirus-icon-theme}/share/icons/Papirus" "$HOME/.local/share/icons/Papirus"
    run chmod -R u+w "$HOME/.local/share/icons/Papirus"
  '';
}
