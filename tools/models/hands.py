"""The shooter's gloved hand with its forearm, built in Blender.

    blender -b --factory-startup --python tools/models/hands.py -- <out.glb> [--sheet <folder>]

tools/build_hands.sh runs this and hands the result to tools/build_hands.gd,
which turns it into scenes/models/glove.scn; tools/models/weapons.gd closes
that hand around whatever a weapon gives it to hold.

It is a right hand, lying palm down and relaxed: the wrist at the origin, the
fingers towards +Y, the back of the hand towards +Z and the thumb towards -X.
Every joint is a bone whose Y runs along it and whose X is the axis it bends
about, so that turning a bone by a negative angle about its own X curls it.

The shape is not modelled but described: for every point in a block of space
around the hand, how far it is from the nearest of a set of rounded shapes (a
finger joint to the next, the bones of the hand, the ball of the thumb), with
the shapes flowing into one another where they meet. The surface is where
that distance is nothing. The plates on the knuckles and the fingers and the
strap are the same surface a little further out, cut to their outline, and
the sleeve is a tube whose girth ripples. --sheet renders the hand in a few
poses on the CPU, to look at it without starting the game.
"""

import json
import math
import sys

import bpy
import numpy as np
import openvdb
from mathutils import Matrix, Vector
from mathutils.kdtree import KDTree

MM = 0.001

# Where each finger leaves the hand (the middle of its knuckle), how far it
# is turned outwards from straight ahead, the length of its three bones and
# its thickness at the knuckle, the two joints and the tip. Millimetres, for
# a large hand in a glove.
FINGERS = {
    "index": {"at": (-30.0, 93.0, 0.0), "yaw": 6.0, "bones": (45.0, 26.0, 25.0), "radius": (11.6, 10.6, 9.6, 8.4)},
    "middle": {"at": (-6.0, 98.0, 1.5), "yaw": 1.0, "bones": (49.0, 30.0, 27.0), "radius": (11.8, 10.8, 9.8, 8.6)},
    "ring": {"at": (17.0, 93.0, 0.5), "yaw": -4.0, "bones": (45.0, 28.0, 26.0), "radius": (11.2, 10.2, 9.3, 8.2)},
    "little": {"at": (38.0, 82.0, -2.5), "yaw": -10.0, "bones": (36.0, 20.0, 23.0), "radius": (10.2, 9.2, 8.4, 7.4)},
}
# How far a finger at rest is bent at its knuckle and its two joints, degrees.
REST = (16.0, 26.0, 14.0)
# The thumb starts at the heel of the hand and points forwards and outwards;
# `up` is where its nail faces, which is sideways rather than up.
THUMB = {
    "at": (-26.0, 24.0, -10.0),
    "towards": (-0.44, 0.84, -0.32),
    "up": (-0.62, -0.2, 0.76),
    "bones": (44.0, 33.0, 29.0),
    "radius": (14.5, 12.6, 11.6, 9.8),
    "rest": (0.0, 12.0, 10.0),
}
FOREARM = 270.0
# How far the cuff of the glove reaches up the arm, and where the sleeve begins.
CUFF = 64.0
SLEEVE = 52.0
# Half the stretch over which a joint bends the glove, from the knuckle out.
BEND = (13.0, 8.5, 7.0)
THUMB_BEND = (17.0, 9.5, 7.5)


def v(point):
    return Vector(point) * MM


def chain(at, ahead, up, lengths, curl):
    """The joints of a finger at rest and which way the back of each bone
    faces: it starts out along `ahead` and bends by `curl` degrees at each
    joint, towards the palm."""
    ahead = Vector(ahead).normalized()
    across = ahead.cross(Vector(up)).normalized()
    points = [v(at)]
    backs = []
    bent = 0.0
    for length, more in zip(lengths, curl):
        bent += more
        turn = Matrix.Rotation(-math.radians(bent), 3, across)
        points.append(points[-1] + (turn @ ahead) * length * MM)
        backs.append(turn @ across.cross(ahead))
    return points, backs


def finger_joints(finger):
    yaw = math.radians(finger["yaw"])
    return chain(finger["at"], (-math.sin(yaw), math.cos(yaw), 0.0), (0, 0, 1), finger["bones"], REST)


def thumb_joints():
    return chain(THUMB["at"], THUMB["towards"], THUMB["up"], THUMB["bones"], THUMB["rest"])


