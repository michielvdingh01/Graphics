"""Brings a character's textures down to one 1K set: colour, normal and roughness.

A model arrives with a texture set per material, often 2K each. Here the UV
layouts of those materials are packed side by side into one square, each scaled
so that a centimetre of surface gets the same number of texels wherever it is
(the head somewhat more, because that is what gets looked at), and the textures
are resampled into it. The layouts themselves stay as they were, only moved and
scaled, so the normal maps stay valid and nothing has to be baked.
"""

import numpy as np

import bpy

SIDE = 1024
GUTTER = 4
# How much sharper the head is than the rest.
HEAD_BOOST = 1.7
HEAD_BONES = ("Head", "Neck", "Jaw", "LeftEye", "RightEye")
CUTOUT_BOOST = 2.0
# Set for FBX and OBJ files. Their materials are from before metalness: the
# importer reads how much a material reflects as how metallic it is, and a
# person in a cotton shirt comes out as polished steel.
LEGACY = False


def pixels(image: bpy.types.Image) -> np.ndarray:
    """An image as rows from the bottom up, RGBA, 0..1 as stored in the file."""
    width, height = image.size
    data = np.empty(width * height * 4, dtype=np.float32)
    image.pixels.foreach_get(data)
    return data.reshape(height, width, 4)


def resize(source: np.ndarray, height: int, width: int) -> np.ndarray:
    """Resamples by averaging the area each new pixel covers, so that going from
    2K to a few hundred pixels does not alias."""
    for axis, size in ((0, height), (1, width)):
        length = source.shape[axis]
        if length == size:
            continue
        total = np.concatenate([np.zeros_like(source.take([0], axis=axis)), np.cumsum(source, axis=axis, dtype=np.float64)], axis=axis)
        edges = np.linspace(0.0, length, size + 1)
        low = np.minimum(edges.astype(np.int64), length - 1)
        part = (edges - low).reshape([-1 if index == axis else 1 for index in range(source.ndim)])
        at = total.take(low, axis=axis) + (total.take(low + 1, axis=axis) - total.take(low, axis=axis)) * part
        source = (np.diff(at, axis=axis) / (length / size)).astype(np.float32)
    return source


def _upstream(socket, channel: str = "RGB"):
    """The image a shader input is fed from, and which channel of it."""
    for link in socket.links:
        node = link.from_node
        if node.type == "TEX_IMAGE" and node.image is not None:
            if link.from_socket.name == "Alpha":
                return node.image, "A"
            return node.image, channel
        if node.type in ("SEPARATE_COLOR", "SEPRGB", "SEPARATE_XYZ"):
            found = _upstream(node.inputs[0], "RGB"[list(node.outputs).index(link.from_socket)])
            if found:
                return found
        for other in node.inputs:
            if other.type in ("RGBA", "VECTOR", "VALUE", "SHADER") and other.is_linked:
                found = _upstream(other, channel)
                if found:
                    return found
    return None


class Source:
    """What one material of the source model is made of."""

    def __init__(self, material: bpy.types.Material):
        self.name = material.name if material else ""
        self.color = self.alpha = self.normal = self.roughness = self.metallic = self.specular = None
        self.base = (0.8, 0.8, 0.8, 1.0)
        self.rough = 0.8
        self.metal = 0.0
        shader = None
        if material is not None and material.node_tree is not None:
            shader = next((node for node in material.node_tree.nodes if node.type == "BSDF_PRINCIPLED"), None)
        if shader is None:
            if material is not None:
                self.base = tuple(material.diffuse_color)
            return
        inputs = shader.inputs
        self.base = tuple(inputs["Base Color"].default_value)
        self.rough = inputs["Roughness"].default_value
        self.metal = inputs["Metallic"].default_value
        self.color = _upstream(inputs["Base Color"])
        self.alpha = _upstream(inputs["Alpha"])
        self.normal = _upstream(inputs["Normal"])
        self.roughness = _upstream(inputs["Roughness"])
        self.metallic = _upstream(inputs["Metallic"])
        self.specular = _upstream(inputs["Specular IOR Level"]) if "Specular IOR Level" in inputs else None
        if LEGACY and self.metallic is None:
            self.metal = 0.0
            # Likewise a material without a gloss map is not a mirror.
            self.rough = max(self.rough, 0.7)

    def size(self) -> tuple:
        for found in (self.color, self.normal, self.roughness, self.specular):
            if found is not None:
                return tuple(found[0].size)
        return (64, 64)


_cache = {}


