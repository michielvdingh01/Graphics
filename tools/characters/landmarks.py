"""Finds where the joints of a standing person are from nothing but its surface.

A scan is a statue: there is no skeleton to read. But a person who stands
upright with the arms held away from the body and the feet apart has a shape
that gives the joints away. Cut into thin horizontal slices, the legs are two
islands that merge at the crotch, each arm is an island beside the trunk that
joins it at the armpit, and the neck is where the trunk is narrowest above the
shoulders. The joints are placed from those few heights and from the middle of
each island, with proportions measured on the skeletons that artists gave the
people of the Rocketbox library (tools/characters/calibrate.py).

Everything here is plain numpy on an array of points: z up, feet at zero.
"""

import numpy as np

SLICES = 220
# Points closer together than this, in body heights, belong to one island.
CELL = 0.007

# Proportions, measured with calibrate.py; fit() shows what each one scales.
# Heights and widths are fractions of the body height. Where a joint can be
# placed both from the shape and from the height alone, it is put halfway: the
# shape follows the person, but clothes, hair and a helmet mislead it, and the
# height alone does not know a long back from long legs.
HIP = 0.500
SHOULDER = 0.784
SHOULDER_PIT = 0.072
PIT = 0.712
SHOULDER_WIDE = 0.111
SHOULDER_IN = 0.035
SHOULDER_BACK = 0.003
CLAVICLE = 0.37
ELBOW = 0.368
WRIST = 0.705
HIP_OUT = 0.88
KNEE = 0.495
ANKLE = 0.058
TOE = 0.64
NECK = 0.833
NECK_DOWN = 0.039
HEAD = 0.036
SPINE = (0.20, 0.44, 0.68)


class PoseError(ValueError):
    """The shape is not a person standing the way a scan has to stand."""


def islands(points: np.ndarray, cell: float) -> list:
    """Groups the points of one slice (x, y) into islands, biggest first."""
    if len(points) == 0:
        return []
    cells = np.floor(points / cell).astype(np.int64)
    keys, inverse = np.unique(cells, axis=0, return_inverse=True)
    inverse = inverse.reshape(-1)
    lookup = {(int(x), int(y)): index for index, (x, y) in enumerate(keys)}
    label = [-1] * len(keys)
    count = 0
    for start in range(len(keys)):
        if label[start] >= 0:
            continue
        label[start] = count
        stack = [start]
        while stack:
            x, y = keys[stack.pop()]
            for dx in (-1, 0, 1):
                for dy in (-1, 0, 1):
                    near = lookup.get((int(x) + dx, int(y) + dy))
                    if near is not None and label[near] < 0:
                        label[near] = count
                        stack.append(near)
        count += 1
    labels = np.array(label)[inverse]
    found = []
    for index in range(count):
        own = points[labels == index]
        low, high = own.min(axis=0), own.max(axis=0)
        # The middle of the outline, not of the points: a scan has more points
        # where there is more detail.
        found.append({"n": len(own), "low": low, "high": high, "centre": (low + high) / 2, "mean": own.mean(axis=0)})
    found.sort(key=lambda island: -island["n"])
    return found


class Slices:
    """A standing figure cut into horizontal slices."""

    def __init__(self, points: np.ndarray):
        self.height = float(points[:, 2].max())
        self.step = self.height / SLICES
        level = np.clip((points[:, 2] / self.step).astype(int), 0, SLICES - 1)
        order = np.argsort(level, kind="stable")
        starts = np.searchsorted(level[order], np.arange(SLICES + 1))
        self.points = [points[order[starts[index]:starts[index + 1]]] for index in range(SLICES)]
        cell = CELL * self.height
        self.levels = [[island for island in islands(own[:, :2], cell) if island["n"] >= 4] for own in self.points]

    def at(self, z: float) -> int:
        return int(np.clip(z / self.step, 0, SLICES - 1))

    def z(self, level: int) -> float:
        return (level + 0.5) * self.step


def _nearest(found: list, centre: np.ndarray, reach: float):
    best = None
    for island in found:
        distance = float(np.linalg.norm(island["centre"] - centre))
        inside = (island["low"] - reach <= centre).all() and (centre <= island["high"] + reach).all()
        if inside and (best is None or distance < best[0]):
            best = (distance, island)
    return best[1] if best else None


