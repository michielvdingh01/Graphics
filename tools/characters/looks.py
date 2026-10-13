"""Paints a character up as a zombie or as a clown, or gives a soldier another
uniform: --look=zombie, --look=clown, --look=desert.

Nobody gives away a realistic zombie or clown under a licence a game can use.
Until a generation service makes real ones, this turns any person the import
route handles, including a scan of a friend, into a stand-in: the paint goes
on in space, not on the texture. For every texel it is known where on the
body it lies, which way it faces and which bones it hangs on, so "white from
the hairline to the chin", "blood from the mouth down" and "dots on the
shirt" can be said without knowing how the model was unwrapped.

The look has a seed, so that two zombies from the same person differ.

A uniform is for telling two teams of the same soldiers apart: every line of
UNIFORMS is one, and its name is the look. It dyes what a soldier wears and
carries, keeps the pattern and the folds of the cloth as light and dark,
leaves skin, hair, eyes and the glass of goggles as they are, and takes the
flag and the badges off the sleeves.
"""

import bmesh
import bpy
import numpy as np

HEAD = ("Head", "Neck", "Jaw", "LeftEye", "RightEye")
FEET = ("LeftFoot", "RightFoot", "LeftToes", "RightToes")
LEGS = ("LeftUpperLeg", "RightUpperLeg", "LeftLowerLeg", "RightLowerLeg", "Hips")
BLOOD = np.array([0.30, 0.015, 0.012])
CLOWNS = (
    {"wig": (0.85, 0.25, 0.05), "top": ((0.9, 0.82, 0.1), (0.75, 0.08, 0.1)), "legs": ((0.1, 0.25, 0.7), (0.92, 0.9, 0.85)), "pattern": "dots"},
    {"wig": (0.15, 0.6, 0.2), "top": ((0.55, 0.1, 0.6), (0.95, 0.75, 0.1)), "legs": ((0.8, 0.1, 0.1), (0.95, 0.92, 0.88)), "pattern": "stripes"},
    {"wig": (0.75, 0.1, 0.15), "top": ((0.92, 0.9, 0.85), (0.1, 0.1, 0.12)), "legs": ((0.1, 0.1, 0.12), (0.8, 0.1, 0.1)), "pattern": "diamonds"},
)
# A uniform: the two colours of its cloth, which lie over the soldier in
# blots, and the leather of the boots; None leaves the boots as they came.
# Another uniform is one more line.
UNIFORMS = {
    "desert": {"cloth": ((0.70, 0.59, 0.40), (0.55, 0.43, 0.27)), "boots": (0.56, 0.45, 0.31)},
    "woodland": {"cloth": ((0.20, 0.215, 0.13), (0.235, 0.185, 0.125)), "boots": (0.11, 0.085, 0.065)},
    "night": {"cloth": ((0.109, 0.105, 0.100), (0.174, 0.168, 0.160)), "boots": (0.062, 0.06, 0.058)},
}
# How bright the three tones of a printed pattern lie against the middle of
# the cloth: what is darker than the first is a fold, what is lighter than
# the last a highlight.
TONES = (0.62, 1.0, 1.42)
GREY = np.array([0.3, 0.55, 0.15])


def noise(points: np.ndarray, scale: float, seed: int) -> np.ndarray:
    """Smooth random values 0..1 in space, the same for the same place and seed."""
    at = points / scale + seed * 17.31
    base = np.floor(at).astype(np.int64)
    part = at - base
    part = part * part * (3.0 - 2.0 * part)
    total = np.zeros(len(points))
    for dx in (0, 1):
        for dy in (0, 1):
            for dz in (0, 1):
                corner = base + np.array([dx, dy, dz])
                value = np.sin(corner[:, 0] * 127.1 + corner[:, 1] * 311.7 + corner[:, 2] * 74.7 + seed * 3.3) * 43758.5453
                value = value - np.floor(value)
                weight = (part[:, 0] if dx else 1 - part[:, 0]) * (part[:, 1] if dy else 1 - part[:, 1]) * (part[:, 2] if dz else 1 - part[:, 2])
                total += value * weight
    return total


def clouds(points: np.ndarray, scale: float, seed: int) -> np.ndarray:
    return (noise(points, scale, seed) * 4 + noise(points, scale / 2.1, seed + 1) * 2 + noise(points, scale / 4.3, seed + 2)) / 7.0


def blend(colour: np.ndarray, paint, amount: np.ndarray) -> np.ndarray:
    amount = np.clip(amount, 0.0, 1.0)[:, None]
    return colour * (1.0 - amount) + np.asarray(paint) * amount