def _channel(found, fallback: float) -> np.ndarray:
    if found is None:
        return None
    image, channel = found
    if image.name not in _cache:
        _cache[image.name] = pixels(image)
    data = _cache[image.name]
    if channel == "A":
        return data[:, :, 3:4]
    if channel in "RGB" and len(channel) == 1:
        return data[:, :, "RGB".index(channel)][:, :, None]
    return data[:, :, :3]


def _shelves(sizes: list, side: int):
    """Packs rectangles in rows, tallest first; None when they do not fit."""
    order = sorted(range(len(sizes)), key=lambda index: -sizes[index][1])
    places = [None] * len(sizes)
    x = y = GUTTER
    row = 0
    for index in order:
        width, height = sizes[index]
        if x + width + GUTTER > side:
            x = GUTTER
            y += row + GUTTER
            row = 0
        if x + width + GUTTER > side or y + height + GUTTER > side:
            return None
        places[index] = (x, y)
        x += width + GUTTER
        row = max(row, height)
    return places


def rasterize(uv: np.ndarray, side: int):
    """Which triangle covers each texel, and where in it the texel lies.
    uv is (triangles, 3, 2) in texels. Returns the triangle index per texel (-1
    where there is none) and the barycentric coordinates."""
    face = np.full((side, side), -1, dtype=np.int32)
    weights = np.zeros((side, side, 3), dtype=np.float32)
    low = np.clip(np.floor(uv.min(axis=1) - 0.5).astype(int), 0, side - 1)
    high = np.clip(np.ceil(uv.max(axis=1) + 0.5).astype(int), 0, side - 1)
    for index in range(len(uv)):
        (ax, ay), (bx, by), (cx, cy) = uv[index]
        area = (bx - ax) * (cy - ay) - (cx - ax) * (by - ay)
        if abs(area) < 1e-9:
            continue
        x0, y0 = low[index]
        x1, y1 = high[index]
        px = np.arange(x0, x1 + 1, dtype=np.float32)[None, :] + 0.5
        py = np.arange(y0, y1 + 1, dtype=np.float32)[:, None] + 0.5
        w0 = ((bx - px) * (cy - py) - (cx - px) * (by - py)) / area
        w1 = ((cx - px) * (ay - py) - (ax - px) * (cy - py)) / area
        w2 = 1.0 - w0 - w1
        # Half a texel of slack, so the texels a bilinear lookup along an
        # island's edge reaches are filled as well.
        slack = 0.5 * (abs(bx - ax) + abs(cx - bx) + abs(ax - cx) + abs(by - ay) + abs(cy - by) + abs(ay - cy)) / abs(area)
        inside = (w0 >= -slack) & (w1 >= -slack) & (w2 >= -slack)
        strict = (w0 >= 0) & (w1 >= 0) & (w2 >= 0)
        target = face[y0:y1 + 1, x0:x1 + 1]
        write = strict | (inside & (target < 0))
        target[write] = index
        block = weights[y0:y1 + 1, x0:x1 + 1]
        block[write] = np.stack([w0, w1, w2], axis=-1)[write]
    return face, weights


def dilate(image: np.ndarray, covered: np.ndarray, steps: int) -> np.ndarray:
    """Grows the islands outward into the texels nothing covers, so that a
    smaller mip level does not mix the background into an island's edge."""
    image = image.copy()
    covered = covered.copy()
    for _ in range(steps):
        total = np.zeros_like(image)
        count = np.zeros(covered.shape, dtype=np.float32)
        for dy, dx in ((0, 1), (0, -1), (1, 0), (-1, 0), (1, 1), (1, -1), (-1, 1), (-1, -1)):
            moved = np.roll(covered, (dy, dx), axis=(0, 1))
            total += np.roll(image, (dy, dx), axis=(0, 1)) * moved[:, :, None]
            count += moved
        grow = ~covered & (count > 0)
        image[grow] = total[grow] / count[grow][:, None]
        covered |= grow
    return image