# --- Distances -------------------------------------------------------------------


class Field:
    """How far every point of a block of space is from a surface, negative
    inside it. The block runs from `low` to `high` (millimetres) in steps of
    `step` metres."""

    def __init__(self, low, high, step):
        self.low = np.array(low, dtype=np.float64) * MM
        self.step = step
        self.shape = tuple(int(math.ceil((h - l) * MM / step)) + 1 for l, h in zip(low, high))
        self.d = np.full(self.shape, 1.0, dtype=np.float32)

    def blank(self):
        other = Field.__new__(Field)
        other.low, other.step, other.shape = self.low, self.step, self.shape
        other.d = np.full(self.shape, 1.0, dtype=np.float32)
        return other

    def region(self, low, high):
        """The part of the block between two corners (metres), and its points."""
        first = np.clip(np.floor((np.array(low) - self.low) / self.step).astype(int), 0, np.array(self.shape) - 1)
        last = np.clip(np.ceil((np.array(high) - self.low) / self.step).astype(int) + 1, 1, np.array(self.shape))
        part = tuple(slice(a, b) for a, b in zip(first, last))
        axes = [(self.low[i] + np.arange(first[i], last[i]) * self.step).astype(np.float32) for i in range(3)]
        return part, (axes[0][:, None, None], axes[1][None, :, None], axes[2][None, None, :])

    def add(self, shape, low, high, flow, reach=12.0 * MM):
        """Joins a shape to what is there, flowing into it over `flow` metres.
        `shape` gives distances for points; it lies between `low` and `high`."""
        part, points = self.region(np.array(low) - reach, np.array(high) + reach)
        self.d[part] = merged(self.d[part], shape(points).astype(np.float32), flow)

    def cone(self, a, b, ra, rb, flow):
        """A rod from `a` to `b` with rounded ends, `ra` thick at one and `rb` at the other."""
        a, b = np.array(a), np.array(b)
        self.add(lambda p: round_cone(p, a, b, ra, rb), np.minimum(a - ra, b - rb), np.maximum(a + ra, b + rb), flow)

    def ball(self, centre, radii, flow):
        """A ball, or an egg if `radii` is three numbers."""
        centre = np.array(centre)
        radii = np.array([radii] * 3 if np.isscalar(radii) else radii)
        self.add(lambda p: ellipsoid(p, centre, radii), centre - radii, centre + radii, flow)

    def join(self, other, flow):
        self.d = merged(self.d, other.d, flow)

    def sample(self, points):
        """The distance at each of `points` (n by 3), between the steps of the block."""
        at = (points - self.low) / self.step
        base = np.clip(np.floor(at).astype(int), 0, np.array(self.shape) - 2)
        t = (at - base).astype(np.float32)
        total = np.zeros(len(points), dtype=np.float32)
        for dx in (0, 1):
            for dy in (0, 1):
                for dz in (0, 1):
                    share = (t[:, 0] if dx else 1 - t[:, 0]) * (t[:, 1] if dy else 1 - t[:, 1]) * (t[:, 2] if dz else 1 - t[:, 2])
                    total += share * self.d[base[:, 0] + dx, base[:, 1] + dy, base[:, 2] + dz]
        return total

    def outwards(self, points):
        """Which way the surface faces at each of `points`."""
        normals = np.zeros((len(points), 3), dtype=np.float32)
        for axis in range(3):
            shift = np.zeros(3)
            shift[axis] = self.step
            normals[:, axis] = self.sample(points + shift) - self.sample(points - shift)
        return normals / np.maximum(np.linalg.norm(normals, axis=1, keepdims=True), 1e-9)

    def surface(self):
        """The surface as points and faces of three and four corners."""
        band = 3.0 * self.step
        grid = openvdb.FloatGrid(band)
        grid.copyFromArray(np.clip(self.d, -band, band))
        grid.transform = openvdb.createLinearTransform(voxelSize=self.step)
        grid.gridClass = openvdb.GridClass.LEVEL_SET
        points, triangles, quads = grid.convertToPolygons(isovalue=0.0, adaptivity=0.0)
        return points.astype(np.float64) + self.low, triangles, quads


def merged(a, b, flow):
    """The nearer of two surfaces, rounded off where they meet."""
    if flow <= 0.0:
        return np.minimum(a, b)
    h = np.maximum(flow - np.abs(a - b), 0.0) / flow
    return np.minimum(a, b) - h * h * flow * 0.25