def soft(distance: np.ndarray, radius: float, edge: float = 0.35) -> np.ndarray:
    """1 inside the radius, falling to 0 over the last part of it."""
    return np.clip((radius - distance) / (radius * edge), 0.0, 1.0)


def _box(grid: np.ndarray, reach: int) -> np.ndarray:
    """For every cell of a grid, the sum over the cells up to `reach` away."""
    summed = np.pad(grid, reach + 1).cumsum(axis=0).cumsum(axis=1)
    rows, columns = grid.shape
    far = 2 * reach + 1
    return summed[far:far + rows, far:far + columns] - summed[:rows, far:far + columns] - summed[far:far + rows, :columns] + summed[:rows, :columns]


class Canvas:
    """The texels of a character, with what is needed to paint by place."""

    def __init__(self, body: bpy.types.Object, armature: bpy.types.Object, atlas, seed: int):
        mesh = body.data
        self.body, self.armature, self.atlas, self.seed = body, armature, atlas, seed
        self.rows, self.columns = np.nonzero(atlas.covered())
        self.at = atlas.positions(mesh)[self.rows, self.columns].astype(np.float64)
        self.facing = atlas.normals(mesh)[self.rows, self.columns].astype(np.float64)
        self.colour = atlas.color[self.rows, self.columns, :3].astype(np.float64)
        self.rough = atlas.rough[self.rows, self.columns].astype(np.float64)
        self.height = float(max(vertex.co.z for vertex in mesh.vertices))
        self.scale = self.height / 1.78
        self._island = None
        self._members = None

        self.head = self.weight(HEAD)
        self.hands = self.weight(tuple(group.name for group in body.vertex_groups if "Hand" in group.name or any(finger in group.name for finger in ("Thumb", "Index", "Middle", "Ring", "Little"))))
        self.feet = self.weight(FEET)
        self.legs = self.weight(LEGS)

        # The face, from the tip of the nose: the point of the head furthest
        # forward, in the middle, between the brow and the mouth.
        bones = armature.data.bones
        joint = np.array(bones["Head"].head_local)
        s = self.scale
        co = np.array([vertex.co for vertex in mesh.vertices])
        middle = co[(np.abs(co[:, 0] - joint[0]) < 0.012 * s) & (co[:, 2] > joint[2] + 0.02 * s) & (co[:, 2] < joint[2] + 0.11 * s)]
        self.nose = middle[np.argmin(middle[:, 1])] if len(middle) else joint + np.array([0.0, -0.11 * s, 0.07 * s])
        self.eyes = [self.nose + np.array([side * 0.032 * s, 0.024 * s, 0.040 * s]) for side in (1.0, -1.0)]
        self.mouth = self.nose + np.array([0.0, 0.016 * s, -0.036 * s])
        self.chin = self.mouth[2] - 0.045 * s
        self.brow = self.eyes[0][2] + 0.03 * s

        # Skin: what has the colour of the cheeks. On the head and the hands
        # that is taken broadly, elsewhere narrowly, or khaki trousers are legs.
        cheeks = np.zeros(len(self.at), dtype=bool)
        for side in (1.0, -1.0):
            cheeks |= np.linalg.norm(self.at - (self.nose + np.array([side * 0.038 * s, 0.03 * s, -0.012 * s])), axis=1) < 0.014 * s
        tone = np.median(self.colour[cheeks], axis=0) if cheeks.sum() > 20 else np.array([0.7, 0.5, 0.4])
        self.tone = tone
        ratio = self.colour / np.maximum(self.colour.sum(axis=1, keepdims=True), 1e-3)
        away = np.linalg.norm(ratio - tone / tone.sum(), axis=1)
        bright = self.colour.sum(axis=1) / tone.sum()
        exposed = np.maximum(self.head, self.hands)
        reach = 0.035 + 0.045 * exposed
        self.skin = soft(away, reach, 0.4) * ((bright > 0.35) & (bright < 1.9))
        self.front = np.clip(-self.facing[:, 1] * 2.0 + 0.6, 0.0, 1.0)
        self.face = self.head * soft(np.linalg.norm((self.at - (self.nose + np.array([0.0, 0.07 * s, 0.01 * s]))) * np.array([1.0, 0.8, 0.82]), axis=1), 0.105 * s, 0.25) * (self.at[:, 2] > self.chin)

    def near(self, point, radius: float, edge: float = 0.35) -> np.ndarray:
        return soft(np.linalg.norm(self.at - np.asarray(point), axis=1), radius * self.scale, edge)

    def weight(self, bones: tuple) -> np.ndarray:
        """How much of every texel hangs on these bones, 0..1."""
        mesh = self.body.data
        indices = {group.index for group in self.body.vertex_groups if group.name in bones}
        values = np.zeros(len(mesh.vertices), dtype=np.float32)
        for vertex in mesh.vertices:
            values[vertex.index] = sum(element.weight for element in vertex.groups if element.group in indices)
        return self.atlas.attribute(mesh, values)[self.rows, self.columns]

    def islands(self) -> np.ndarray:
        """Which island of the texture every texel lies on: the faces that
        hang together where the model was unwrapped. A sleeve is one, a boot
        is one, and so is the face with the hair around it."""
        if self._island is None:
            mesh = self.body.data
            layout = np.empty(len(mesh.loops) * 2, dtype=np.float32)
            mesh.uv_layers.active.data.foreach_get("uv", layout)
            # Corners that lie on the same spot of the texture are one point of it.
            point = np.unique(layout.reshape(-1, 2), axis=0, return_inverse=True)[1].reshape(-1)
            faces = point[self.atlas.triangles]
            joined = list(range(int(point.max()) + 1))

            def first(at: int) -> int:
                while joined[at] != at:
                    joined[at] = joined[joined[at]]
                    at = joined[at]
                return at

            for corners in faces.tolist():
                home = first(corners[0])
                joined[first(corners[1])] = home
                joined[first(corners[2])] = home
            of_face = np.unique([first(at) for at in faces[:, 0].tolist()], return_inverse=True)[1].reshape(-1)
            self._island = of_face[self.atlas.face[self.rows, self.columns]]
            order = np.argsort(self._island, kind="stable")
            self._members = np.split(order, np.searchsorted(self._island[order], np.arange(1, int(self._island.max()) + 1)))
        return self._island

    def members(self) -> list:
        """The texels of every island, by its number."""
        self.islands()
        return self._members

    def spread(self, values: np.ndarray, reach: int) -> np.ndarray:
        """The mean of a value over the texels up to `reach` away in the
        texture, as far as they lie on a texel's own island: what a spot is
        like, rather than one texel of it."""
        result = np.zeros(len(values))
        for own in self.members():
            if len(own) == 0:
                continue
            rows = self.rows[own] - self.rows[own].min()
            columns = self.columns[own] - self.columns[own].min()
            total = np.zeros((rows.max() + 1, columns.max() + 1))
            count = np.zeros_like(total)
            total[rows, columns] = values[own]
            count[rows, columns] = 1.0
            result[own] = (_box(total, reach) / np.maximum(_box(count, reach), 1.0))[rows, columns]
        return result

    def finish(self) -> None:
        self.atlas.color[self.rows, self.columns, :3] = np.clip(self.colour, 0.0, 1.0)
        self.atlas.rough[self.rows, self.columns] = np.clip(self.rough, 0.05, 1.0)