class Atlas:
    """The texture set of one character and how its mesh maps onto it."""

    def __init__(self, side: int = SIDE):
        self.side = side
        self.color = np.zeros((side, side, 4), dtype=np.float32)
        self.color[:, :, 3] = 1.0
        self.normal = np.zeros((side, side, 3), dtype=np.float32)
        self.normal[:] = (0.5, 0.5, 1.0)
        self.rough = np.full((side, side), 0.8, dtype=np.float32)
        self.metal = np.zeros((side, side), dtype=np.float32)
        self.face = None
        self.weights = None
        self.cutout = False
        self.notes = {}

    def covered(self) -> np.ndarray:
        return self.face >= 0

    def locate(self, mesh: bpy.types.Mesh) -> None:
        """Works out which triangle of the mesh each texel belongs to."""
        mesh.calc_loop_triangles()
        layer = mesh.uv_layers.active.data
        uv = np.empty(len(layer) * 2, dtype=np.float32)
        layer.foreach_get("uv", uv)
        uv = uv.reshape(-1, 2) * self.side
        loops = np.empty(len(mesh.loop_triangles) * 3, dtype=np.int32)
        mesh.loop_triangles.foreach_get("loops", loops)
        self.triangles = loops.reshape(-1, 3)
        self.face, self.weights = rasterize(uv[self.triangles], self.side)

    def attribute(self, mesh: bpy.types.Mesh, values: np.ndarray) -> np.ndarray:
        """A per-vertex value spread over the texels."""
        corners = np.empty(len(mesh.loops), dtype=np.int32)
        mesh.loops.foreach_get("vertex_index", corners)
        at = values[corners[self.triangles[np.maximum(self.face, 0)]]]
        if at.ndim == 3:
            return (at * self.weights).sum(axis=2)
        return (at * self.weights[:, :, :, None]).sum(axis=2)

    def corner_attribute(self, values: np.ndarray) -> np.ndarray:
        """A per-corner value, such as a tangent, spread over the texels."""
        at = values[self.triangles[np.maximum(self.face, 0)]]
        if at.ndim == 3:
            return (at * self.weights).sum(axis=2)
        return (at * self.weights[:, :, :, None]).sum(axis=2)

    def positions(self, mesh: bpy.types.Mesh) -> np.ndarray:
        co = np.empty(len(mesh.vertices) * 3, dtype=np.float32)
        mesh.vertices.foreach_get("co", co)
        return self.attribute(mesh, co.reshape(-1, 3))

    def normals(self, mesh: bpy.types.Mesh) -> np.ndarray:
        normal = np.empty(len(mesh.vertices) * 3, dtype=np.float32)
        mesh.vertex_normals.foreach_get("vector", normal)
        at = self.attribute(mesh, normal.reshape(-1, 3))
        return at / np.maximum(np.linalg.norm(at, axis=2, keepdims=True), 1e-6)

    def finish(self) -> None:
        """Fills the texels around the islands."""
        covered = self.covered()
        self.color = dilate(self.color, covered, 8)
        self.normal = dilate(self.normal, covered, 8)
        packed = dilate(np.stack([self.rough, self.metal], axis=-1), covered, 8)
        self.rough, self.metal = packed[:, :, 0], packed[:, :, 1]

    def material(self, obj: bpy.types.Object, name: str, folder: str) -> dict:
        """Writes the three textures and gives the mesh the material that uses them."""
        color = self.color.copy()
        if not self.cutout:
            color[:, :, 3] = 1.0
        orm = np.ones((self.side, self.side, 4), dtype=np.float32)
        orm[:, :, 1] = self.rough
        orm[:, :, 2] = self.metal
        normal = np.ones((self.side, self.side, 4), dtype=np.float32)
        normal[:, :, :3] = self.normal
        images = {
            "color": _save(name + "_color", color, folder, "PNG" if self.cutout else "JPEG", True),
            "normal": _save(name + "_normal", normal, folder, "PNG", False),
            "orm": _save(name + "_orm", orm, folder, "JPEG", False),
        }
        mesh = obj.data
        used = [obj.material_slots[polygon.material_index].name.endswith("#cutout") if obj.material_slots else False for polygon in mesh.polygons]
        mesh.materials.clear()
        mesh.materials.append(_material(name, images, False))
        if self.cutout and any(used):
            mesh.materials.append(_material(name + "_cutout", images, True))
            mesh.polygons.foreach_set("material_index", [1 if cut else 0 for cut in used])
        else:
            mesh.polygons.foreach_set("material_index", [0] * len(mesh.polygons))
        mesh.update()
        return {key: image.filepath_raw for key, image in images.items()}


def _save(name: str, data: np.ndarray, folder: str, kind: str, srgb: bool) -> bpy.types.Image:
    side = data.shape[0]
    image = bpy.data.images.new(name, side, side, alpha=kind == "PNG" and srgb)
    image.colorspace_settings.name = "sRGB" if srgb else "Non-Color"
    image.pixels.foreach_set(np.clip(data, 0.0, 1.0).astype(np.float32).ravel())
    image.filepath_raw = "%s/%s.%s" % (folder, name, "png" if kind == "PNG" else "jpg")
    image.file_format = kind
    image.save(quality=92)
    image.source = "FILE"
    image.reload()
    return image


