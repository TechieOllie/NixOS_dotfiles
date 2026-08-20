# Zen Browser isn't in nixpkgs at all (confirmed via nix eval against this
# repo's pinned nixpkgs) — packaged via the community zen-browser flake
# input instead (see flake.nix/lib/mkHost.nix). Channel: `beta`, Zen's own
# versioned release channel. It was briefly on `twilight-official` (the
# nightly), which is a *rolling* source: upstream replaces the tarball behind
# an already-locked revision every few days, so the fixed-output source
# derivation starts failing with a hash mismatch on whatever commit happens
# to be pushed next, unrelated to what that commit changed. That cost a
# scheduled CI job whose only purpose was to bump this one input daily.
# `beta` publishes immutable per-release artifacts, so a locked revision
# stays buildable and the lock only moves when the operator moves it.
#
# Extensions ARE ported (policies.ExtensionSettings, below), mirroring the
# set actually installed on the operator's daily-driver CachyOS laptop.
# Everything else in the real profile — bookmarks, logins, history,
# workspaces, pinned tabs — is *not*, and deliberately: that machine is
# signed into Firefox Sync (an account-side concern, and one that carries
# credentials Nix has no business holding), which already replicates all of
# it to a new install. So Nix seeds the browser; Sync seeds the profile.
# Zen's own theming (userChrome.css/userContent.css)
# is handled by Noctalia's "zen-browser" community template instead (see
# home/noctalia.nix) — it mutates that same mutable profile state directly,
# so there's nothing for Nix to conflict with here either.
#
# No desktop-entry override here, unlike home/vesktop.nix. This channel's
# own packaged entry (share/applications/zen-beta.desktop) is internally
# consistent — Icon=zen-browser, and the package really does ship
# zen-browser.png at every hicolor size (verified against the built store
# path). That was *not* true of twilight-official, whose entry pointed at a
# zen-twilight-official icon the package never shipped and which therefore
# needed a hiPrio xdg.desktopEntries copy to correct; that override is gone
# with the channel. If the channel ever changes again, re-check the built
# package's own .desktop and icon names before assuming they line up.
#
# Self-gates on osConfig.features.niri, same convention as home/vscode.nix.
#
# Transparent Zen mod opacity: the mod itself (installed manually via Zen's
# own Mods UI, not Nix-managed — see below) makes the webpage backplate
# fully see-through with no tint at all; there's no built-in "how much"
# slider for that. To match the rest of this repo's transparent surfaces
# (Ghostty, Noctalia's bar — both driven by the shared opacity value in
# transparency.nix), we give it a custom semi-transparent background color
# instead via its own mod.sameerasw.zen_bg_color_enabled/zen_transparency_color
# prefs (confirmed real via the mod's own preferences.json, mod UUID
# 642854b5-88b4-4c40-b256-e035532109df, github:sameerasw/zen-themes).
#
# policies.Preferences silently drops any pref outside Firefox's own prefix
# allowlist. Read straight out of the shipped browser
# (browser/omni.ja -> modules/policies/Policies.sys.mjs, `Preferences:
# onBeforeAddons`, Zen 1.21.10b): the allowed prefixes are accessibility.,
# alerts., app.update., browser., datareporting.policy., devtools., dom.,
# extensions., general.autoScroll, general.smoothScroll, geo., gfx.,
# identity.fxaccounts.toolbar., intl., keyword.enabled, layers., layout.,
# mathml.disabled, media., network., pdfjs., places., pref., print., four
# specific privacy.* prefs, sidebar., signon., spellchecker., two svg.*,
# toolkit.legacyUserProfileCustomizations.stylesheets, ui., two webgl.*,
# widget., and some xpinstall.*; security.* is an exact-match allow-list of
# its own. Anything else is rejected with an `Unable to set preference X.
# Preference not allowed for stability reasons.` line in the browser console
# and nothing else — no eval error, no visible failure.
#
# `zen.*` and `mod.*` are NOT on that list. Zen inherits the upstream
# allowlist unchanged and does not add its own namespace to it. So the
# transparency prefs below in those two namespaces are inert, and every
# genuinely Zen-specific UI setting on the operator's laptop
# (zen.view.compact.enable-at-startup, zen.view.use-single-toolbar,
# zen.glance.activation-method, zen.tabs.ctrl-tab.ignore-essential-tabs,
# zen.pinned-tab-manager.restore-pinned-tabs-to-pinned-url,
# zen.swipe.is-fast-swipe, zen.workspaces.continue-where-left-off) is
# unreachable from here. Reaching them needs profiles.<name>.settings, i.e.
# handing the profile directory to Home Manager — the exact thing the next
# paragraph explains this repo does not do. They are left to the browser's
# own settings UI (and to Sync, which carries some of them) rather than
# quietly declared in a place that cannot apply them. The transparency prefs
# are kept in those inert namespaces anyway, so that turning transparency
# back on doesn't silently lose the intent.
#
# Set via policies.Preferences (policies.json), not profiles.<name>.settings
# (prefs.js) — deliberately, not just following the flake's own examples:
# profiles.*.settings requires declaring a profiles.<name> entry, which
# hands the whole profile directory over to Home Manager to manage/create.
# This repo has never done that for Zen (see the "no extension/policy
# porting" comment above), and the VM already has a real ad hoc profile
# from earlier live testing with its own session state — there's no
# guarantee a Nix-declared "default" profile lines up with whatever that
# one is actually called on disk, risking Home Manager creating and
# switching to a second, empty profile instead. policies.Preferences is
# stock home-manager Firefox `policies` (confirmed by reading
# mkFirefoxModule.nix directly): applied at package-wrap time, fully
# independent of any profiles.* declaration, so it reaches whichever
# profile is actually in use with no such risk. Status = "default" (not
# "locked") throughout: seeds the starting value but leaves it a normal,
# user-editable pref afterward, so Transparent Zen's own settings panel
# still works normally for live tweaking.
{
  lib,
  osConfig,
  zen-browser,
  ...
}:
let
  opacity = import ./transparency.nix;

  # Every transparency-related pref below is derived from the shared value
  # rather than hardcoded, so turning transparency off (opacity = 1.0) flips
  # them all together and turning it back on restores them — no second place
  # to remember. With this false, Zen renders its normal, fully-themed chrome
  # (Noctalia's "zen-browser" community template still colors it), instead of
  # the opaque-black backplate that `zen_bg_color_enabled` would otherwise
  # force at #000000FF.
  transparent = opacity < 1.0;

  # Every pref below is seeded, never locked: Status = "default" sets the
  # starting value and then leaves it an ordinary user-editable pref, so the
  # browser's own settings UI keeps working. Same choice as the transparency
  # prefs, which predate this helper.
  seed = Value: {
    inherit Value;
    Status = "default";
  };
