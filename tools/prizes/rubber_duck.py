"""A rubber duck as big as a dog, with a collar in the colour of its team.
Carried, it lies with its side against the back, so that whoever gives chase
sees a duck.

    tools/make_prize.sh tools/prizes/rubber_duck.py
"""

import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import kit  # noqa: E402

kit.start()
rubber = kit.paint("yellow_rubber", (1.0, 0.8, 0.08), roughness=0.32)
bill = kit.paint("orange_rubber", (1.0, 0.42, 0.04), roughness=0.38)
eye = kit.paint("eye", (0.02, 0.02, 0.025), roughness=0.15)
shine = kit.paint("shine", (0.95, 0.95, 0.95), roughness=0.2)
collar = kit.paint("collar", (0.9, 0.9, 0.9), roughness=0.6)

# Body and head as one soft shape: an egg along Y with a flat bottom, a tail
# that turns up at the back (+Y) and a head over the front (-Y).
duck = kit.Field((-0.34, -0.48, -0.06), (0.34, 0.48, 0.74))
duck.ball((0.0, 0.03, 0.2), (0.25, 0.34, 0.2))
duck.rod((0.0, 0.22, 0.24), (0.0, 0.37, 0.4), 0.11, 0.03, flow=0.1)
duck.ball((0.0, -0.17, 0.5), 0.16, flow=0.1)
duck.ball((0.0, -0.06, 0.32), (0.13, 0.13, 0.1), flow=0.08)
duck.carve(lambda p: kit.block(p, (0.0, 0.0, -0.5), (2.0, 2.0, 1.04), 0.0), flow=0.03)
kit.shape(duck, "Body", rubber, triangles=2200)

# The bill: two flat eggs, the upper a little longer than the lower.
beak = kit.Field((-0.12, -0.46, 0.38), (0.12, -0.22, 0.56))
beak.ball((0.0, -0.33, 0.475), (0.085, 0.1, 0.03))
beak.ball((0.0, -0.31, 0.44), (0.07, 0.08, 0.022), flow=0.02)
kit.shape(beak, "Bill", bill, triangles=500)

for side in (-1.0, 1.0):
    kit.ball("Eye" if side < 0 else "Eye2", (side * 0.075, -0.295, 0.565), 0.026, eye)
    kit.ball("Shine" if side < 0 else "Shine2", (side * 0.08, -0.316, 0.575), 0.007, shine)

# A collar round the neck, leaning forward as the neck does.
ring = kit.Field((-0.2, -0.32, 0.24), (0.2, 0.08, 0.5))
ring.torus((0.0, -0.13, 0.37), (0.0, -0.35, 1.0), 0.125, 0.05)
kit.shape(ring, "Collar", collar, triangles=600, team=True)

kit.save("rubber_duck", "Rubber duck", "the duck", stand="football_stand", team_material="team_ribbon",
    poses={"down": {"turn": [0, 40, 0]}})