def _material(name: str, images: dict, cutout: bool) -> bpy.types.Material:
    material = bpy.data.materials.new(name)
    if material.node_tree is None:
        material.use_nodes = True
    nodes, links = material.node_tree.nodes, material.node_tree.links
    shader = next(node for node in nodes if node.type == "BSDF_PRINCIPLED")

    def texture(key: str):
        node = nodes.new("ShaderNodeTexImage")
        node.image = images[key]
        return node

    color = texture("color")
    links.new(color.outputs["Color"], shader.inputs["Base Color"])
    if cutout:
        # The exporter reads an alpha that is rounded as a cutout at 0.5.
        snap = nodes.new("ShaderNodeMath")
        snap.operation = "ROUND"
        links.new(color.outputs["Alpha"], snap.inputs[0])
        links.new(snap.outputs[0], shader.inputs["Alpha"])
    bump = nodes.new("ShaderNodeNormalMap")
    links.new(texture("normal").outputs["Color"], bump.inputs["Color"])
    links.new(bump.outputs["Normal"], shader.inputs["Normal"])
    split = nodes.new("ShaderNodeSeparateColor")
    links.new(texture("orm").outputs["Color"], split.inputs[0])
    links.new(split.outputs[1], shader.inputs["Roughness"])
    links.new(split.outputs[2], shader.inputs["Metallic"])
    material.use_backface_culling = True
    return material


def pack(obj: bpy.types.Object, side: int = SIDE) -> Atlas:
    """Moves the UVs of every material of the mesh into one square and
    resamples the textures to match."""
    mesh = obj.data
    atlas = Atlas(side)
    count = len(mesh.polygons)
    material_of = np.empty(count, dtype=np.int32)
    mesh.polygons.foreach_get("material_index", material_of)
    area = np.empty(count, dtype=np.float32)
    mesh.polygons.foreach_get("area", area)
    start = np.empty(count, dtype=np.int32)
    total = np.empty(count, dtype=np.int32)
    mesh.polygons.foreach_get("loop_start", start)
    mesh.polygons.foreach_get("loop_total", total)
    if not (total == 3).all():
        raise ValueError("the mesh has to be triangulated before its textures are packed")
    layer = mesh.uv_layers.active.data
    uv = np.empty(len(layer) * 2, dtype=np.float64)
    layer.foreach_get("uv", uv)
    uv = uv.reshape(-1, 2)
    corners = start[:, None] + np.arange(3)[None, :]

    # A face that lies in another tile of a repeating texture is moved back
    # into the first one.
    tile = np.floor(uv[corners].mean(axis=1) + 1e-6)
    uv[corners] -= tile[:, None, :]
    uv = np.clip(uv, 0.0, 1.0)

    head = _head_share(obj, mesh, corners)
    slots = [slot.material for slot in obj.material_slots] or [None]
    sources = [Source(material) for material in slots]
    entries = []
    for index, source in enumerate(sources):
        faces = np.nonzero(material_of == index)[0]
        if len(faces) == 0:
            continue
        width, height = source.size()
        own = uv[corners[faces]]
        low = np.maximum(own.reshape(-1, 2).min(axis=0) - 2.0 / np.array([width, height]), 0.0)
        high = np.minimum(own.reshape(-1, 2).max(axis=0) + 2.0 / np.array([width, height]), 1.0)
        edge1 = own[:, 1] - own[:, 0]
        edge2 = own[:, 2] - own[:, 0]
        # UV area in units where the texture is as tall as 1.
        covered = 0.5 * np.abs(edge1[:, 0] * edge2[:, 1] - edge1[:, 1] * edge2[:, 0]).sum() * (width / height)
        surface = float(area[faces].sum())
        boost = 1.0 + (HEAD_BOOST - 1.0) * float((area[faces] * head[faces]).sum() / max(surface, 1e-9))
        if source.alpha is not None:
            # Cards of hair lie over each other on the texture, and their
            # outline is all there is to them.
            boost *= CUTOUT_BOOST
        entries.append({
            "source": source, "faces": faces, "low": low, "high": high, "aspect": width / height,
            # Texels per UV unit for one texel per metre of surface.
            "rate": np.sqrt(surface / max(covered, 1e-9)) * boost,
            "limit": float(height),
        })
        if source.alpha is not None:
            atlas.cutout = True

    def sizes(density: float) -> list:
        result = []
        for entry in entries:
            scale = min(entry["rate"] * density, entry["limit"])
            span = entry["high"] - entry["low"]
            result.append((max(int(round(span[0] * scale * entry["aspect"])), 2), max(int(round(span[1] * scale)), 2)))
        return result

    low, high = 1.0, 20000.0
    for _ in range(40):
        middle = (low + high) / 2
        if _shelves(sizes(middle), side) is None:
            high = middle
        else:
            low = middle
    density = low
    places = _shelves(sizes(density), side)
    if places is None:
        raise ValueError("the textures do not fit the atlas")

    for entry, (width, height), (x, y) in zip(entries, sizes(density), places):
        source = entry["source"]
        span = entry["high"] - entry["low"]
        faces = entry["faces"]
        own = uv[corners[faces]]
        uv[corners[faces]] = (np.array([x, y]) + (own - entry["low"]) / span * np.array([width, height])) / side

        def crop(data: np.ndarray) -> np.ndarray:
            rows, columns = data.shape[:2]
            x0, x1 = int(entry["low"][0] * columns), max(int(np.ceil(entry["high"][0] * columns)), 1)
            y0, y1 = int(entry["low"][1] * rows), max(int(np.ceil(entry["high"][1] * rows)), 1)
            return resize(data[y0:y1, x0:x1], height, width)

        target = (slice(y, y + height), slice(x, x + width))
        color = _channel(source.color, 0.0)
        atlas.color[target][:, :, :3] = crop(color) if color is not None else np.array(source.base[:3])
        alpha = _channel(source.alpha, 1.0)
        if alpha is not None:
            atlas.color[target][:, :, 3] = crop(alpha)[:, :, 0]
        normal = _channel(source.normal, 0.5)
        if normal is not None:
            atlas.normal[target] = crop(normal)
        rough = _channel(source.roughness, source.rough)
        specular = _channel(source.specular, 0.5)
        if rough is not None:
            atlas.rough[target] = crop(rough)[:, :, 0]
            origin = "source"
        elif specular is not None:
            # An old-style specular map: what shines is smooth.
            shine = crop(specular).mean(axis=2)
            atlas.rough[target] = np.clip(0.95 - 0.75 * shine, 0.25, 1.0)
            origin = "derived from the specular map"
        else:
            atlas.rough[target] = source.rough
            origin = "one value per material"
        metal = _channel(source.metallic, source.metal)
        atlas.metal[target] = crop(metal)[:, :, 0] if metal is not None else source.metal
        atlas.notes.setdefault("roughness", origin)
        atlas.notes.setdefault("normal", "source" if normal is not None else "flat")
        atlas.notes.setdefault("color", "source" if color is not None else "one colour per material")

    flat = np.empty(len(layer) * 2, dtype=np.float32)
    flat[:] = uv.ravel()
    layer.foreach_set("uv", flat)
    # material() needs to know afterwards which faces were see-through.
    for slot, source in zip(obj.material_slots, sources):
        if source.alpha is not None and slot.material is not None:
            slot.material.name = slot.material.name + "#cutout"
    atlas.notes["texels_per_cm"] = round(density / 100.0, 2)
    atlas.notes["source_textures"] = sorted({"%dx%d" % entry["source"].size() for entry in entries})
    _cache.clear()
    atlas.locate(mesh)
    return atlas


