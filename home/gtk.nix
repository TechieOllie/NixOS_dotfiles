# Icon theme (Papirus-Dark) and GTK3 shape theme (adw-gtk3) — self-gates on
# osConfig.features.desktop, same convention as home/niri.nix/home/cursor.nix.
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
lib.mkIf osConfig.features.desktop {
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
  # tracking the wallpaper's accent color. Its apply.sh runs papirus-folders
  # once per variant — Papirus, Papirus-Dark and Papirus-Light — against a
  # writable copy in $HOME/.local/share/icons, copying a variant there first
  # only if that directory doesn't exist yet. papirus-folders picks the first
  # directory holding the variant's index.theme, so a copy here wins over the
  # read-only one in the Nix store.
  #
  # All three are seeded here rather than left to that copy step, for two
  # reasons. The template copies once and never again, so its copy would go
  # stale across papirus-icon-theme bumps; this one is redone on every
  # activation. And a variant whose home directory exists but is not a full
  # theme makes papirus-folders fall through to the store copy, which it
  # can only change as root — so it execs `sudo`, which on theseus waits on
  # the fingerprint reader until it times out, on every theme pass. That is
  # what the previous shape did to Papirus-Dark: it symlinked only its
  # `places` directories at the recolored Papirus ones (from when the
  # template recolored the base theme alone), leaving a directory with no
  # index.theme. Found 2026-10-22 from `pam_unix(sudo:auth)` failures in
  # `journalctl --user -u noctalia`.
  #
  # Each variant is small apart from Papirus itself (~6-8 MB against
  # ~108 MB): most of their size directories are relative symlinks into
  # ../Papirus, which resolve to the writable copy beside them. Copies,
  # not symlinks into the store, since papirus-folders relinks folder icons
  # in place. Re-seeding resets every folder to Papirus' default blue, so it
  # is immediately followed by re-running the template's own apply.sh (see
  # the note at the end of this script), which repaints them from the color
  # Noctalia last computed.
  home.activation.seedPapirusIcons = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    run mkdir -p "$HOME/.local/share/icons"
    for papirusVariant in Papirus Papirus-Dark Papirus-Light; do
      run rm -rf "$HOME/.local/share/icons/$papirusVariant"
      run cp -r "${pkgs.papirus-icon-theme}/share/icons/$papirusVariant" "$HOME/.local/share/icons/$papirusVariant"
      run chmod -R u+w "$HOME/.local/share/icons/$papirusVariant"
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

  # The same apply.sh also runs from Noctalia itself on every theme pass, and
  # there it gets Noctalia's PATH (the per-user profile), not the explicit one
  # above. Without gtk-update-icon-cache on it, papirus-folders deletes the
  # recoloured theme's icon cache and can't rebuild it (`command not found` in
  # `journalctl --user -u noctalia`), so GTK apps scan the theme directories
  # instead of reading the cache. Only that one binary is linked, not all of
  # gtk3's bin/ (gtk3-demo, gtk-builder-tool, ...); nixpkgs has no standalone
  # package for it.
  home.packages = [
    (pkgs.runCommand "gtk-update-icon-cache" { } ''
      mkdir -p $out/bin
      ln -s ${pkgs.gtk3}/bin/gtk-update-icon-cache $out/bin/
    '')
  ];
}