def zombie(canvas: Canvas) -> None:
    c, seed, s = canvas, canvas.seed, canvas.scale
    grey = c.colour @ np.array([0.3, 0.55, 0.15])
    # Clothes that have been lived and died in: faded, grimy, darker towards the ground.
    cloth = 1.0 - c.skin
    faded = c.colour * 0.55 + grey[:, None] * 0.3
    c.colour = blend(c.colour, faded, cloth * 0.9)
    grime = clouds(c.at, 0.16 * s, seed)
    low = np.clip(1.0 - c.at[:, 2] / (0.9 * c.height), 0.0, 1.0)
    c.colour = blend(c.colour, c.colour * np.array([0.42, 0.36, 0.27]), cloth * np.clip((grime - 0.42 + 0.35 * low) * 3.0, 0.0, 0.85))

    # Skin with no blood behind it, mottled, darker where it has pooled.
    pallor = np.stack([grey * 0.78, grey * 0.86, grey * 0.70], axis=1) + np.array([0.03, 0.05, 0.02])
    c.colour = blend(c.colour, pallor, c.skin * 0.82)
    mottle = clouds(c.at, 0.035 * s, seed + 5)
    c.colour = blend(c.colour, c.colour * np.array([0.5, 0.42, 0.55]), c.skin * np.clip((mottle - 0.5) * 4.0, 0.0, 0.7))
    veins = np.abs(noise(c.at, 0.022 * s, seed + 9) - 0.5)
    c.colour = blend(c.colour, np.array([0.16, 0.2, 0.3]), c.skin * c.head * np.clip((0.03 - veins) * 22.0, 0.0, 0.28))

    # Sunken eyes with a dead white in them.
    for eye in c.eyes:
        socket = c.near(eye + np.array([0.0, 0.0, -0.002 * s]), 0.034, 0.7) * c.head
        c.colour = blend(c.colour, np.array([0.07, 0.03, 0.06]), socket * 0.85)
        ball = c.near(eye + np.array([0.0, -0.004 * s, 0.0]), 0.0125, 0.3) * c.head
        c.colour = blend(c.colour, np.array([0.74, 0.72, 0.6]), ball * 0.9)
        c.rough = c.rough * (1.0 - ball) + 0.2 * ball
    # Blood from the mouth down over the chin and the chest.
    side = np.abs(c.at[:, 0] - c.mouth[0])
    down = c.mouth[2] - c.at[:, 2]
    ragged = clouds(c.at, 0.03 * s, seed + 3)
    spill = (down > -0.012 * s) & (down < 0.42 * s) & (c.facing[:, 1] < 0.25)
    width = (0.034 + 0.05 * np.clip(down / (0.3 * s), 0.0, 1.0)) * s * (0.55 + ragged)
    blood = spill * np.clip((width - side) / (0.012 * s), 0.0, 1.0) * np.clip(1.25 - down / (0.4 * s) - 0.5 * (1.0 - ragged), 0.0, 1.0)
    blood = np.maximum(blood, c.near(c.mouth, 0.03, 0.6) * c.head)
    # On the hands, and thrown about wherever the seed has it.
    blood = np.maximum(blood, c.hands * np.clip((clouds(c.at, 0.05 * s, seed + 11) - 0.3) * 4.0, 0.0, 1.0))
    spots = clouds(c.at, 0.09 * s, seed + 21)
    blood = np.maximum(blood, np.clip((spots - 0.66) * 14.0, 0.0, 1.0) * (c.at[:, 2] > 0.25 * c.height))
    # A few wounds: torn open in the middle, dark around.
    random = np.random.default_rng(seed)
    for _ in range(4):
        z = random.uniform(0.45, 0.8) * c.height
        ring = c.at[np.abs(c.at[:, 2] - z) < 0.01]
        if len(ring) == 0:
            continue
        spot = ring[random.integers(len(ring))]
        stretch = np.array([1.0, 1.0, random.uniform(0.3, 0.6)])
        distance = np.linalg.norm((c.at - spot) * stretch, axis=1)
        blood = np.maximum(blood, soft(distance, 0.05 * s, 0.9) * (0.55 + 0.45 * ragged))
        c.colour = blend(c.colour, np.array([0.06, 0.0, 0.0]), soft(distance, 0.017 * s, 0.5))
    c.colour = blend(c.colour, BLOOD * (0.7 + 0.6 * ragged[:, None]), blood * 0.93)
    c.rough = c.rough * (1.0 - blood) + 0.3 * blood


