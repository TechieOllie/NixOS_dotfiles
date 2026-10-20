# Bitwarden desktop — the user half: autostart and the browser bridge. The
# polkit action that lets it accept a fingerprint is system-side, in
# modules/programs/bitwarden.nix.
#
# The browser extension (home/zen-browser.nix) can't unlock with biometrics
# by itself: it hands the request to this app over native messaging, so the
# app has to be running. It starts with the session, and on Umbriel its
# window is caught by the "bitwarden" scratchpad (home/umbriel/cfg/
# scratchpad.toml), stored hidden and summoned with Mod+X.
#
# Native messaging: deliberately NOT programs.zen-browser.nativeMessagingHosts.
# On every start the app writes its own manifest to
# ~/.mozilla/native-messaging-hosts/com.8bit.bitwarden.json and copies
# desktop_proxy next to it (main.ts → generateManifests), so the manifest
# never points at a stale store path. The Zen wrapper's option would instead
# force-symlink a store-path manifest over that same file on every browser
# launch, and the app's next write would follow the symlink into the store,
# fail, and abort its native-messaging setup — listener included. Zen reads
# user manifests from ~/.mozilla even though its profile lives in
# ~/.config/zen (its XREUserNativeManifests, read out of the running
# browser), and creating ~/.mozilla doesn't move the profile root.
#
# What the app needs from us is only that ~/.mozilla exists: it skips any
# browser whose directory is missing ("Firefox not found, skipping"), and
# nothing else on these hosts creates it. `d` never touches the directory
# once it exists.
#
# Settings that stay in the app (account-side state, no config file to own):
# "Unlock with system authentication" and "Allow browser integration" in the
# desktop app, then "Unlock with biometrics" in the extension.
#
# Self-gates on osConfig.features.desktop, same convention as home/vscode.nix.
{
  lib,
  osConfig,
  pkgs,
  ...
}:
lib.mkIf osConfig.features.desktop {
  home.packages = [ pkgs.bitwarden-desktop ];

  systemd.user.tmpfiles.rules = [ "d %h/.mozilla 0700 - - -" ];

  systemd.user.services.bitwarden = {
    Unit = {
      Description = "Bitwarden";
      After = [ "graphical-session.target" ];
      PartOf = [ "graphical-session.target" ];
    };
    Service = {
      ExecStart = "${pkgs.bitwarden-desktop}/bin/bitwarden";
      Restart = "on-failure";
    };
    Install.WantedBy = [ "graphical-session.target" ];
  };
}
