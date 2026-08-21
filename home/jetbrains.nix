# IntelliJ IDEA — the JetBrains IDE, next to VS Code rather than instead of
# it (Java/Kotlin work is the case VS Code is worst at).
#
# There is no `jetbrains.idea-community` any more: JetBrains discontinued
# the separate Community edition in 2025 and merged everything into one
# distribution, and nixpkgs removed the attribute outright — evaluating it
# throws a "has been removed" error naming its two replacements.
#
# Of those two, `jetbrains.idea-oss` is the Apache-2.0 build (the literal
# Community successor) and plain `jetbrains.idea` is JetBrains' own
# unified binary. This takes the latter, despite it being the unfree one,
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
# Package only. IDEA writes its whole configuration — keymaps, plugins,
# per-project SDK paths, the IDE's own JVM options — into a versioned
# ~/.config/JetBrains/IntelliJIdea<version> directory that it migrates
# between releases on first launch, and it has JetBrains' own Settings Sync
# for carrying that between machines. Same call as home/vscode.nix: Nix's
# job here is making sure the binary exists.
{
  pkgs,
  lib,
  osConfig,
  ...
}:
lib.mkIf osConfig.features.development {
  home.packages = [ pkgs.jetbrains.idea ];
}
