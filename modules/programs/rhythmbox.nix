# CD ripper for the shared GNOME host.
#
# Fifth and, on current evidence, last — the ripper question got answered
# four times against criteria that each turned out not to be the binding
# one. The sequence is in docs/decisions.md; the short version is that
# "does it rip correctly" was never actually the problem after the first
# attempt, and "can the output layout be declared for four accounts" was
# the constraint nobody had named.
#
# That constraint is what picks Rhythmbox. fre:ac ripped a disc here
# flawlessly — 19/19 tracks verified against `flac -t`, fully tagged with
# ISRC and catalogue number — and it is the only option in nixpkgs with
# AccurateRip. But it keeps its output patterns in ~/.config/freac's own
# XML, which the app owns and rewrites, so on a machine with four accounts
# and Home Manager for one of them there is no way to declare the layout
# for the other three. Rhythmbox keeps the same settings in GSettings,
# which means an override package can set them for every account including
# ones that don't exist yet.
#
# Cost, stated plainly: Rhythmbox is a music *player* that also rips, so
# the rip flow is less direct than a dedicated tool's, and it has no
# AccurateRip. The trade is a slightly worse ripping UI for a layout four
# people don't each have to configure by hand.
#
# System-wide for the same reason as chrome/picard here: Home Manager
# covers one of this host's four accounts.
{
  config,
  lib,
  pkgs,
  ...
}:
lib.mkIf config.features.gnome {
  environment.systemPackages = [ pkgs.rhythmbox ];

  # CD ripping needs no plugin wrangling: `active-plugins` defaults to an
  # empty list, but the audiocd plugin is marked `Builtin=true` in its own
  # .plugin file and is therefore always loaded. Checked, because an empty
  # default list is exactly the shape that usually means "nothing is
  # enabled".
  #
  # These are dconf defaults rather than a GSettings override package,
  # which is a deliberate departure from modules/desktop/gnome.nix, and the
  # reason is org.gnome.rhythmbox.encoding-settings: it is a *relocatable*
  # schema, declaring no path of its own, and **a .gschema.override cannot
  # target one at all**. Neither header form works — a bare
  # [org.gnome.rhythmbox.encoding-settings] names nothing, and the
  # [schema:path] form that `gsettings` itself accepts is not understood by
  # glib-compile-schemas in an override file. Both compile clean and both
  # emit no warning whatsoever; the FLAC default simply stays Vorbis.
  # Confirmed by building the override and querying the compiled schema,
  # then reading the build log for a warning that never came.
  #
  # dconf has no such limit because it keys on *paths*, not schemas, so the
  # encoding child sits at a plain path like any other. The path is where
  # rb-library-source.c instantiates it —
  # g_settings_get_child(settings, "encoding") against
  # org.gnome.rhythmbox.library, whose own path is /org/gnome/rhythmbox/
  # library/ — read from both the schema's <child> element and the call
  # site rather than guessed.
  #
  # Defaults, not locks: enableUserDb defaults true, so `user-db:user` sits
  # ahead of this in the profile and anything a person changes in the app
  # still wins. That is the same reach favoriteAppsOverride has and the
  # same reason it is used — three of this host's four accounts have no
  # Home Manager profile.
  programs.dconf.profiles.user.databases = [
    {
      settings = {
        # %aa album artist, %at album title, %ay album year,
        # %tN track number zero-padded, %tt track title. Every one of
        # these was read out of filepath_parse_pattern() in
        # rb-library-source.c — Rhythmbox's own UI only offers a fixed
        # dropdown of preset layouts with no year among them, so the
        # legend is not discoverable from the app.
        #
        # Known rough edge: %ay renders a missing year as "0", giving
        # "Album (0)". Rhythmbox has no conditional syntax, so a disc
        # whose lookup returns no date needs the year filled in before
        # ripping, or fixing afterwards in Picard.
        "org/gnome/rhythmbox/library" = {
          layout-path = "%aa/%at (%ay)";
          layout-filename = "%tN - %tt";
        };
        "org/gnome/rhythmbox/library/encoding" = {
          media-type = "audio/x-flac";
        };
      };
    }
  ];
}
