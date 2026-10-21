"""Writes two masks next to a character, for scripts/humanoid_rig.gd to light
skin and cloth each as what it is:

    blender -b --python tools/characters/parts_masks.py -- assets/characters/soldier_01/soldier_01.glb

In <id>_skin.png red and green are where the character is skin (the face
with its hair, brows and lips, the ears, bare hands and forearms), which the
light goes into and comes out of a little further on, and blue is how rough
it is: as its own texture has it, but skin as skin is, with a sheen. The
route makes roughness out of the specular map of a source, and for the skin
of the Rocketbox people that gives 0.92, which is chalk. <id>_cloth.png is
where it is cloth, which has a soft sheen at its edges instead of a shine.
What the rest is (the glass of goggles, boots, the metal on a vest) is in
neither. They come from looks.parts(), which tells a uniform what not to dye,
and are laid out as the textures of the character are, at half their size.
The character itself stays as it is; tools/characters/build_masks.sh makes
them for the soldiers.
"""

import os
import pathlib
import sys

import bpy
import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import atlas  # noqa: E402
import looks  # noqa: E402

SIDE = 512
## How rough skin is, and how far its own roughness gives way to that.
SKIN_ROUGH = 0.55
SKIN_SHARE = 0.85


def main() -> None:
    glb = pathlib.Path(sys.argv[sys.argv.index("--") + 1]).resolve()
    name = glb.stem
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=str(glb), merge_vertices=True)
    armatures = [obj for obj in bpy.context.scene.objects if obj.type == "ARMATURE"]
    bodies = [obj for obj in bpy.context.scene.objects if obj.type == "MESH" and any(modifier.type == "ARMATURE" for modifier in obj.modifiers)]
    if len(armatures) != 1 or len(bodies) != 1:
        sys.exit("parts_masks: %s is not one mesh on one skeleton" % glb)
    body, armature = bodies[0], armatures[0]
    source = atlas.Source(body.material_slots[0].material)
    if None in (source.color, source.roughness):
        sys.exit("parts_masks: %s has not got the textures the route gives a character" % glb)
    textures = atlas.Atlas(source.color[0].size[0])
    textures.color[:] = atlas.pixels(source.color[0])
    textures.rough[:] = atlas.pixels(source.roughness[0])[:, :, "RGB".index(source.roughness[1])]
    textures.locate(body.data)
    canvas = looks.Canvas(body, armature, textures, 0)
    found = looks.parts(canvas)

    covered = textures.covered()
    rough = canvas.rough - (canvas.rough - SKIN_ROUGH) * SKIN_SHARE * found["skin"]

    def half(values: np.ndarray) -> np.ndarray:
        """Laid out as the texture, out over the edges of the islands so that
        a smaller mip does not mix in what lies around them, at half size."""
        full = np.zeros((textures.side, textures.side, 1), dtype=np.float32)
        full[canvas.rows, canvas.columns, 0] = values
        full = atlas.dilate(full, covered, 8)
        step = textures.side // SIDE
        return full[:, :, 0].reshape(SIDE, step, SIDE, step).mean(axis=(1, 3))

    skin = half(found["skin"])
    cloth = half(found["cloth"])
    image = np.ones((SIDE, SIDE, 4), dtype=np.float32)
    image[:, :, 0] = image[:, :, 1] = skin
    image[:, :, 2] = half(rough)
    atlas._save(name + "_skin", image, str(glb.parent), "PNG", False)
    image[:, :, 0] = image[:, :, 1] = image[:, :, 2] = cloth
    atlas._save(name + "_cloth", image, str(glb.parent), "PNG", False)
    for kind in ("skin", "cloth"):
        print("parts_masks: %s %s %.0f%% of the texels, roughness %.2f there, now %.2f" % (name, kind, 100.0 * float((found[kind] > 0.5).mean()), float(np.median(canvas.rough[found[kind] > 0.5])), float(np.median(rough[found[kind] > 0.5]))))


main()
