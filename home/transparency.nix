# Shared transparency opacity value for every app/surface that renders
# semi-transparent (Ghostty, Noctalia's bar, and any future transparent
# app) — one place so they can't silently drift apart from a single "how
# transparent should things be" decision. Plain value import, not a
# specialArgs-threaded option: there's nothing host-conditional about it.
#
# Lowered from 0.90: pixel-sampled live testing confirmed 0.90 opacity was
# genuinely blending (not broken), but only lets ~10% of the backdrop show
# through — too little to read as transparency at all. 0.80 roughly
# doubles that to ~20%.
#
# The original note here justified 0.80 as the point where niri's blur
# starts "reading as blur". That reasoning only holds for the surfaces
# with real client-side alpha (Ghostty, and Noctalia's bar) — the apps
# driven by niri's `opacity` window-rule instead (Zen, Nautilus, Vesktop)
# never show blur at any value, because that rule fades the composited
# window rather than making its background translucent. See the
# background-effect block at the top of home/niri/cfg/rules.kdl. The value
# is still shared so the transparent surfaces can't drift apart.
0.80