def legs(slices: Slices, baggy: bool = False) -> dict:
    """Follows the two legs up from the shins to where they meet. In something
    `baggy`, a suit that hangs down to the knees, that may be lower than any
    crotch is."""
    start = slices.at(0.14 * slices.height)
    found = slices.levels[start]
    if len(found) < 2:
        raise PoseError("the legs are not apart at shin height; stand with the feet a foot's length apart")
    a, b = found[0], found[1]
    tracks = {"a": {start: a}, "b": {start: b}}
    crotch = None
    for level in range(start + 1, SLICES):
        here = slices.levels[level]
        next_a = _nearest(here, tracks["a"][level - 1]["centre"], 0.02 * slices.height)
        next_b = _nearest(here, tracks["b"][level - 1]["centre"], 0.02 * slices.height)
        if next_a is None or next_b is None or next_a is next_b:
            crotch = level
            break
        tracks["a"][level] = next_a
        tracks["b"][level] = next_b
    if crotch is None or not (0.2 if baggy else 0.3) < slices.z(crotch) / slices.height < 0.62:
        raise PoseError("cannot find where the legs meet" + ("" if crotch is None else
            ": they join at %d%% of the height; for a suit that hangs that low, say --baggy" % round(100 * slices.z(crotch) / slices.height)))
    for level in range(start - 1, -1, -1):
        here = slices.levels[level]
        for key in "ab":
            island = _nearest(here, tracks[key][level + 1]["centre"], 0.05 * slices.height)
            tracks[key][level] = island if island is not None else tracks[key][level + 1]
    return {"a": tracks["a"], "b": tracks["b"], "crotch": crotch}


def facing(slices: Slices, baggy: bool = False) -> np.ndarray:
    """The direction the figure looks in, from where its feet stick out."""
    found = legs(slices, baggy)
    ankle = slices.at(0.11 * slices.height)
    sole = slices.at(0.02 * slices.height)
    ahead = np.zeros(2)
    for key in "ab":
        ahead += found[key][sole]["centre"] - found[key][ankle]["centre"]
    length = float(np.linalg.norm(ahead))
    if length < 0.02 * slices.height:
        raise PoseError("cannot tell front from back by the feet; pass --yaw")
    return ahead / length