def common(a, b, flow):
    """What two shapes share, rounded off along the cut."""
    return -merged(-a, -b, flow)


def round_cone(p, a, b, ra, rb):
    ba = b - a
    l2 = float(ba.dot(ba))
    rr = ra - rb
    a2 = l2 - rr * rr
    il2 = 1.0 / l2
    px, py, pz = p[0] - a[0], p[1] - a[1], p[2] - a[2]
    y = px * ba[0] + py * ba[1] + pz * ba[2]
    z = y - l2
    qx, qy, qz = px * l2 - ba[0] * y, py * l2 - ba[1] * y, pz * l2 - ba[2] * y
    x2 = qx * qx + qy * qy + qz * qz
    y2 = y * y * l2
    z2 = z * z * l2
    k = np.sign(rr) * rr * rr * x2
    return np.where(
        np.sign(z) * a2 * z2 > k, np.sqrt(x2 + z2) * il2 - rb,
        np.where(np.sign(y) * a2 * y2 < k, np.sqrt(x2 + y2) * il2 - ra, (np.sqrt(x2 * a2 * il2) + y * rr) * il2 - ra))


def ellipsoid(p, centre, radii):
    qx, qy, qz = (p[0] - centre[0]) / radii[0], (p[1] - centre[1]) / radii[1], (p[2] - centre[2]) / radii[2]
    k0 = np.sqrt(qx * qx + qy * qy + qz * qz)
    k1 = np.sqrt((qx / radii[0]) ** 2 + (qy / radii[1]) ** 2 + (qz / radii[2]) ** 2)
    return k0 * (k0 - 1.0) / np.maximum(k1, 1e-9)


def block(p, centre, axes, half, corner):
    """A box with rounded corners, turned to stand along `axes` (three directions)."""
    dx, dy, dz = p[0] - centre[0], p[1] - centre[1], p[2] - centre[2]
    q = []
    for axis, size in zip(axes, half):
        q.append(np.abs(dx * axis[0] + dy * axis[1] + dz * axis[2]) - (size - corner))
    outside = np.sqrt(np.maximum(q[0], 0.0) ** 2 + np.maximum(q[1], 0.0) ** 2 + np.maximum(q[2], 0.0) ** 2)
    return outside + np.minimum(np.maximum(q[0], np.maximum(q[1], q[2])), 0.0) - corner


# --- Shape ---------------------------------------------------------------------


def glove_field():
    """The glove, and the same block of space with nothing in it yet for
    whatever is laid on top of it."""
    field = Field((-84.0, -(CUFF + 28.0), -76.0), (64.0, 198.0, 30.0), 0.5 * MM)
    hand = field.blank()

    # The bones of the hand, from the wrist to each knuckle, and the knuckles
    # themselves standing up out of its back.
    knuckles = []
    for finger in FINGERS.values():
        joints, backs = finger_joints(finger)
        radius = [r * MM for r in finger["radius"]]
        knuckle = np.array(joints[0])
        knuckles.append((knuckle, radius[0]))
        root = np.array((knuckle[0] * 0.42, 6.0 * MM, -2.0 * MM))
        hand.cone(root, knuckle + np.array((0.0, -4.0, 0.0)) * MM, 15.5 * MM, radius[0] * 1.06, 9.0 * MM)
        hand.ball(knuckle + np.array((0.0, -1.5, 3.4)) * MM, radius[0] * 0.92, 5.0 * MM)
        # And the pad under it, on the side of the palm.
        hand.ball(knuckle + np.array((0.0, -11.0, -7.5)) * MM, radius[0] * 0.9, 7.0 * MM)
    # The heel on the side of the little finger.
    hand.cone(np.array((21.0, 10.0, -7.0)) * MM, np.array((37.0, 60.0, -7.5)) * MM, 15.5 * MM, 12.0 * MM, 9.0 * MM)

    # The ball of the thumb and the web between thumb and index finger.
    joints, backs = thumb_joints()
    thumb = [np.array(j) for j in joints]
    radius = [r * MM for r in THUMB["radius"]]
    hand.cone(thumb[0] + np.array((3.0, -6.0, 1.0)) * MM, thumb[1], radius[0] * 1.12, radius[1] * 1.04, 10.0 * MM)
    hand.ball(np.array((-11.0, 33.0, -13.0)) * MM, np.array((15.0, 22.0, 11.0)) * MM, 10.0 * MM)
    hand.cone(thumb[1] * 0.75 + knuckles[0][0] * 0.25, knuckles[0][0] + np.array((1.0, -14.0, -4.0)) * MM, 8.5 * MM, 9.0 * MM, 9.0 * MM)

    # The wrist, and the cuff over it that widens towards the arm.
    for side in (-1.0, 1.0):
        hand.cone(np.array((side * 12.5, 6.0, -1.0)) * MM, np.array((side * 15.5, -CUFF, -1.0)) * MM, 18.5 * MM, 21.5 * MM, 9.0 * MM)
    field.join(hand, 0.0)

    # The fingers and the thumb, each flowing into the hand where it leaves it.
    for finger in list(FINGERS.values()) + [THUMB]:
        joints, backs = finger_joints(finger) if finger is not THUMB else thumb_joints()
        joints = [np.array(j) for j in joints]
        radius = [r * MM for r in finger["radius"]]
        one = field.blank()
        for i in range(3):
            if finger is THUMB and i == 0:
                continue
            one.cone(joints[i], joints[i + 1], radius[i], radius[i + 1], 1.5 * MM)
        # The joints stand out a little at the back, where the glove creases.
        one.ball(joints[1] + np.array(backs[1]) * 1.0 * MM, radius[1] * 1.0, 2.5 * MM)
        one.ball(joints[2] + np.array(backs[2]) * 0.6 * MM, radius[2] * 1.0, 2.5 * MM)
        field.join(one, (7.0 if finger is THUMB else 5.5) * MM)
    return field


