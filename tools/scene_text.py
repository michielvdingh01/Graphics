"""Reads a Godot text scene (.tscn) for the tools that compare what the
builders wrote (build_check.py) and that decide what has to be baked
(bake_lightmaps.py).

A scene is read into its nodes, by path, with every reference to another
resource followed to what it refers to: a path for a file, the contents for a
resource inside the scene. The ids Godot hands out afresh on every save are
left out, so that two saves of the same scene read the same.
"""
import hashlib
import re


def without_ids(text):
    return re.sub(r" unique_id=\d+", "", text)


class Scene:
    def __init__(self, text):
        self.ext = {}  # id -> path of the file
        self.sub = {}  # id -> the lines of a resource inside the scene
        self.nodes = {}  # path -> {head, kind, lines, children}, in the order of the file
        self.rest = []
        self._inlined = {}
        blocks = []
        block = None
        for line in text.split("\n"):
            if line.startswith("[") and not line.startswith("[["):
                block = [line]
                blocks.append(block)
            elif block is not None and line.strip():
                block.append(line)
        for block in blocks:
            head = block[0]
            if head.startswith("[ext_resource"):
                self.ext[re.search(r' id="([^"]+)"', head).group(1)] = re.search(r' path="([^"]+)"', head).group(1)
            elif head.startswith("[sub_resource"):
                self.sub[re.search(r' id="([^"]+)"', head).group(1)] = block
        for block in blocks:
            head = block[0]
            if head.startswith("[node"):
                head = without_ids(head)
                name = re.search(r'name="([^"]+)"', head).group(1)
                parent = re.search(r' parent="([^"]+)"', head)
                kind = re.search(r' type="([^"]+)"', head)
                path = "." if parent is None else name if parent.group(1) == "." else parent.group(1) + "/" + name
                self.nodes[path] = {
                    "head": self.follow(head),
                    "kind": kind.group(1) if kind else "",
                    "instance": " instance=" in head,
                    "lines": [self.follow(line) for line in block[1:]],
                    "raw": block[1:],
                    "children": [],
                }
                if parent is not None and parent.group(1) in self.nodes:
                    self.nodes[parent.group(1)]["children"].append(path)
            elif not head.startswith(("[gd_scene", "[ext_resource", "[sub_resource")):
                self.rest.append("\n".join(self.follow(line) for line in block))

    def follow(self, line):
        """A line with its references replaced by what they refer to."""
        line = re.sub(r'ExtResource\("([^"]+)"\)', lambda m: 'Ext("%s")' % self.ext[m.group(1)], line)
        return re.sub(r'SubResource\("([^"]+)"\)', lambda m: "Sub(%s)" % self.inline(m.group(1)), line)

    def inline(self, key):
        """The contents of a resource inside the scene, or a hash of them."""
        if key not in self._inlined:
            kind = re.search(r'type="([^"]+)"', self.sub[key][0]).group(1)
            body = kind + "{" + ";".join(self.follow(line) for line in self.sub[key][1:]) + "}"
            self._inlined[key] = body if len(body) < 200 else kind + "#" + hashlib.sha1(body.encode()).hexdigest()[:16]
        return self._inlined[key]

    def below(self, path):
        """The paths of a node and of everything under it, in the order of the file."""
        if path == ".":
            return list(self.nodes)
        return [p for p in self.nodes if p == path or p.startswith(path + "/")]

    def canonical(self, build_order=()):
        """The whole scene as text. The children of the nodes named in
        `build_order` come out nameless and sorted: for comparing two scenes
        whatever order those were filed in."""

        def dump(path, depth=0):
            # depth: how far below a node of build_order this one hangs, 0 for not at all.
            node = self.nodes[path]
            head = node["head"]
            if depth:
                head = re.sub(r' parent="[^"]+"', "", head)
            if depth == 1:
                head = re.sub(r'name="[^"]+"', 'name="*"', head)
            below = depth + 1 if depth else 1 if path in build_order else 0
            children = [dump(child, below) for child in node["children"]]
            if below == 1:
                children.sort()
            return "\n".join([head] + node["lines"] + children)

        return dump(".") + "\n" + "\n".join(sorted(self.rest))