def clown(canvas: Canvas) -> dict:
    c, seed, s = canvas, canvas.seed, canvas.scale
    suit = CLOWNS[seed % len(CLOWNS)]
    grey = c.colour @ np.array([0.3, 0.55, 0.15])
    cloth = (1.0 - c.skin) * (1.0 - np.clip(c.head * 2.0, 0.0, 1.0))
    # The folds of the cloth are in how bright it was; keep those under the new colours.
    typical = np.median(grey[cloth > 0.5]) if (cloth > 0.5).sum() > 100 else 0.4
    folds = np.clip(grey / max(typical, 0.05), 0.35, 1.5)[:, None] ** 0.8
    if suit["pattern"] == "dots":
        cell = 0.115 * s
        centre = (np.floor(c.at / cell) + 0.5) * cell
        second = np.linalg.norm(c.at - centre, axis=1) < 0.034 * s
    elif suit["pattern"] == "stripes":
        # Upright stripes, narrower on the legs.
        second = np.floor((c.at[:, 0] + 0.5 * c.at[:, 1]) / ((0.05 - 0.016 * c.legs) * s)) % 2 == 0
    else:
        u = (c.at[:, 0] + c.at[:, 2] * 0.6) / (0.085 * s)
        v = (c.at[:, 0] - c.at[:, 2] * 0.6) / (0.085 * s)
        second = (np.floor(u) + np.floor(v)) % 2 == 0
    lower = np.clip(c.legs * 1.5, 0.0, 1.0)[:, None]
    first_colour = np.asarray(suit["top"][0]) * (1.0 - lower) + np.asarray(suit["legs"][0]) * lower
    second_colour = np.asarray(suit["top"][1]) * (1.0 - lower) + np.asarray(suit["legs"][1]) * lower
    costume = np.where(second[:, None], second_colour, first_colour) * folds
    c.colour = blend(c.colour, costume, cloth * (1.0 - c.feet) * 0.94)
    # Big shoes in one loud colour, white gloves.
    c.colour = blend(c.colour, np.asarray(suit["top"][1]) * folds, cloth * c.feet * 0.94)
    c.colour = blend(c.colour, np.array([0.9, 0.89, 0.85]) * np.clip(grey / max(float(np.median(grey[c.hands > 0.5])) if (c.hands > 0.5).any() else 0.5, 0.05), 0.5, 1.15)[:, None], np.clip(c.hands * 1.5, 0.0, 1.0) * 0.92)

    # A wig: whatever on the head is not skin.
    hair = c.head * (1.0 - c.skin) * (c.at[:, 2] > c.mouth[2])
    wig = np.asarray(suit["wig"]) * np.clip(grey / max(float(np.median(grey[hair > 0.5])) if (hair > 0.5).sum() > 50 else 0.2, 0.05), 0.35, 1.9)[:, None] ** 0.7
    c.colour = blend(c.colour, wig, hair * 0.9)

    # Greasepaint, cracked: white from the hairline to under the chin.
    cracks = np.abs(noise(c.at, 0.006 * s, seed + 4) - 0.5) < 0.03
    worn = clouds(c.at, 0.03 * s, seed + 6)
    paint = c.face * c.skin * c.front * np.clip(1.25 - 0.7 * worn, 0.0, 1.0) * (1.0 - 0.6 * cracks)
    c.colour = blend(c.colour, np.array([0.93, 0.92, 0.89]) * (0.75 + 0.3 * np.clip(grey / max(float(c.tone @ np.array([0.3, 0.55, 0.15])), 0.05), 0.5, 1.1))[:, None], paint * 0.95)
    c.rough = c.rough * (1.0 - paint) + 0.5 * paint
    on_face = c.head * c.front
    # Diamonds over the eyes, dark and run, in sockets gone grey.
    for eye in c.eyes:
        c.colour = blend(c.colour, np.array([0.12, 0.1, 0.13]), c.near(eye, 0.036, 0.9) * on_face * 0.55)
        dx = np.abs(c.at[:, 0] - eye[0]) / (0.021 * s)
        dz = (c.at[:, 2] - eye[2]) / (0.05 * s)
        run = np.where(dz < 0.0, 1.0 + 0.5 * worn, 1.0)
        diamond = np.clip((1.0 - dx - np.abs(dz) / run) * 6.0, 0.0, 1.0) * (np.abs(c.at[:, 1] - eye[1]) < 0.04 * s)
        ball = c.near(eye + np.array([0.0, -0.004 * s, 0.0]), 0.0115, 0.3)
        c.colour = blend(c.colour, np.array([0.03, 0.04, 0.16]), diamond * on_face * (1.0 - ball) * 0.95)
    # A mouth painted far too wide, curling up into the cheeks, with dark corners.
    dx = c.at[:, 0] - c.mouth[0]
    dz = c.at[:, 2] - c.mouth[2]
    curve = 0.42 * dx * dx / (0.062 * s)
    thick = (0.017 - 0.008 * np.abs(dx) / (0.062 * s)) * s
    smile = np.clip((thick - np.abs(dz - curve)) / (0.004 * s), 0.0, 1.0) * (np.abs(dx) < 0.064 * s) * (np.abs(c.at[:, 1] - c.mouth[1]) < 0.06 * s)
    c.colour = blend(c.colour, np.array([0.62, 0.03, 0.04]), smile * on_face * 0.95)
    inner = np.clip((0.0045 * s - np.abs(dz - curve * 0.85)) / (0.002 * s), 0.0, 1.0) * (np.abs(dx) < 0.058 * s) * (np.abs(c.at[:, 1] - c.mouth[1]) < 0.06 * s)
    c.colour = blend(c.colour, np.array([0.08, 0.0, 0.0]), inner * on_face * 0.9)
    # The nose: a red ball of its own, see ball(), and red under it.
    tip = c.near(c.nose, 0.02, 0.4) * c.head
    c.colour = blend(c.colour, np.array([0.8, 0.04, 0.03]), tip)
    c.rough = c.rough * (1.0 - tip) + 0.22 * tip
    # Grime over all of it, and stains nobody wants explained: this one has
    # not seen a circus in years.
    dirt = clouds(c.at, 0.12 * s, seed + 8)
    c.colour = blend(c.colour, c.colour * np.array([0.42, 0.37, 0.3]), np.clip((dirt - 0.42) * 2.6, 0.0, 0.7) * (1.0 - 0.6 * paint))
    stains = np.clip((clouds(c.at, 0.1 * s, seed + 31) - 0.63) * 12.0, 0.0, 1.0) * (c.at[:, 2] < c.chin)
    stains = np.maximum(stains, c.hands * np.clip((clouds(c.at, 0.05 * s, seed + 13) - 0.45) * 5.0, 0.0, 1.0))
    c.colour = blend(c.colour, BLOOD * 1.1, stains * 0.85)
    c.rough = c.rough * (1.0 - stains) + 0.35 * stains
    return suit