def plates_field(glove):
    """What is sewn onto the glove: a guard over the knuckles, a plate on the
    back of each finger bone and the strap round the wrist. Each is the
    surface of the glove a little further out, cut to an outline."""
    plates = glove.blank()

    def lay(thick, centre, axes, half, corner):
        """Raises the glove by `thick` inside a box."""
        centre = np.array(centre)
        reach = float(np.linalg.norm(half)) + 2.0 * MM
        part, points = glove.region(centre - reach, centre + reach)
        cut = common(glove.d[part] - thick, block(points, centre, axes, half, corner).astype(np.float32), 0.7 * MM)
        # Not what lies under the glove's own surface, or it would show inside.
        cut = np.maximum(cut, -(glove.d[part] + 0.4 * MM))
        plates.d[part] = np.minimum(plates.d[part], cut)

    for name, finger in FINGERS.items():
        joints, backs = finger_joints(finger)
        radius = [r * MM for r in finger["radius"]]
        for i in range(2):
            a, b = np.array(joints[i]), np.array(joints[i + 1])
            along = (b - a) / np.linalg.norm(b - a)
            back = np.array(backs[i])
            across = np.cross(along, back)
            middle = a + (b - a) * (0.56 if i == 0 else 0.5) + back * (radius[i] + radius[i + 1]) * 0.5
            length = np.linalg.norm(b - a) * (0.25 if i == 0 else 0.27)
            lay(1.5 * MM, middle, (across, along, back), (radius[i + 1] * 0.72, length, 6.0 * MM), 2.2 * MM)
        # Over the knuckle: a hump of its own, on a strip that joins all four.
        knuckle = np.array(joints[0])
        lay(2.6 * MM, knuckle + np.array((0.0, -3.0, 8.0)) * MM, ((1, 0, 0), (0, 1, 0), (0, 0, 1)), (radius[0] * 0.8, 11.5 * MM, 9.0 * MM), 4.5 * MM)
    lay(1.3 * MM, np.array((2.0, 84.0, 8.0)) * MM, ((0.99, -0.12, 0), (0.12, 0.99, 0), (0, 0, 1)), (43.0 * MM, 9.0 * MM, 10.0 * MM), 5.0 * MM)
    # A pad on the back of the hand and one on the thumb.
    lay(1.2 * MM, np.array((4.0, 44.0, 12.0)) * MM, ((1, 0, 0), (0, 1, 0), (0, 0, 1)), (27.0 * MM, 19.0 * MM, 10.0 * MM), 7.0 * MM)
    joints, backs = thumb_joints()
    radius = [r * MM for r in THUMB["radius"]]
    for i in (1, 2):
        a, b = np.array(joints[i]), np.array(joints[i + 1])
        along = (b - a) / np.linalg.norm(b - a)
        back = np.array(backs[i])
        middle = (a + b) * 0.5 + back * (radius[i] + radius[i + 1]) * 0.5
        lay(1.4 * MM, middle, (np.cross(along, back), along, back), (radius[i + 1] * 0.74, np.linalg.norm(b - a) * 0.27, 6.0 * MM), 2.5 * MM)
    # Where a hand wears through first, in the fork between thumb and index
    # finger, the glove is doubled: that is the side of it the shooter sees.
    fork = np.array(joints[1]) * 0.5 + np.array(finger_joints(FINGERS["index"])[0][0]) * 0.5
    along = np.array(finger_joints(FINGERS["index"])[0][0]) - np.array(joints[1])
    along /= np.linalg.norm(along)
    outwards = np.array((-0.78, 0.0, 0.62))
    outwards -= along * outwards.dot(along)
    outwards /= np.linalg.norm(outwards)
    lay(1.1 * MM, fork + outwards * 6.0 * MM, (np.cross(along, outwards), along, outwards), (15.0 * MM, 19.0 * MM, 13.0 * MM), 5.0 * MM)
    # The strap, all the way round, with its end standing proud on the back.
    # It sits above the wrist, where the glove no longer bends with the hand.
    lay(1.6 * MM, np.array((0.0, -36.0, -1.0)) * MM, ((1, 0, 0), (0, 1, 0), (0, 0, 1)), (60.0 * MM, 8.5 * MM, 40.0 * MM), 2.0 * MM)
    lay(3.0 * MM, np.array((9.0, -36.0, 18.0)) * MM, ((1, 0, 0), (0, 1, 0), (0, 0, 1)), (15.0 * MM, 10.5 * MM, 10.0 * MM), 2.5 * MM)
    return plates


