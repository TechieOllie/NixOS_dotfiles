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

    # gtk.iconTheme.name below is "Papirus-Dark", not "Papirus" — but
    # papirus-folders (called by the "papirus-icons" template's apply.sh
    # above) only ever recolors the base "Papirus" theme (confirmed by
    # reading its source: -t/--theme defaults to "Papirus", and apply.sh
    # never passes -t). "Papirus-Dark" is a genuinely separate theme tree
    # (its own index.theme: Inherits=breeze-dark,hicolor, not Papirus at
    # all), so nothing above ever touched it — found live on the VM while
    # investigating an operator-reported bug ("Nautilus's folder icons
    # aren't themed").
    #
    # First fix attempt (superseded) only symlinked Papirus-Dark's
    # folder.svg — insufficient, since Nautilus (and GIO generally) doesn't
    # actually resolve a plain directory's icon via the name "folder" at
    # all; it resolves the "inode/directory" MIME type to the icon name
    # "inode-directory" instead, confirmed live (readlink -f on
    # Papirus-Dark's own inode-directory.svg resolved to the original,
    # never-recolored file — a *different* alias symlink than folder.svg,
    # missed by that first attempt). Papirus itself has ~2000 folder-related
    # icon names per size (every color × every named-folder variant, e.g.
    # folder-documents, folder-adwaita-arduino, inode-directory, user-home,
    # ...) all chained via relative symlinks that only resolve correctly
    # when colocated in the same writable directory as the recolored files
    # — individually mirroring each name into Papirus-Dark isn't practical
    # at that scale. Fixed instead by symlinking Papirus-Dark's entire
    # "places" category directory (the one holding every folder/location
    # icon — not unrelated categories like apps/status/mimetypes) straight
    # at the writable/recolorable Papirus copy's own "places" dir, at every
    # size both themes have one. Accepted trade-off: Papirus-Dark's own
    # "places" renderings (if they ever meaningfully differ from Papirus')
    # are fully superseded by Papirus' — a much smaller concern than
    # folders showing the wrong/default color. GTK's icon lookup checks
    # $HOME/.local/share/icons before the Nix-store-installed theme, so
    # this override is enough; every non-"places" Papirus-Dark icon is
    # untouched and still resolves from the Nix store as before. Verified
    # live: readlink -f on both inode-directory.svg and folder-documents.svg
    # resolved through to Papirus' current recolored files, not the
    # originals.
    for papirusDarkPlacesDir in "${pkgs.papirus-icon-theme}/share/icons/Papirus-Dark"/*/places; do
      papirusDarkSize="$(basename "$(dirname "$papirusDarkPlacesDir")")"
      recoloredPlacesDir="$HOME/.local/share/icons/Papirus/$papirusDarkSize/places"
      if [ -d "$recoloredPlacesDir" ]; then
        run mkdir -p "$HOME/.local/share/icons/Papirus-Dark/$papirusDarkSize"
        run rm -rf "$HOME/.local/share/icons/Papirus-Dark/$papirusDarkSize/places"
        run ln -sfn "$recoloredPlacesDir" "$HOME/.local/share/icons/Papirus-Dark/$papirusDarkSize/places"
      fi
    done
  '';
}