def ball(canvas: Canvas) -> None:
    """A clown's nose: a small ball on the tip of the real one, hung on the head."""
    c = canvas
    mesh = c.body.data
    nearest = int(np.argmin(np.linalg.norm(c.at - c.nose, axis=1)))
    # All of it takes its colour from one red texel.
    row, column = int(c.rows[nearest]), int(c.columns[nearest])
    side = c.atlas.side
    c.atlas.color[max(row - 2, 0):row + 3, max(column - 2, 0):column + 3, :3] = (0.8, 0.04, 0.03)
    c.atlas.rough[max(row - 2, 0):row + 3, max(column - 2, 0):column + 3] = 0.22
    slot = mesh.polygons[int(c.atlas.face[row, column])].material_index
    group = c.body.vertex_groups["Head"].index
    grown = bmesh.new()
    grown.from_mesh(mesh)
    weights = grown.verts.layers.deform.verify()
    layout = grown.loops.layers.uv.verify()
    from mathutils import Matrix, Vector
    made = bmesh.ops.create_icosphere(grown, subdivisions=2, radius=0.024 * c.scale, matrix=Matrix.Translation(Vector(c.nose) + Vector((0.0, -0.008 * c.scale, 0.0))))
    for vertex in made["verts"]:
        vertex[weights][group] = 1.0
        for face in vertex.link_faces:
            face.material_index = slot
            face.smooth = True
            for loop in face.loops:
                loop[layout].uv = ((column + 0.5) / side, (row + 0.5) / side)
    grown.to_mesh(mesh)
    grown.free()