def fit(points: np.ndarray, measures: dict = None, baggy: bool = False) -> dict:
    """The joints of a figure that faces -Y with its feet on z = 0, as
    {profile bone name: (x, y, z)}. Left is +X. The heights and widths they
    were placed from are left in measures, for calibrate.py. `baggy` is for
    legs that are in one garment down to the knees, see legs()."""
    slices = Slices(points)
    height = slices.height
    found = legs(slices, baggy)
    crotch = found["crotch"]
    below = crotch - 2
    left, right = (found["a"], found["b"]) if found["a"][below]["centre"][0] > found["b"][below]["centre"][0] else (found["b"], found["a"])
    middle = (left[below]["centre"] + right[below]["centre"]) / 2

    # The trunk is the island over the middle; an arm is one beside it.
    trunk = {}
    arms = {"L": {}, "R": {}}
    for level in range(slices.at(0.2 * height), SLICES):
        here = slices.levels[level]
        own = _nearest(here, middle, 0.0) if level >= crotch else None
        if own is not None:
            trunk[level] = own
        for island in here:
            if island is own or island is left.get(level) or island is right.get(level):
                continue
            inner_left = own["high"][0] if own is not None else left[min(level, below)]["high"][0]
            inner_right = own["low"][0] if own is not None else right[min(level, below)]["low"][0]
            if island["centre"][0] > inner_left - 0.01 * height:
                arms["L"].setdefault(level, island)
            elif island["centre"][0] < inner_right + 0.01 * height:
                arms["R"].setdefault(level, island)
    if not trunk:
        raise PoseError("cannot find the trunk above the legs")

    def run(levels: dict) -> list:
        """The longest unbroken run of levels: the arm itself, not a stray bit."""
        best, current = [], []
        for level in sorted(levels):
            current = current + [level] if current and level == current[-1] + 1 else [level]
            if len(current) > len(best):
                best = current
        return best

    joints = {}
    pits = {}
    lines = {}
    for side, word in (("L", "Left"), ("R", "Right")):
        own = run(arms[side])
        if len(own) < 0.03 * SLICES:
            raise PoseError("the %s arm does not stand clear of the body anywhere; hold the arms 30 to 45 degrees out" % word.lower())
        pits[side] = own[-1] + 1
        z = np.array([slices.z(level) for level in own])
        centre = np.array([arms[side][level]["centre"] for level in own])
        z_tip = slices.z(own[0]) - slices.step / 2
        if len(own) >= 0.12 * SLICES:
            # Leave out the hand, where the outline widens, and the last bit under the armpit.
            use = slice(int(len(own) * 0.3), len(own) - 2)
            lines[side] = (np.polyfit(z[use], centre[use, 0], 1), np.polyfit(z[use], centre[use, 1], 1), z_tip)
        else:
            # A sleeve that lies against the body leaves only the hand and the
            # wrist free: enough for where the arm ends, not for how it runs.
            # The elbow then goes on the straight line from the shoulder.
            lines[side] = (None, centre[:max(len(own) // 2, 1)].mean(axis=0), z_tip)
    pit = int(round((pits["L"] + pits["R"]) / 2))
    # An armpit is found where the arm joins the trunk, but a sleeve joins it
    # at the elbow. Where that is no armpit, the height of the body says where one is.
    if not 0.65 * height < slices.z(pit) < 0.78 * height:
        pit = slices.at(PIT * height)

    # The neck: where the trunk is narrowest above the shoulders.
    top = max(trunk)
    width = {level: trunk[level]["high"][0] - trunk[level]["low"][0] for level in trunk}
    span = [level for level in range(slices.at(0.82 * height), slices.at(0.91 * height)) if level in width]
    if not span:
        raise PoseError("cannot find the neck above the shoulders")
    neck = min(span, key=lambda level: width[level])
    z_neck = slices.z(neck)
    z_pit = slices.z(pit)

    def trunk_at(z: float) -> dict:
        level = min(trunk, key=lambda own: abs(own - slices.at(z)))
        return trunk[level]

    # Thighs touch well below the hip joints, so where the legs meet only says
    # how low the hips cannot be.
    z_hip = max(HIP * height, slices.z(crotch) + 0.03 * height)
    hip = trunk_at(z_hip)
    spine_x = float(middle[0])
    # The spine runs behind the middle of the outline, most of all in the neck,
    # where the outline has the chin in it.
    joints["Hips"] = (spine_x, float(hip["centre"][1]) + 0.005 * height, z_hip)
    z_base = (NECK * height + z_neck - NECK_DOWN * height) / 2
    for name, part in zip(("Spine", "Chest", "UpperChest"), SPINE):
        z = z_hip + part * (z_base - z_hip)
        joints[name] = (spine_x, float(trunk_at(z)["centre"][1]) + 0.005 * height, z)
    back = float(trunk_at(z_neck)["centre"][1])
    joints["Neck"] = (spine_x, back + 0.021 * height, z_base)
    joints["Head"] = (spine_x, back + 0.010 * height, z_base + HEAD * height)

    z_shoulder = (SHOULDER * height + z_pit + SHOULDER_PIT * height) / 2
    across = trunk_at(z_shoulder)
    for side, word, sign in (("L", "Left", 1.0), ("R", "Right", -1.0)):
        edge = across["high"][0] if sign > 0 else across["low"][0]
        x = (spine_x + sign * SHOULDER_WIDE * height + edge - sign * SHOULDER_IN * height) / 2
        y = float(across["centre"][1]) + SHOULDER_BACK * height
        joints[word + "UpperArm"] = (float(x), y, z_shoulder)
        joints[word + "Shoulder"] = (spine_x + (float(x) - spine_x) * CLAVICLE, y, z_shoulder + 0.017 * height)
        fit_x, fit_y, z_tip = lines[side]
        shoulder = np.array(joints[word + "UpperArm"])
        if fit_x is None:
            # Only the end of the arm is known: a straight arm from the shoulder to there.
            tip = np.array([fit_y[0], fit_y[1], z_tip])
            fit_x = np.polyfit([z_tip, shoulder[2]], [tip[0], shoulder[0]], 1)
            fit_y = np.polyfit([z_tip, shoulder[2]], [tip[1], shoulder[1]], 1)
        tip = np.array([np.polyval(fit_x, z_tip), np.polyval(fit_y, z_tip), z_tip])
        length = float(np.linalg.norm(tip - shoulder))
        if (shoulder[2] - z_tip) < 0.5 * length:
            raise PoseError("the %s arm is held too high for a scan; hold the arms 30 to 45 degrees out, not level" % word.lower())
        # An elbow sits outside and behind the middle of the arm, a wrist a little outside.
        for name, part, out, behind in (("LowerArm", ELBOW, 0.013, 0.009), ("Hand", WRIST, 0.007, -0.004)):
            z = shoulder[2] - part * (shoulder[2] - z_tip)
            # Near the shoulder the joint is on the way to the arm's line, further down on it.
            blend = min(part * 2.2, 1.0)
            x = shoulder[0] + (tip[0] - shoulder[0]) * part
            y = shoulder[1] + (tip[1] - shoulder[1]) * part
            joints[word + name] = (
                float(x * (1 - blend) + np.polyval(fit_x, z) * blend) + sign * out * height,
                float(y * (1 - blend) + np.polyval(fit_y, z) * blend) + behind * height, float(z))

        leg = left if side == "L" else right
        top_of_leg = leg[below]["centre"]
        joints[word + "UpperLeg"] = (spine_x + (float(top_of_leg[0]) - spine_x) * HIP_OUT, float(hip["centre"][1]) + 0.005 * height, z_hip)
        z_ankle = ANKLE * height
        ankle = leg[slices.at(z_ankle + 0.03 * height)]["centre"]
        z_knee = z_ankle + KNEE * (z_hip - z_ankle)
        # In a suit that hangs low the knee is above where the legs come apart.
        knee = leg[min(slices.at(z_knee), below)]["centre"]
        joints[word + "LowerLeg"] = (float(knee[0]), float(knee[1]) - 0.002 * height, z_knee)
        joints[word + "Foot"] = (float(ankle[0]), float(ankle[1]), z_ankle)
        sole = np.concatenate([slices.points[level] for level in range(0, slices.at(0.035 * height) + 1)])
        own = sole[np.abs(sole[:, 0] - ankle[0]) < 0.07 * height]
        tip_y = float(own[:, 1].min()) if len(own) else float(ankle[1]) - 0.1 * height
        # Feet point outward: the toes are where the front of the sole is, not straight ahead of the ankle.
        front = own[own[:, 1] < tip_y + 0.35 * (float(ankle[1]) - tip_y)] if len(own) else own
        toe_x = float((front[:, 0].min() + front[:, 0].max()) / 2) if len(front) else float(ankle[0])
        joints[word + "Toes"] = (toe_x, float(ankle[1]) + TOE * (tip_y - float(ankle[1])), 0.008 * height)
        if measures is not None:
            measures[word] = {"edge": float(edge), "tip": tip.tolist(), "leg_x": float(top_of_leg[0]), "toe_tip": tip_y, "ankle_y": float(ankle[1])}
    if measures is not None:
        # Which way the trunk is broad: across the body, whatever the feet say.
        chest = np.concatenate([slices.points[level][:, :2] for level in range(slices.at(z_hip + 0.06 * height), max(pit - 3, slices.at(z_hip + 0.06 * height) + 1))])
        chest = chest[(chest[:, 0] > trunk_at(z_hip + 0.1 * height)["low"][0]) & (chest[:, 0] < trunk_at(z_hip + 0.1 * height)["high"][0])]
        spread = np.linalg.eigh(np.cov((chest - chest.mean(axis=0)).T))[1][:, -1]
        if spread[0] < 0.0:
            spread = -spread
        measures.update(height=height, crotch=slices.z(crotch), pit=z_pit, neck=z_neck, middle=spine_x, shoulder_y=float(across["centre"][1]),
                        skew=float(np.arctan2(spread[1], spread[0])))
    return joints
