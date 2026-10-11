# IntelliJ IDEA — the JetBrains IDE, next to VS Code rather than instead of
# it (Java/Kotlin work is the case VS Code is worst at).
#
# There is no `jetbrains.idea-community` any more: JetBrains discontinued
# the separate Community edition in 2025 and merged everything into one
# distribution, and nixpkgs removed the attribute outright — evaluating it
# throws a "has been removed" error naming its two replacements.
#
# Of those two, `intellij-idea-oss` is the Apache-2.0 build (the literal
# Community successor) and plain `intellij-idea` is JetBrains' own
# unified binary. Both lived under the `jetbrains` set as `idea-oss`/`idea`
# until nixpkgs moved them to pkgs/by-name (this repo followed the rename
# on 2026-09-26); the old attributes still work as aliases, but the pname
# changed with the move, which is what modules/system/unfree.nix had to be
# taught. This takes the latter, despite it being the unfree one,
# because nixpkgs currently pins idea-oss at 2025.3.4 and marks that
# version *insecure* (NIXPKGS-2026-2269, multiple known vulnerabilities):
# using it would mean adding it to permittedInsecurePackages, which is a
# worse trade than an unfree entry for a package the operator is entitled
# to run — IDEA's unified distribution starts in its free feature set and
# only asks for a subscription for the Ultimate features. Revisit if
# nixpkgs bumps idea-oss past the advisory.
#
# Being unfree, it needs its name in modules/system/unfree.nix — the usual
# useGlobalPkgs consequence, same as home/vscode.nix.
#
# Package (plus the launcher below) only. IDEA writes its whole
# configuration — keymaps, plugins, per-project SDK paths, the IDE's own JVM
# options — into a versioned ~/.config/JetBrains/IntelliJIdea<version>
# directory that it migrates between releases on first launch, and it has
# JetBrains' own Settings Sync for carrying that between machines. Same call
# as home/vscode.nix: Nix's job here is making sure the binary exists.
#
# `idea [dir]` opens a project (default: the current directory) the way
# launching it from a terminal inside that project would, minus the
# terminal. Two things that matters for:
#   - setsid detaches it. Started from a shell, IDEA is part of that shell's
#     session and dies with the terminal window.
#   - direnv exec gives it the project's environment even when `idea` is run
#     from somewhere else, and IDEA hands that environment to everything it
#     starts (Gradle, run configurations). A blocked .envrc makes direnv
#     refuse to run anything at all, so that case falls back to a plain
#     launch. Caveat: IDEA is one process per user, so a second `idea` only
#     opens a window in the running instance, which keeps the *first*
#     project's environment. Quit IDEA to switch which shell it carries.
{
  pkgs,
  lib,
  osConfig,
  ...
}:
let
  idea = pkgs.writeShellApplication {
    name = "idea";
    runtimeInputs = [
      pkgs.direnv
      pkgs.util-linux
      pkgs.coreutils
    ];
    text = ''
      target=$(realpath -- "''${1:-.}")
      dir=$target
      [ -d "$dir" ] || dir=$(dirname -- "$dir")

      run=(intellij-idea "$target")
      if direnv exec "$dir" true >/dev/null 2>&1; then
        run=(direnv exec "$dir" "''${run[@]}")
      else
        echo "idea: $dir's .envrc is blocked (direnv allow); opening without it" >&2
      fi
      setsid -f "''${run[@]}" >/dev/null 2>&1 </dev/null
    '';
  };
in
lib.mkIf osConfig.features.development {
  home.packages = [
    pkgs.intellij-idea
    idea
  ];
}