def unmark(canvas: Canvas) -> dict:
    """Takes the flag off the sleeve, and with it the badges that are sewn on
    under it and on the other sleeve, by laying cloth from elsewhere on the
    same sleeve over them.

    The flag is found by its colours: nothing else on an arm is that red and
    that blue. What goes is the pocket it sits on, on both arms: from 5 cm
    above the middle of the flag to 19 cm below it and 7.5 cm to either side,
    but no further down than the pattern of the cloth goes. A sleeve that is
    rolled up ends in a band without one."""
    c, s = canvas, canvas.scale
    top = c.colour.max(axis=1)
    least = np.maximum(top, 0.08)
    red = (c.colour[:, 0] - np.maximum(c.colour[:, 1], c.colour[:, 2])) / least > 0.25
    blue = (c.colour[:, 2] - np.maximum(c.colour[:, 0], c.colour[:, 1])) / least > 0.15
    island = c.islands()
    upper = (c.weight(("LeftShoulder", "LeftUpperArm", "RightShoulder", "RightUpperArm")) > 0.5) & (top > 0.25)
    flag = None
    for index in np.unique(island[upper & (red | blue)]):
        own = upper & (island == index)
        if (own & red).sum() >= 60 and (own & blue).sum() >= 25 and (flag is None or (own & (red | blue)).sum() > flag.sum()):
            flag = own & (red | blue)
    if flag is None:
        return {"flag": "none found"}

    grey = c.colour @ GREY
    mean = c.spread(grey, 3)
    patterned = np.sqrt(np.maximum(c.spread(grey * grey, 3) - mean * mean, 0.0)) / np.maximum(mean, 0.05) > 0.1
    plain = patterned & ~red & ~blue & ((top - c.colour.min(axis=1)) / least < 0.2) & ((c.colour[:, 0] - c.colour[:, 2]) / least < 0.12)
    middle = c.at[flag].mean(axis=0)
    outward = c.facing[flag].mean(axis=0)
    outward /= np.linalg.norm(outward)
    bones = c.armature.data.bones
    covered = 0
    for side in ("Left", "Right"):
        # The other arm is this one in a mirror.
        mirror = np.array([1.0 if (side == "Left") == (middle[0] > 0.0) else -1.0, 1.0, 1.0])
        down = np.array(bones[side + "LowerArm"].head_local) - np.array(bones[side + "UpperArm"].head_local)
        down /= np.linalg.norm(down)
        across = np.cross(down, outward * mirror)
        across /= np.linalg.norm(across)
        along = (c.at - middle * mirror) @ down / s
        aside = np.abs((c.at - middle * mirror) @ across) / s
        turned = c.facing @ (outward * mirror)
        sleeve = (c.weight((side + "Shoulder", side + "UpperArm", side + "LowerArm")) > 0.5) & (turned > 0.05) & (aside < 0.075)
        end = 0.19
        for start in np.arange(0.0, end, 0.005):
            strip = sleeve & (along >= start) & (along < start + 0.01)
            if strip.sum() < 30 or patterned[strip].mean() < 0.5:
                end = start
                break
        # Soft at its edges, also where the sleeve turns away to the inside of the arm.
        amount = sleeve * np.clip(np.minimum(np.minimum(along + 0.05, end - along), 0.075 - aside) / 0.01, 0.0, 1.0) * np.clip((turned - 0.05) / 0.2, 0.0, 1.0)
        covered += _lay_over(c, amount, plain)
    return {"flag": "painted over, with the badges on both sleeves" if covered else "found, but there is no cloth to lay over it", "badge_texels": covered}


