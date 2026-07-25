# Package only. The operator's real Feishin config (currently a Flatpak
# install, ~/.var/app/org.jeffvli.feishin) has a "server" key in its
# config.json holding actual Jellyfin/Navidrome/Subsonic connection
# details — almost certainly including a token or password. Deliberately
# not read further or ported: this is exactly the kind of real credential
# this repo never commits, matching the standing secrets discipline
# elsewhere (sops-nix for anything that must be declared at all). The
# operator sets this up once via Feishin's own UI after first launch,
# same as Zen Browser's profile-side setup.
#
# Theming: Noctalia's official "feishin" community template writes a
# separate $XDG_CONFIG_HOME/feishin/custom.css — confirmed already active
# on the operator's real (Flatpak) install (a matugen-template.css/
# custom.css pair already present there) — added to home/noctalia.nix's
# community_ids. No conflict: nothing here manages that file.
#
# Self-gates on osConfig.features.niri, same convention as home/vscode.nix.
{
  pkgs,
  lib,
  osConfig,
  ...
}:
lib.mkIf osConfig.features.niri {
  home.packages = [ pkgs.feishin ];
}
