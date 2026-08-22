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

    # The shared UI font. modules/system/fonts.nix's fontconfig sansSerif
    # default would already resolve GTK's own "Sans 10" default to this
    # family, so this is belt-and-braces on the *family* — but not on the
    # size: GTK's default is 10, and 11 is what actually matches the visual
    # weight of Noctalia's bar next to a Nautilus window. Set here rather than
    # in fonts.nix because it's a Home Manager toolkit setting with no
    # system-level equivalent, and because the greeter (which fonts.nix does
    # have to cover) has no GTK surface of its own.
    #
    # Qt deliberately has no counterpart in home/qt.nix — see the note in
    # modules/system/fonts.nix on qt5ct/qt6ct storing fonts as a serialized
    # QFont blob that can't be written as INI.
    font = {
      package = pkgs.adwaita-fonts;
      name = "Adwaita Sans";
      size = 11;
    };

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
  # store) since papirus-folders rewrites the SVGs in place. Re-seeded on
  # every Home Manager activation, which resets the folders to Papirus'
  # default blue — so the re-seed is immediately followed by re-running the
  # template's own apply.sh (see the note at the end of this script), which
  # repaints them from the color Noctalia last computed.
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

    # Re-apply the wallpaper-derived folder color that the re-seed above just
    # wiped. Noctalia only runs a template when the theme actually changes,
    # so on its own the seed leaves folders default-blue from one
    # `nixos-rebuild switch` until the next wallpaper change — which is what
    # the operator saw as "Nautilus folders aren't themed" (found live on the
    # desktop 2026-08-22: every places icon resolved to folder-blue.svg while
    # the template's own cached state said bluegrey).
    #
    # The template's apply.sh is reused rather than calling papirus-folders
    # directly, so the accent-to-Papirus-color mapping stays defined in
    # exactly one place — Noctalia's. It reads `colors-final` (written by
    # Noctalia on each theme pass) and is a no-op exiting 0 when that file
    # doesn't exist yet, so this is safe on a host where Noctalia has never
    # run. Best-effort by design: a failure here must not fail activation, so
    # it is `|| true`. Run through an explicit PATH because activation's own
    # is minimal — apply.sh needs awk, and papirus-folders needs find/sed and
    # `getent passwd` (to locate the home directory; without it the whole run
    # dies with `Error: Failed to apply papirus-folders`, found by simulating
    # this script live rather than by eval). gtk3 is for gtk-update-icon-cache,
    # whose absence is only a warning but a noisy one.
    papirusApply="$HOME/.local/state/noctalia/community-templates/papirus-icons/apply.sh"
    if [ -x "$papirusApply" ]; then
      run env PATH="${
        lib.makeBinPath [
          pkgs.bash
          pkgs.coreutils
          pkgs.findutils
          pkgs.gawk
          pkgs.getent
          pkgs.gnused
          pkgs.gtk3
        ]
      }" ${lib.getExe pkgs.bash} "$papirusApply" || true
    fi
  '';
}
