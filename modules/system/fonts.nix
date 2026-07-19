# System-level font installation. Currently just JetBrains Mono Nerd
# Font, needed by home/ghostty.nix's font-family setting. Unconditional,
# no features.* flag — same reasoning as modules/system/shell.nix: every
# real host that gets a terminal environment needs this, so there's no
# per-host axis of variation for a flag to express.
{ pkgs, ... }:
{
  fonts.packages = [ pkgs.nerd-fonts.jetbrains-mono ];
}