def sleeve_field():
    """The sleeve from the cuff of the glove towards the elbow: a tube that
    widens, creased where an arm creases a sleeve."""
    start = SLEEVE * MM
    field = Field((-70.0, -(FOREARM + 34.0), -66.0), (70.0, -(SLEEVE - 8.0), 64.0), 1.0 * MM)
    part, (x, y, z) = field.region(field.low, field.low + np.array(field.shape) * field.step)
    up = -y
    along = np.clip((up - start) / (FOREARM * MM - start), 0.0, 1.2)
    wide = (37.5 + 17.0 * along ** 0.8) * MM
    deep = (32.0 + 18.0 * along ** 0.8) * MM
    around = np.arctan2(z + 0.001, x)
    girth = np.sqrt((x / wide) ** 2 + ((z + 0.001) / deep) ** 2)
    # Folds run round the arm, never quite in a ring, and deeper under it;
    # a few long ones run down it where the cloth hangs.
    folds = 4.6 * np.sin(up * 74.0 + 1.5 * np.sin(around * 2.0 + 0.7) + 0.7 * np.sin(around * 5.0)) ** 3
    folds += 3.2 * np.sin(up * 37.0 + around + 1.0) + 1.5 * np.sin(up * 150.0 + 2.2 * np.sin(around * 3.0 + 2.0))
    folds *= 0.62 - 0.38 * np.sin(around)
    folds += 2.4 * np.sin(around * 3.0 + up * 9.0) * np.sin(up * 17.0 + 0.5)
    folds *= np.clip((up - start - 0.024) / 0.03, 0.0, 1.0)
    tube = (girth - 1.0) * np.minimum(wide, deep) - folds.astype(np.float32) * MM
    # The cuff is a band with a stitched edge; the tube ends there and at the elbow.
    band = np.clip(1.0 - np.abs(up - start - 0.012) / 0.012, 0.0, 1.0)
    tube -= (1.4 * np.sqrt(band) - 0.5 * np.clip(1.0 - np.abs(up - start - 0.021) / 0.0025, 0.0, 1.0)).astype(np.float32) * MM
    ends = np.maximum(up - (FOREARM + 28.0) * MM, start - up)
    field.d = common(tube.astype(np.float32), np.broadcast_to(ends, tube.shape).astype(np.float32), 3.0 * MM)
    return field


