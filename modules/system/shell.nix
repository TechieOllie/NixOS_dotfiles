# System-level shell registration: enables Zsh's NixOS module so it's
# added to /etc/shells and gets NixOS's own system-wide completion
# wiring. Its own file rather than folded into users.nix — "enable a
# shell system-wide" and "assign one user's login shell" are distinct
# concerns (the former needs no particular user; the latter does). Kept
# unconditional, no features.* flag: every real host needs a terminal
# environment, so there's no per-host axis of variation a flag would
# express — same reasoning ARCHITECTURE.md gives for dropping the
# bluetooth and sshAgentUnlock flags.
{ pkgs, ... }:
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
  # that host has any use for the terminal itself — and for arriving TERM
  # values in general, not just Ghostty's, so that the next change of
  # terminal needs no edit here.
  #
  # This is environment.enableAllTerminfo's own package list
  # (nixos/modules/config/terminfo.nix) minus contour, and should go back
  # to that one option once contour builds again. At the 2026-10-08 nixpkgs
  # pin contour 0.6.3 fails to compile (`simd::native_simd` errors in
  # Image.cpp), and its `terminfo` is an output of the full package, so the
  # option alone pulled a from-source build of the whole terminal emulator
  # into every host's closure and failed it. Nothing is lost by leaving it
  # out: ncurses already ships a `contour` entry of its own. Check with
  # `nix build nixpkgs#contour.terminfo` against the locked input;
  # NixOS/nixpkgs#569719 (contour 0.7.0) is the likely fix.
  environment.systemPackages = map (p: p.terminfo) (
    with pkgs.pkgsBuildBuild;
    [
      alacritty
      foot
      ghostty
      kitty
      mtm
      rio
      rxvt-unicode-unwrapped
      rxvt-unicode-unwrapped-emoji
      st
      tmux
      wezterm
      yaft
    ]
  );
}
