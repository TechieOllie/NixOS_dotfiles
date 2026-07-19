# System-level shell registration: enables Zsh's NixOS module so it's
# added to /etc/shells and gets NixOS's own system-wide completion
# wiring. Its own file rather than folded into users.nix — "enable a
# shell system-wide" and "assign one user's login shell" are distinct
# concerns (the former needs no particular user; the latter does). Kept
# unconditional, no features.* flag: every real host needs a terminal
# environment, so there's no per-host axis of variation a flag would
# express — same reasoning ARCHITECTURE.md gives for dropping the
# bluetooth and sshAgentUnlock flags.
{ ... }:
{
  programs.zsh.enable = true;
}