def mesh_of(field, name, triangles, material_name):
    """The surface of a field as an object of about that many triangles,
    shaded as smoothly as the field itself is."""
    points, three, four = field.surface()
    mesh = bpy.data.meshes.new(name)
    # OpenVDB winds its faces the other way round from Blender.
    faces = [tuple(int(i) for i in face[::-1]) for face in four] + [tuple(int(i) for i in face[::-1]) for face in three]
    mesh.from_pydata([tuple(p) for p in points], [], faces)
    mesh.update()
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(obj)
    count = len(four) * 2 + len(three)
    thin = obj.modifiers.new("thin", "DECIMATE")
    thin.ratio = min(1.0, triangles / count)
    obj.data = bpy.data.meshes.new_from_object(obj.evaluated_get(bpy.context.evaluated_depsgraph_get()))
    obj.modifiers.clear()
    mesh = obj.data
    mesh.name = name
    for polygon in mesh.polygons:
        polygon.use_smooth = True
    corners = np.array([vertex.co[:] for vertex in mesh.vertices], dtype=np.float64)
    normals = field.outwards(corners)
    mesh.normals_split_custom_set_from_vertices([tuple(float(c) for c in n) for n in normals])
    mesh.materials.append(bpy.data.materials.get(material_name) or bpy.data.materials.new(material_name))
    return obj


# --- Skeleton ------------------------------------------------------------------


def skeleton():
    data = bpy.data.armatures.new("Hand")
    rig = bpy.data.objects.new("Hand", data)
    bpy.context.collection.objects.link(rig)
    bpy.context.view_layer.objects.active = rig
    bpy.ops.object.mode_set(mode="EDIT")

    def bone(name, head, tail, up, parent=None):
        made = data.edit_bones.new(name)
        made.head = head
        made.tail = tail
        made.align_roll(Vector(up))
        made.parent = parent
        return made

    hand = bone("hand", Vector((0, 0, 0)), v((0.0, 60.0, 0.0)), (0, 0, 1))
    bone("forearm", Vector((0, 0, 0)), v((0.0, -FOREARM, 0.0)), (0, 0, 1), hand)
    fingers = [(name, finger_joints(finger)) for name, finger in FINGERS.items()] + [("thumb", thumb_joints())]
    for name, (joints, backs) in fingers:
        above = hand
        for i in range(3):
            above = bone("%s%d" % (name, i + 1), joints[i], joints[i + 1], backs[i], above)
    bpy.ops.object.mode_set(mode="OBJECT")
    return rig


def strands():
    """What carries the glove, as lines through it: each a row of points, the
    bone between every two of them and how far either side of a point the
    glove bends there."""
    lines = []
    for name, finger in FINGERS.items():
        joints, _ = finger_joints(finger)
        base = joints[0].lerp(Vector((joints[0].x * 0.5, 0.012, 0.0)), 0.6)
        lines.append({"points": [base] + joints, "bones": ["hand"] + ["%s%d" % (name, i + 1) for i in range(3)], "bend": [b * MM for b in BEND]})
    joints, _ = thumb_joints()
    lines.append({"points": [joints[0].lerp(Vector((0.0, 0.005, 0.0)), 0.6)] + joints, "bones": ["hand", "thumb1", "thumb2", "thumb3"], "bend": [b * MM for b in THUMB_BEND]})
    lines.append({"points": [v((0.0, 45.0, 0.0)), Vector((0, 0, 0)), v((0.0, -FOREARM, 0.0))], "bones": ["hand", "forearm"], "bend": [20.0 * MM]})
    return lines


def nearest(point, line):
    """Distance from a point to a strand, how far along it that is, the point
    there and the stretch of the strand it lies on."""
    best = (1e9, 0.0, point, 0)
    run = 0.0
    points = line["points"]
    for i in range(len(points) - 1):
        a, b = points[i], points[i + 1]
        length = (b - a).length
        t = max(0.0, min(1.0, (point - a).dot(b - a) / (length * length)))
        at = a.lerp(b, t)
        distance = (point - at).length
        if distance < best[0]:
            best = (distance, run + t * length, at, i)
        run += length
    return best


def smoothstep(low, high, x):
    t = max(0.0, min(1.0, (x - low) / (high - low)))
    return t * t * (3.0 - 2.0 * t)


