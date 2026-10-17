# System half of Umbriel, features.desktop's other compositor (the
# alternative to niri.nix). Package, Wayland session entry, the
# umbriel.service user unit and xdg-desktop-portal-umbriel all come from
# upstream's own module; user config lives in home/umbriel.nix. What every
# compositor needs (NIXOS_OZONE_WL, the keyring daemon, wl-clipboard) is in
# session.nix, and greetd.nix picks the `umbriel` session from the flag.
#
# No XWayland wiring here, unlike niri.nix: Umbriel's package wraps plain
# Xwayland onto the compositor's own PATH and starts it itself
# (general.xwayland defaults true), so Steam's X11-only client has a DISPLAY
# without xwayland-satellite.
{
  config,
  lib,
  umbriel,
  ...
}:
{
  # Imported unconditionally, like greetd.nix's noctalia-greeter module, so
  # only the hosts that import this file carry the input at all.
  imports = [ umbriel.nixosModules.default ];

  config = lib.mkIf config.features.umbriel {
    programs.umbriel.enable = true;

    # Upstream routes every portal interface to its own portal, then GTK's.
    # programs.niri additionally sends Secret to gnome-keyring, and nothing
    # here would otherwise: an app asking the Secret portal for a key (a
    # Flatpak, or anything libsecret-over-portal) would get no answer. The
    # keyring daemon itself is enabled in session.nix.
    xdg.portal.config.umbriel."org.freedesktop.impl.portal.Secret" = "gnome-keyring";

    # Substitute prebuilt Umbriel instead of building a wlroots/SceneFX
    # compositor from source — the reason flake.nix's umbriel input
    # deliberately doesn't follow this repo's nixpkgs. Same shape as
    # noctalia.nix's block.
    nix.settings = {
      substituters = [ "https://umbriel.cachix.org" ];
      trusted-public-keys = [
        "umbriel.cachix.org-1:JfNq/2yg2S6D6z4Z2dVSZrZlDPQTKtexB6GAVLD98nw="
      ];
    };
  };
}
