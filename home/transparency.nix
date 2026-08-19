# Shared transparency opacity for every app/surface that renders
# semi-transparent (Ghostty, Noctalia's bar, Zen's Transparent Zen mod) — one
# place so they can't silently drift apart from a single "how transparent
# should things be" decision. Plain value import, not a specialArgs-threaded
# option: there's nothing host-conditional about it.
#
# CURRENTLY 1.0 — fully opaque, i.e. transparency is OFF, at the operator's
# request. This one value neutralizes every *client-side* transparent surface
# at once, which is the half that actually matters: niri can only blur behind
# a surface that has real alpha, so with this at 1.0 the compositor-side blur
# rules would be inert even if they weren't also commented out (they are — see
# home/niri/cfg/rules.kdl's banner and misc.kdl's blur block).
#
# Deliberately neutralized rather than deleted, along with its consumers. The
# machinery encodes findings that were expensive to establish and are not
# recoverable by re-reading the code:
#
#   - niri's `opacity` window-rule is NOT client-side alpha. It fades the
#     whole composited window, so Zen/Nautilus/Vesktop show a sharp backdrop
#     at any value and can never show blur. Verified by screenshotting Ghostty
#     and Vesktop side by side on one wallpaper.
#   - Noctalia's panels are opaque until shell.panel.transparency_mode leaves
#     its "solid" default, which silently defeated the entire setup once.
#   - 0.90 was measurably blending but only let ~10% of the backdrop through,
#     which doesn't read as transparency at all; 0.80 was the value that did.
#
# Turning it all back on is: this value to 0.80, transparency_mode back to
# "glass" in home/noctalia.nix, and uncommenting the three blur blocks in
# rules.kdl plus the tuning block in misc.kdl.
1.0