def bind(obj, rig, rigid=None, like=None):
    """Hangs the surface on the bones. Every point goes by the strand it lies
    around, and passes from one bone to the next where that strand bends; near
    two strands at once, as between two fingers, it goes by both. With `rigid`
    all of it follows that one bone, and with `like` every point follows what
    the nearest point of that other surface follows: a plate goes with the
    glove under it."""
    lines = strands()
    groups = {bone.name: obj.vertex_groups.new(name=bone.name) for bone in rig.data.bones}
    mesh = obj.data
    under = None
    if like:
        under = KDTree(len(like.data.vertices))
        for vertex in like.data.vertices:
            under.insert(vertex.co, vertex.index)
        under.balance()
    for vertex in mesh.vertices:
        if rigid or vertex.co.y < -24.0 * MM:
            # Above the wrist there is only the arm.
            groups[rigid or "forearm"].add([vertex.index], 1.0, "REPLACE")
            continue
        if under:
            _, index, _ = under.find(vertex.co)
            for held in like.data.vertices[index].groups:
                groups[like.vertex_groups[held.group].name].add([vertex.index], held.weight, "REPLACE")
            continue
        found = []
        for line in lines:
            distance, along, at, _ = nearest(vertex.co, line)
            # A strand lies behind the surface it carries: the side of a finger
            # that faces its neighbour is not the neighbour's.
            behind = vertex.normal.dot((vertex.co - at).normalized()) if distance > 1e-6 else 1.0
            found.append((distance * (2.0 - behind), along, line))
        least = min(f[0] for f in found)
        weights = {}
        for felt, along, line in found:
            share = max(0.0, 1.0 - (felt - least) / (6.0 * MM)) ** 2
            if share <= 0.0:
                continue
            run = 0.0
            passed = []
            for i, bend in enumerate(line["bend"]):
                run += (line["points"][i + 1] - line["points"][i]).length
                passed.append(smoothstep(run - bend, run + bend, along))
            passed.append(0.0)
            before = 1.0
            for bone, after in zip(line["bones"], passed):
                weights[bone] = weights.get(bone, 0.0) + share * (before - after)
                before = after
        strongest = sorted(weights.items(), key=lambda item: -item[1])[:4]
        total = sum(weight for _, weight in strongest)
        for bone, weight in strongest:
            if weight / total > 0.004:
                groups[bone].add([vertex.index], weight / total, "REPLACE")
    obj.parent = rig
    obj.modifiers.new("bones", "ARMATURE").object = rig


def unwrap(obj):
    """Gives the surface its texture coordinates, in metres, so that a weave
    is the same size everywhere: wound round each finger and the arm, and
    laid flat on the back and the palm of the hand."""
    lines = strands()
    mesh = obj.data
    layer = mesh.uv_layers.new(name="UVMap")
    for polygon in mesh.polygons:
        centre = polygon.center
        best = min(range(len(lines)), key=lambda i: nearest(centre, lines[i])[0])
        line = lines[best]
        _, _, _, stretch = nearest(centre, line)
        is_hand = line["bones"][stretch] == "hand"
        first = None
        for loop in polygon.loop_indices:
            co = mesh.vertices[mesh.loops[loop].vertex_index].co
            if is_hand:
                normal = polygon.normal
                if abs(normal.z) > 0.55:
                    uv = (co.x if normal.z > 0 else 0.3 - co.x, co.y)
                else:
                    uv = (0.6 + (co.z if normal.x > 0 else -co.z), co.y)
            else:
                a, b = line["points"][stretch], line["points"][stretch + 1]
                axis = (b - a).normalized()
                side = axis.cross(Vector((0, 0, 1))).normalized()
                up = side.cross(axis)
                off = co - a
                angle = math.atan2(off.dot(side), -off.dot(up))
                if first is None:
                    first = angle
                # A face that lies across the seam stays in one piece.
                while angle - first > math.pi:
                    angle -= math.tau
                while angle - first < -math.pi:
                    angle += math.tau
                run = sum((line["points"][i + 1] - line["points"][i]).length for i in range(stretch))
                uv = (1.0 + best * 0.2 + angle * 0.011, run + off.dot(axis))
            layer.data[loop].uv = uv


# --- Poses and pictures --------------------------------------------------------

# Degrees of curl beyond rest at the knuckle and the two joints of the
# fingers, then of the three joints of the thumb.
POSES = {
    "rest": {"fingers": (0, 0, 0), "thumb": (0, 0, 0)},
    "flat": {"fingers": (-16, -26, -14), "thumb": (-4, -12, -10)},
    "hold": {"fingers": (40, 46, 24), "thumb": (14, 14, 24)},
    "fist": {"fingers": (66, 72, 46), "thumb": (24, 26, 44)},
    "point": {"fingers": (66, 72, 46), "thumb": (24, 26, 44), "index": (-14, -24, -12)},
}


