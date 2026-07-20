# Shared transparency opacity value for every app/surface that renders
# semi-transparent (Ghostty, Noctalia's bar, and any future transparent
# app) — one place so they can't silently drift apart from a single "how
# transparent should things be" decision. Plain value import, not a
# specialArgs-threaded option: there's nothing host-conditional about it.
#
# Lowered from 0.90: pixel-sampled live testing confirmed 0.90 opacity was
# genuinely blending (not broken), but only lets ~10% of the backdrop show
# through — too little for niri's blur (rules.kdl) to look visually
# distinct from plain tinting. 0.80 roughly doubles that to ~20%, enough
# for blur to actually read as blur.
0.80
