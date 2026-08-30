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

  # Terminfo for terminals this host is SSHed *from*, which is not the
  # same set as the terminals installed on it — and that difference is
  # the whole reason this line exists.
  #
  # `ol`'s Ghostty comes from home/ghostty.nix, which self-gates on
  # features.workstation. inotmac has that flag off deliberately (it is
  # a machine ol administers rather than works on), so nothing there
  # provides the `xterm-ghostty` entry — while every SSH session opened
  # from the desktop still arrives carrying `TERM=xterm-ghostty`, since
  # OpenSSH forwards TERM unconditionally. The login shell then fails
  # its terminal lookup and prints `can't find terminal definition for
  # xterm-ghostty` twice before the prompt, and `$terminfo` comes up
  # empty for every capability, which is what makes home/zsh.nix's
  # arrow-key bindings fall over.
  #
  # So the entry has to be present on the *destination*, whether or not
  # that host has any use for the terminal itself. enableAllTerminfo
  # rather than a bare `pkgs.ghostty.terminfo` because the failure is
  # about arriving TERM values in general, not about Ghostty: the option
  # covers alacritty/foot/kitty/wezterm/tmux and the rest by the same
  # argument, costs a handful of small terminfo-only outputs, and needs
  # no edit the next time the operator changes terminal. Verified at
  # this pin: `ghostty` is in the option's own package list
  # (nixos/modules/config/terminfo.nix).
  environment.enableAllTerminfo = true;
}
