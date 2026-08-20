# Prism Launcher — Minecraft instance manager (the maintained MultiMC
# fork). Rides features.gaming alongside home/heroic.nix rather than taking
# a flag of its own: same capability (this machine plays games), same purely
# user-level shape — no service, no system integration.
#
# Package only. Accounts, instances and per-instance mod sets live under
# ~/.local/share/PrismLauncher, written by the launcher itself and including
# a Microsoft account token; none of it is a declarative preference, and the
# token is exactly the kind of credential this repo keeps out of the store
# (same reasoning as home/feishin.nix's server config).
#
# No host-level Java: nixpkgs' wrapper already puts the JDKs the launcher
# needs on its own path, including a legacy one for old Minecraft versions.
{
  pkgs,
  lib,
  osConfig,
  ...
}:
lib.mkIf osConfig.features.gaming {
  home.packages = [ pkgs.prismlauncher ];
}
