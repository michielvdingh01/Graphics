"""A gold cup with two handles on a black foot, a band round the foot in the
colour of its team.

    tools/make_prize.sh tools/prizes/trophy.py
"""

import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import kit  # noqa: E402

kit.start()
gold = kit.paint("gold", (1.0, 0.77, 0.32), roughness=0.22, metallic=1.0)
foot = kit.paint("black_stone", (0.04, 0.04, 0.045), roughness=0.3)
band = kit.paint("band", (0.9, 0.9, 0.9), roughness=0.45)

# A foot of two steps, a stem with a knot in it, and the bowl, open at the top.
kit.lathe("Foot", [(0.0, 0.0), (0.16, 0.0), (0.16, 0.07), (0.12, 0.08), (0.12, 0.15), (0.0, 0.15)], foot, sides=6, sharp=30.0)
kit.lathe("Band", [(0.0, 0.025), (0.163, 0.025), (0.163, 0.05), (0.0, 0.05)], band, sides=6, team=True, sharp=30.0)
kit.lathe("Cup", [
    (0.0, 0.15), (0.075, 0.15), (0.06, 0.17), (0.025, 0.2), (0.022, 0.27), (0.045, 0.29), (0.022, 0.31), (0.025, 0.34),
    (0.07, 0.37), (0.13, 0.42), (0.165, 0.5), (0.18, 0.6), (0.185, 0.66), (0.192, 0.67),
    # Over the lip and down inside.
    (0.18, 0.672), (0.172, 0.6), (0.155, 0.5), (0.11, 0.43), (0.0, 0.41),
], gold, sides=40, sharp=50.0)

# The handles: a ring on either side, standing up, of which only the part
# outside the bowl is kept.
handles = kit.Field((-0.34, -0.06, 0.36), (0.34, 0.06, 0.7), step=0.006)
for side in (-1.0, 1.0):
    handles.torus((side * 0.2, 0.0, 0.53), (0.0, 1.0, 0.0), 0.075, 0.026)
handles.carve(lambda p: kit.block(p, (0.0, 0.0, 0.5), (0.34, 1.0, 1.0), 0.0))
kit.shape(handles, "Handles", gold, triangles=900)

kit.save("trophy", "Trophy", "the trophy", stand="banana_stand", team_material="team_paint",
    poses={"down": {"turn": [0, 60, 0]}})
