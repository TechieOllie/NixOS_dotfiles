# Bitwarden desktop — the system half: its polkit action. The app itself,
# its autostart and the browser bridge are home/bitwarden.nix.
#
# The desktop app is what makes "unlock with biometrics" work in the browser
# extension: the extension asks the running app over native messaging, and
# the app checks the user through polkit action com.bitwarden.Bitwarden.unlock
# — which, on a host with fprintd, accepts a fingerprint. nixpkgs ships that
# action in the package's share/polkit-1/actions (and patches out the app's
# own "set up biometrics" button, which would write to /usr/share), but
# polkit only reads actions from /run/current-system/sw/share. A copy that
# reaches the system profile only through Home Manager's per-user profile is
# invisible to it, so the package goes in environment.systemPackages too —
# the same store path home/bitwarden.nix installs, so nothing is built twice.
#
# Only theseus has a fingerprint reader. On the other desktop hosts the same
# action falls back to the account password, which is still a working
# "unlock with system authentication".
{
  pkgs,
  lib,
  config,
  ...
}:
lib.mkIf config.features.desktop {
  environment.systemPackages = [ pkgs.bitwarden-desktop ];
}