def _head_share(obj: bpy.types.Object, mesh: bpy.types.Mesh, corners: np.ndarray) -> np.ndarray:
    """How much of each face hangs on the head, 0..1."""
    indices = {group.index for group in obj.vertex_groups if group.name in HEAD_BONES}
    share = np.zeros(len(mesh.vertices), dtype=np.float32)
    if indices:
        for vertex in mesh.vertices:
            share[vertex.index] = sum(element.weight for element in vertex.groups if element.group in indices)
    loops = np.empty(len(mesh.loops), dtype=np.int32)
    mesh.loops.foreach_get("vertex_index", loops)
    return share[loops[corners]].mean(axis=1)


def sample(data: np.ndarray, uv: np.ndarray) -> np.ndarray:
    """Looks an image up at UV coordinates, between its pixels, repeating at the edges."""
    rows, columns = data.shape[:2]
    x = uv[:, 0] * columns - 0.5
    y = uv[:, 1] * rows - 0.5
    x0 = np.floor(x).astype(np.int64)
    y0 = np.floor(y).astype(np.int64)
    fx = (x - x0)[:, None].astype(np.float32)
    fy = (y - y0)[:, None].astype(np.float32)
    x1, y1 = (x0 + 1) % columns, (y0 + 1) % rows
    x0, y0 = x0 % columns, y0 % rows
    low = data[y0, x0] * (1 - fx) + data[y0, x1] * fx
    high = data[y1, x0] * (1 - fx) + data[y1, x1] * fx
    return low * (1 - fy) + high * fy
