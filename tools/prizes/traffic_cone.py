"""A traffic cone, its two reflective bands in the colour of its team.

    tools/make_prize.sh tools/prizes/traffic_cone.py
"""

import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import kit  # noqa: E402

kit.start()
orange = kit.paint("cone_orange", (1.0, 0.33, 0.02), roughness=0.55)
rubber = kit.paint("base_rubber", (0.06, 0.06, 0.065), roughness=0.85)
band = kit.paint("band", (0.92, 0.92, 0.92), roughness=0.35)

# A square foot of black rubber with a rim, and the cone on it, hollow at the
# top where it is rounded off.
kit.box("Foot", (0.0, 0.0, 0.02), (0.5, 0.5, 0.04), rubber)
kit.lathe("Rim", [(0.0, 0.04), (0.23, 0.04), (0.23, 0.055), (0.0, 0.055)], rubber, sides=40)
kit.lathe("Cone", [(0.0, 0.055), (0.205, 0.055), (0.04, 0.74), (0.03, 0.755), (0.0, 0.755)], orange, sides=40)
# The bands stand a few millimetres proud of the cone they are wrapped round.
for low, high, name in ((0.27, 0.37, "Low"), (0.47, 0.54, "High")):
    def radius(height):
        return 0.205 + (0.04 - 0.205) * (height - 0.055) / (0.74 - 0.055) + 0.003
    kit.lathe(name, [(radius(low) - 0.003, low), (radius(low), low), (radius(high), high), (radius(high) - 0.003, high)], band, sides=40, team=True)

kit.save("traffic_cone", "Traffic cone", "the cone", stand="football_stand", team_material="team_paint",
    poses={"down": {"turn": [0, 25, 0]}})