def pose(rig, name):
    curl = POSES[name]
    for bone in rig.pose.bones:
        bone.rotation_mode = "XYZ"
        bone.rotation_euler = (0.0, 0.0, 0.0)
        if bone.name[-1] not in "123":
            continue
        finger = bone.name[:-1]
        angles = curl.get(finger, curl["thumb" if finger == "thumb" else "fingers"])
        bone.rotation_euler.x = -math.radians(angles[int(bone.name[-1]) - 1])


def sheet(rig, folder):
    scene = bpy.context.scene
    scene.render.engine = "CYCLES"
    scene.cycles.device = "CPU"
    scene.cycles.samples = 24
    scene.render.threads_mode = "FIXED"
    scene.render.threads = 4
    scene.render.resolution_x = 600
    scene.render.resolution_y = 480
    scene.world = bpy.data.worlds.new("sky")
    scene.world.use_nodes = True
    scene.world.node_tree.nodes["Background"].inputs[0].default_value = (0.5, 0.52, 0.56, 1.0)
    scene.world.node_tree.nodes["Background"].inputs[1].default_value = 0.8
    sun = bpy.data.objects.new("sun", bpy.data.lights.new("sun", "SUN"))
    sun.data.energy = 3.0
    sun.rotation_euler = (math.radians(50), math.radians(10), math.radians(-30))
    scene.collection.objects.link(sun)
    for shade, name in ((0.42, "glove"), (0.16, "glove_pad"), (0.3, "sleeve")):
        clay = bpy.data.materials.get(name)
        if clay:
            clay.use_nodes = True
            clay.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value = (shade, shade, shade * 1.04, 1.0)
    camera = bpy.data.objects.new("camera", bpy.data.cameras.new("camera"))
    camera.data.lens = 70
    scene.collection.objects.link(camera)
    scene.camera = camera
    middle = Vector((0.0, 0.04, 0.0))
    views = {"back": (0.04, -0.22, 0.44), "palm": (-0.05, -0.2, -0.45), "thumb": (-0.46, 0.05, 0.14), "front": (0.12, 0.48, 0.2), "shooter": (-0.16, -0.42, 0.2)}
    for name in POSES:
        pose(rig, name)
        for view, eye in views.items():
            camera.location = Vector(eye)
            camera.rotation_euler = (middle - camera.location).to_track_quat("-Z", "Z").to_euler()
            scene.render.filepath = "%s/%s_%s.png" % (folder, name, view)
            bpy.ops.render.render(write_still=True)
    pose(rig, "rest")


def main():
    args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    out = args[0] if args else "/tmp/glove.glb"
    for obj in list(bpy.data.objects):
        bpy.data.objects.remove(obj)

    field = glove_field()
    glove = mesh_of(field, "Glove", 9000, "glove")
    plates = mesh_of(plates_field(field), "Plates", 3600, "glove_pad")
    sleeve = mesh_of(sleeve_field(), "Sleeve", 4200, "sleeve")
    rig = skeleton()
    for obj, rigid, like in ((glove, None, None), (plates, None, glove), (sleeve, "forearm", None)):
        unwrap(obj)
        bind(obj, rig, rigid, like)
        print("%s: %d vertices, %d faces" % (obj.name, len(obj.data.vertices), len(obj.data.polygons)))

    if "--sheet" in args:
        sheet(rig, args[args.index("--sheet") + 1])
    bpy.ops.export_scene.gltf(filepath=out, export_format="GLB", export_yup=True, export_apply=False, export_animations=False, export_skins=True)
    # What cannot be read back from the file: how long and how thick each bone is.
    bones = {}
    for name, finger in list(FINGERS.items()) + [("thumb", THUMB)]:
        for i in range(3):
            bones["%s%d" % (name, i + 1)] = {"length": finger["bones"][i] * MM, "radius": [finger["radius"][i] * MM, finger["radius"][i + 1] * MM]}
    with open(out + ".json", "w") as about:
        json.dump({"bones": bones, "forearm": FOREARM * MM}, about, indent="\t")
    print("wrote", out)


main()
