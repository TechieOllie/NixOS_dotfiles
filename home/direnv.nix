# direnv + nix-direnv: entering a project directory loads that project's
# `nix develop` shell automatically, and leaving it unloads it again.
# nix-direnv caches the evaluated shell and GC-roots it, so re-entering is
# instant and `nix-collect-garbage` doesn't delete a project's toolchain.
# Home Manager wires the zsh hook itself (enableZshIntegration defaults on
# once programs.zsh.enable is set in home/zsh.nix).
# Self-gates on osConfig.features.workstation, like the rest of the
# operator's terminal environment.
{
  config,
  lib,
  osConfig,
  ...
}:
lib.mkIf osConfig.features.workstation {
  programs.direnv = {
    enable = true;
    nix-direnv.enable = true;

    # Without this, every `cd` into a project prints the whole diff of the
    # loaded environment — some sixty `+CC +CONFIG_SHELL +NIX_CFLAGS_COMPILE`
    # entries for a stdenv-based shell, which scrolls the prompt away. Errors
    # and the `direnv: loading` line are still shown; only the export dump is
    # suppressed.
    silent = true;

    # `direnv allow` is per-clone mutable state: the approval lives in
    # ~/.local/share/direnv/allow, keyed by the hash of the .envrc's absolute
    # path, so nothing declarative can seed it — and *editing* an .envrc
    # revokes it, which presents as direnv having silently stopped working
    # after a rebuild. A whitelisted prefix removes the approval step from the
    # loop entirely. Scoped to this one repo on purpose: a whitelist means any
    # .envrc beneath it executes arbitrary shell on `cd` with no prompt, which
    # is no new trust boundary for a tree we already run `nixos-rebuild switch`
    # out of, but would be one for something like ~/projects, where a freshly
    # cloned third-party repo would get silent execution.
    config.whitelist.prefix = [ "${config.home.homeDirectory}/.dotfiles" ];
  };
}
