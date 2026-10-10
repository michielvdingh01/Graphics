"""Cuts a figure out of the plain background it was painted on.

    blender -b --python tools/characters/cutout.py -- <picture> <out.png>

TRELLIS.2 wants a picture with a see-through background. Its demo can remove
one, but hands that to another demo, which costs one of the few GPU turns a
visitor gets in a day. A painted character stands on an even backdrop, so it
can be done here: the backdrop is whatever can be reached from the edge of the
picture without crossing an edge in the picture, and that follows the soft
shadow on the floor without eating a grey collar.
"""

import sys

import bpy
import numpy as np

# How much two neighbouring pixels may differ and still be the same backdrop.
STEP = 0.022
# A backdrop is one tint from a dark corner to a lit floor: how far a pixel may
# be from the tint of the border, and from its brightness, to be backdrop at all.
TINT = 0.07
SHADE = 0.45


def main() -> None:
    source, target = sys.argv[sys.argv.index("--") + 1:][:2]
    image = bpy.data.images.load(source)
    width, height = image.size
    pixels = np.empty(width * height * 4, dtype=np.float32)
    image.pixels.foreach_get(pixels)
    pixels = pixels.reshape(height, width, 4)
    colour = pixels[:, :, :3]
    border = np.median(np.concatenate([colour[0], colour[-1], colour[:, 0], colour[:, -1]]), axis=0)
    bright = colour.mean(axis=2)
    tint = colour - bright[:, :, None]
    near = (np.linalg.norm(tint - (border - border.mean()), axis=2) < TINT) & (np.abs(bright - border.mean()) < SHADE)
    backdrop = np.zeros((height, width), dtype=bool)
    backdrop[0], backdrop[-1], backdrop[:, 0], backdrop[:, -1] = near[0], near[-1], near[:, 0], near[:, -1]
    alike = {
        (0, 1): np.linalg.norm(colour[:, 1:] - colour[:, :-1], axis=2) < STEP,
        (1, 0): np.linalg.norm(colour[1:] - colour[:-1], axis=2) < STEP,
    }

    def spread(backdrop: np.ndarray) -> np.ndarray:
        while True:
            grown = backdrop.copy()
            grown[:, 1:] |= backdrop[:, :-1] & alike[(0, 1)]
            grown[:, :-1] |= backdrop[:, 1:] & alike[(0, 1)]
            grown[1:] |= backdrop[:-1] & alike[(1, 0)]
            grown[:-1] |= backdrop[1:] & alike[(1, 0)]
            grown &= near
            if (grown == backdrop).all():
                return backdrop
            backdrop = grown

    backdrop = spread(backdrop)
    # The backdrop between two legs or under an arm cannot be reached from the
    # edge. It is what has the colour the backdrop has beside it, at that height.
    beside = np.full((height, 3), np.nan)
    for row in range(height):
        if backdrop[row].any():
            beside[row] = np.median(colour[row][backdrop[row]], axis=0)
    known = np.nonzero(~np.isnan(beside[:, 0]))[0]
    if len(known):
        for channel in range(3):
            beside[:, channel] = np.interp(np.arange(height), known, beside[known, channel])
        same = near & ~backdrop & (np.linalg.norm(colour - beside[:, None, :], axis=2) < 0.03)
        # Only where a whole patch has that colour: a white face has pixels of
        # it too, here and there.
        patch = same.copy()
        for reach in range(1, 7):
            for axis in (0, 1):
                patch &= np.roll(same, reach, axis) & np.roll(same, -reach, axis)
        backdrop = spread(backdrop | patch)
    # A pixel of rim between figure and backdrop is half of each: let it fade.
    solid = ~backdrop
    edge = solid.astype(np.float32)
    for _ in range(2):
        edge = (edge + np.roll(edge, 1, 0) + np.roll(edge, -1, 0) + np.roll(edge, 1, 1) + np.roll(edge, -1, 1)) / 5.0
    pixels[:, :, 3] = np.where(solid, np.minimum(edge * 1.6, 1.0), 0.0)
    result = bpy.data.images.new("cutout", width, height, alpha=True)
    result.pixels.foreach_set(pixels.ravel())
    result.filepath_raw = target
    result.file_format = "PNG"
    result.save()
    print("cutout: %.0f%% of the picture is figure" % (100.0 * solid.mean()))


if __name__ == "__main__":
    main()