def _lay_over(canvas: Canvas, amount: np.ndarray, plain: np.ndarray) -> int:
    """Lays over the texels in `amount` what lies a fixed step away from them
    in the texture, on plain cloth of their own island and clear of what is
    being covered. A step in the texture keeps the grain of a printed
    pattern, which a step in space would smear. The step is the shortest
    that serves all of them. On a sleeve that has no such room there is
    none: then it is the step that serves most, and what that one cannot
    reach is served by the next, a few times over. Returns how many texels
    it covered."""
    c = canvas
    island = c.islands()
    if not (amount > 0.5).any():
        return 0
    # One island at a time: the one most of it lies on, which is the sleeve.
    home = np.bincount(island[amount > 0.5]).argmax()
    left = np.nonzero((amount > 0.02) & (island == home))[0]
    side = c.atlas.side
    which = np.full((side, side), -1, dtype=np.int64)
    which[c.rows, c.columns] = np.arange(len(c.rows))
    # What may be laid over something else: the sleeve as it was, away from the badges.
    usable = np.append((island == home) & (amount <= 0.02), False)
    cloth = c.colour.copy()
    reach = 160
    steps = sorted(((down, right) for down in range(-reach, reach + 1, 2) for right in range(-reach, reach + 1, 2)), key=lambda step: step[0] * step[0] + step[1] * step[1])
    covered = 0
    for _ in range(4):
        if len(left) == 0:
            break
        rows, columns = c.rows[left], c.columns[left]
        best, most = None, 0
        for down, right in steps:
            row, column = rows + down, columns + right
            inside = (row >= 0) & (row < side) & (column >= 0) & (column < side)
            source = np.where(inside, which[np.clip(row, 0, side - 1), np.clip(column, 0, side - 1)], -1)
            fine = usable[source]
            count = int(fine.sum())
            if count > most and plain[source[fine]].mean() >= 0.97:
                best, most = (source, fine), count
                if count == len(left):
                    break
        if best is None:
            break
        source, fine = best
        share = amount[left[fine]][:, None]
        c.colour[left[fine]] = c.colour[left[fine]] * (1.0 - share) + cloth[source[fine]] * share
        covered += most
        left = left[~fine]
    return covered


def _toned(colour: np.ndarray, tone: np.ndarray) -> np.ndarray:
    """A colour for every texel, as light or as dark as the cloth was there:
    `tone` is 1 where that was of middling brightness. A dark colour gets its
    tones further apart than a light one, or its pattern would not show."""
    apart = float(np.clip(1.3 - 1.1 * (colour @ GREY), 0.6, 1.25))
    light = np.minimum(colour * (1.0 + 0.6 * apart), 1.0)
    steps = np.stack([np.zeros(3), colour * (1.0 - 0.45 * apart), colour, light, np.minimum(light * 1.3, 1.0)])
    return np.stack([np.interp(tone, (0.0,) + TONES + (TONES[2] * 1.5,), steps[:, channel]) for channel in range(3)], axis=1)


