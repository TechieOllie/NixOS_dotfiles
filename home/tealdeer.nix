# tealdeer, a fast client for tldr pages: short, example-first summaries of
# a command (`tldr tar`). The pages are a cache it downloads into
# ~/.cache/tealdeer on first use and refreshes on its own schedule.
#
# Self-gates on osConfig.features.workstation, like the rest of the
# operator's terminal environment.
{ lib, osConfig, ... }:
lib.mkIf osConfig.features.workstation {
  programs.tealdeer = {
    enable = true;
    settings.updates.auto_update = true;
  };
}