in
{
  imports = [ zen-browser.homeModules.beta ];

  config = lib.mkIf osConfig.features.niri {
    programs.zen-browser = {
      enable = true;
      setAsDefaultBrowser = true;

      policies.Preferences = {
        "browser.tabs.allow_transparent_browser" = {
          Value = transparent;
          Status = "default";
        };
        "zen.widget.linux.transparency" = {
          Value = transparent;
          Status = "default";
        };
        "mod.sameerasw.zen_bg_color_enabled" = {
          Value = transparent;
          Status = "default";
        };
        "mod.sameerasw.zen_transparency_color" = {
          # Plain black, matching this repo's globally dark theming (Noctalia
          # theme.mode = "dark", GTK/Papirus dark variants). 8-digit hex
          # (#RRGGBBAA), NOT CSS rgba()/percentage syntax — confirmed via
          # live devtools inspection that the mod's preference-to-CSS-variable
          # binding silently zeroes out anything that isn't hex (its own
          # default value is "#00000000", the same format), so an rgba()
          # string was accepted as a valid pref value but never actually
          # reached the element it themes.
          Value = "#000000${lib.fixedWidthString 2 "0" (lib.toHexString (builtins.floor (opacity * 255)))}";
          Status = "default";
        };
        "mod.sameerasw.zen_no_shadow" = {
          # The mod's own multi-layer box-shadow around the webpage view
          # (chrome.css) is meant to blend invisibly against an opaque
          # white page — with a transparent backplate it shows up instead
          # as a stray rim just inside niri's own border. Confirmed via
          # live testing. Only relevant while the backplate is actually
          # transparent, so it follows the same shared value.
          Value = transparent;
          Status = "default";
        };

        # --- Ported from the operator's live CachyOS profile ---------------
        # Read out of ~/.config/zen/<profile>/prefs.js on
        # the-entertaining-caos-laptop and filtered down to prefs that are
        # (a) a deliberate choice rather than browser-written state, (b) not
        # machine-local (download.lastDir, backup.location and friends are
        # dropped — they name paths that need not exist on a NixOS host), and
        # (c) inside the policy allowlist documented above.

        # Tab and window behaviour.
        "browser.ctrlTab.sortByRecentlyUsed" = seed true;
        "general.autoScroll" = seed true;
        "accessibility.typeaheadfind.flashBar" = seed 0;

        # Ask where to put every download rather than dropping it in
        # ~/Downloads, and clear private-window downloads on close.
        "browser.download.useDownloadDir" = seed false;
        "browser.download.deletePrivate" = seed true;

        # New tab: no second search box (the URL bar is the search box), no
        # sponsored content, stories kept. showSponsoredTopSites is left
        # alone on purpose — it is still at its default on the laptop, so
        # there is no operator choice here to reproduce.
        "browser.newtabpage.activity-stream.showSearch" = seed false;
        "browser.newtabpage.activity-stream.showSponsored" = seed false;
        "browser.newtabpage.activity-stream.feeds.section.topstories" = seed true;

        # URL bar: history/bookmarks before search suggestions, and no
        # "search with <engine>" rows.
        "browser.search.suggest.enabled" = seed true;
        "browser.urlbar.showSearchSuggestionsFirst" = seed false;
        "browser.urlbar.suggest.engines" = seed false;

        # Translation is off entirely on the laptop, including the built-in
        # AI translation feature that would otherwise re-offer it.
        "browser.translations.enable" = seed false;
        "browser.translations.automaticallyPopup" = seed false;
        "browser.ai.control.translations" = seed "blocked";

        # Passwords and form data belong to Bitwarden (installed below), not
        # to the browser — so its own password manager is switched off rather
        # than left to compete for the same save prompts.
        "signon.rememberSignons" = seed false;
        "signon.management.page.breach-alerts.enabled" = seed false;
        "extensions.formautofill.addresses.enabled" = seed false;
        "extensions.formautofill.creditCards.enabled" = seed false;

        # No speculative connections or prefetching.
        "network.prefetch-next" = seed false;
        "network.http.speculative-parallel-limit" = seed 0;

        # Picture-in-picture: follow the video across tab switches, no
        # subtitle toggle overlay.
        "media.videocontrols.picture-in-picture.enable-when-switching-tabs.enabled" = seed true;
        "media.videocontrols.picture-in-picture.display-text-tracks.toggle.enabled" = seed false;
        "extensions.pictureinpicture.enable_picture_in_picture_overrides" = seed true;

        # UK English UI, French second, and dates/units from the OS locale.
        # The French language pack is force-installed below; en-GB and en-US
        # ship in the build.
        "intl.locale.requested" = seed "en-GB,fr,en-US";
        "intl.regional_prefs.use_os_locales" = seed true;

        # Zen's own sidebar replaces the Firefox one.
        "sidebar.visibility" = seed "hide-sidebar";

        # Required for chrome/userChrome.css to be read at all — which is
        # how both Noctalia's "zen-browser" template and any Zen mod apply
        # themselves. Set on the laptop, and easy to lose on a fresh profile.
        "toolkit.legacyUserProfileCustomizations.stylesheets" = seed true;
      };

      # The extension set actually installed and enabled on the laptop,
      # by add-on ID. `normal_installed` rather than `force_installed`:
      # it installs the extension on first run and keeps it updated, but
      # leaves the operator able to disable or remove one from about:addons
      # — the same seed-don't-lock stance as Status = "default" above.
      # Pinned to AMO's /latest/ redirect rather than a versioned file URL,
      # so this doesn't need a bump every time an extension updates; the
      # cost is that the exact version installed isn't reproducible, which
      # is already true of everything else in a browser profile.
      #
      # Deliberately absent: the two disabled themes (DarkMagic, Matte
      # Black) and Conex, all three inactive on the laptop.
      policies.ExtensionSettings = {
        # uBlock Origin.
        "uBlock0@raymondhill.net" = {
          install_url = "https://addons.mozilla.org/firefox/downloads/latest/ublock-origin/latest.xpi";
          installation_mode = "normal_installed";
        };
        # Dark Reader.
        "addon@darkreader.org" = {
          install_url = "https://addons.mozilla.org/firefox/downloads/latest/darkreader/latest.xpi";
          installation_mode = "normal_installed";
        };
        # Bitwarden Password Manager — the reason signon.rememberSignons is
        # false above.
        "{446900e4-71c2-419f-a6a7-df9c091e268b}" = {
          install_url = "https://addons.mozilla.org/firefox/downloads/latest/bitwarden-password-manager/latest.xpi";
          installation_mode = "normal_installed";
        };
        # Obsidian Web Clipper — pairs with home/obsidian.nix.
        "clipper@obsidian.md" = {
          install_url = "https://addons.mozilla.org/firefox/downloads/latest/web-clipper-obsidian/latest.xpi";
          installation_mode = "normal_installed";
        };
        # Chrome Mask — presents a Chrome user agent to sites that refuse
        # anything else.
        "chrome-mask@overengineer.dev" = {
          install_url = "https://addons.mozilla.org/firefox/downloads/latest/chrome-mask/latest.xpi";
          installation_mode = "normal_installed";
        };
        # French language pack, for intl.locale.requested's "fr" fallback.
        "langpack-fr@firefox.mozilla.org" = {
          install_url = "https://addons.mozilla.org/firefox/downloads/latest/francais-language-pack/latest.xpi";
          installation_mode = "normal_installed";
        };
      };
    };

    # No BROWSER override needed on this channel. setAsDefaultBrowser = true
    # routes through the flake's own hm-module/default-browser.nix, which
    # derives everything from the *flake attribute* name — `BROWSER =
    # "zen-${name}"`, plus mime associations pointing at `zen-${name}.desktop`.
    # On `beta` the attribute and the package agree (bin/zen-beta,
    # share/applications/zen-beta.desktop), so upstream's own values are
    # already correct; the mkForce that corrected them under
    # `twilight-official` is gone with the channel.
    #
    # The mime half of that only reaches disk because home/xdg-mime-apps.nix
    # sets xdg.mimeApps.enable — upstream populates defaultApplications but
    # never enables the module, and home-manager writes no mimeapps.list
    # without it. Don't drop that module assuming this one is self-contained.
  };
}