def uniform(canvas: Canvas, palette: dict) -> dict:
    """Dyes what a soldier wears and carries in the colours of `palette`."""
    c = canvas
    note = unmark(c)
    top = c.colour.max(axis=1)
    least = np.maximum(top, 0.08)
    # How far a colour is from grey, and from blue towards red: not fooled by
    # black, in which the smallest difference is a large part.
    vivid = (top - c.colour.min(axis=1)) / least
    warm = (c.colour[:, 0] - c.colour[:, 2]) / least
    grey = c.colour @ GREY
    island = c.islands()

    # What is not to be dyed. On the head that goes by island: the face comes
    # with its hair, brows and lips, and so do the eyes and the inside of the
    # mouth, and all of those are vivid where a helmet, a cap and goggles are
    # grey. Hair is no colour of its own, so it cannot be told texel by texel.
    typical = float(np.median(grey[vivid < 0.2])) if (vivid < 0.2).sum() > 100 else 0.4
    person = np.zeros(len(c.members()), dtype=bool)
    glass = np.zeros(len(c.members()), dtype=bool)
    boot = np.zeros(len(c.members()), dtype=bool)
    for index, own in enumerate(c.members()):
        if len(own) == 0:
            continue
        on_head = c.head[own].mean() > 0.5
        person[index] = on_head and np.median(vivid[own]) > 0.38
        # Glass is dark and shines all over: the lens of goggles, sunglasses.
        glass[index] = on_head and (c.rough[own] < 0.74).mean() > 0.66 and np.median(grey[own]) < 0.75 * typical
        # Whatever ends below the shin is a boot: a trouser leg goes on up.
        boot[index] = c.at[own, 2].max() < 0.15 * c.height
    # Elsewhere, bare hands and forearms, it goes by colour: skin is vivid
    # and warm, and a spot is skin when most of what is around it is, so that
    # a nail stays a nail and a speck in the cloth stays cloth.
    flesh = np.clip((vivid - 0.28) / 0.1, 0.0, 1.0) * (warm > 0.1)
    around = c.spread(flesh, 4)
    skin = np.maximum(flesh * (around > 0.25), np.clip((around - 0.5) / 0.15, 0.0, 1.0))
    skin = np.where((person | glass)[island], 1.0, skin)
    boots = boot[island] & ~person[island]
    cloth = (1.0 - skin) * ~boots

    # The pattern and the folds are in how bright the cloth was: every tone
    # of it becomes the new colour as much lighter or darker. The two colours
    # lie in blots a hand or two across, which are laid out in space and so
    # run on over a seam and from the jacket onto the vest; their edges give
    # way to the pattern, so that they are cut out of it and not sprayed on.
    typical = float(np.median(grey[cloth > 0.5])) if (cloth > 0.5).sum() > 100 else typical
    tone = grey / max(typical, 0.05)
    first, second = (_toned(np.asarray(colour, dtype=np.float64), tone) for colour in palette["cloth"])
    blot = clouds(c.at, 0.13 * c.scale, c.seed + 40) + 0.2 * (np.clip(tone, 0.4, 1.6) - 1.0) > 0.5
    c.colour = blend(c.colour, np.where(blot[:, None], second, first), cloth)
    if palette.get("boots") is not None and boots.any():
        leather = np.asarray(palette["boots"]) * np.clip(grey / max(float(np.median(grey[boots])), 0.05), 0.25, 1.7)[:, None]
        c.colour = blend(c.colour, leather, boots)
    note["boots"] = "dyed" if palette.get("boots") is not None else "as they came"
    return note


def apply(name: str, body: bpy.types.Object, armature: bpy.types.Object, atlas, seed: int) -> dict:
    canvas = Canvas(body, armature, atlas, seed)
    note = {"name": name, "seed": seed}
    if name == "zombie":
        zombie(canvas)
        canvas.finish()
    elif name == "clown":
        suit = clown(canvas)
        canvas.finish()
        ball(canvas)
        note["pattern"] = suit["pattern"]
    elif name in UNIFORMS:
        note.update(uniform(canvas, UNIFORMS[name]))
        canvas.finish()
    else:
        raise SystemExit("import_character: no look called %s; there is zombie, clown and the uniforms %s" % (name, ", ".join(UNIFORMS)))
    return note
