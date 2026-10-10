#!/usr/bin/env python3
"""Rebuilds the levels and the models and says what came out differently from
what is committed. The way to know that a change to a builder, to the kit or
to the way a level is cut into files changed nothing that it should not have:

    tools/build_check.py              every level and every model
    tools/build_check.py factory      only that level

Meshes are compared byte for byte. A scene is compared by what is in it: the
ids Godot hands out afresh on every save do not count. A file that came out
the same is put back as it was committed, so that what is left in
`git status` is what really changed. A level whose meshes changed needs its
lightmaps baked again.

A level with the same colliders in another order counts as changed, and is
reported as such. They are filed in the order they were built in, and that
order shifts where every ray of the physics engine lands by a hair, which is
enough for the robots to pick other cover: tools/selftest.sh --fights can
come out differently.

Exits with 1 when anything changed in substance.
"""
import hashlib
import os
import re
import subprocess
import sys
import tempfile

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
GODOT = os.environ.get("GODOT", "/Applications/Godot.app/Contents/MacOS/Godot")
# Nodes whose children are filed in the order they were built in: the
# colliders in the body of a level and the bodies of what explodes.
BUILD_ORDER = {"Collision", "Explosives"}
NOISE = re.compile(r"RID allocations|Leaked instance|^ *at: |resources still in use|ObjectDB instances|PagedAllocator")


def run(command):
    """Runs a builder and passes on what it has to say about itself."""
    done = subprocess.run(command, cwd=ROOT, capture_output=True, text=True)
    for line in (done.stdout + done.stderr).splitlines():
        if re.search(r"ERROR|WARNING|error", line) and not NOISE.search(line):
            print("  " + line)


def git(*args, binary=False):
    return subprocess.run(["git", *args], cwd=ROOT, capture_output=True, text=not binary, check=True).stdout


def without_ids(text):
    return re.sub(r" unique_id=\d+", "", text)


def canonical(text, whatever_the_order=False):
    """A text scene with every reference followed to what it refers to. With
    `whatever_the_order`, the children of the nodes in BUILD_ORDER are
    nameless and sorted."""
    ext, sub, nodes, rest = {}, {}, [], []
    block = None
    for line in text.split("\n"):
        if line.startswith("[") and not line.startswith("[["):
            block = [line]
            if line.startswith("[ext_resource"):
                ext[re.search(r' id="([^"]+)"', line).group(1)] = re.search(r' path="([^"]+)"', line).group(1)
            elif line.startswith("[sub_resource"):
                sub[re.search(r' id="([^"]+)"', line).group(1)] = block
            elif line.startswith("[node"):
                nodes.append(block)
            elif not line.startswith("[gd_scene"):
                rest.append(block)
        elif block is not None and line.strip():
            block.append(line)
    inlined = {}

    def follow(line):
        line = re.sub(r'ExtResource\("([^"]+)"\)', lambda m: 'Ext("%s")' % ext[m.group(1)], line)
        return re.sub(r'SubResource\("([^"]+)"\)', lambda m: "Sub(%s)" % inline(m.group(1)), line)

    def inline(key):
        if key not in inlined:
            kind = re.search(r'type="([^"]+)"', sub[key][0]).group(1)
            body = kind + "{" + ";".join(follow(line) for line in sub[key][1:]) + "}"
            inlined[key] = body if len(body) < 200 else kind + "#" + hashlib.sha1(body.encode()).hexdigest()[:16]
        return inlined[key]

    tree = {}
    for block in nodes:
        head = without_ids(block[0])
        name = re.search(r'name="([^"]+)"', head).group(1)
        parent = re.search(r' parent="([^"]+)"', head)
        path = "." if parent is None else name if parent.group(1) == "." else parent.group(1) + "/" + name
        tree[path] = {"head": follow(head), "lines": [follow(line) for line in block[1:]], "children": []}
        if parent is not None:
            tree[parent.group(1)]["children"].append(path)

    def dump(path, depth=0):
        # depth: how far below a node of BUILD_ORDER this one hangs, 0 for not at all.
        node = tree[path]
        head = node["head"]
        if depth:
            head = re.sub(r' parent="[^"]+"', "", head)
        if depth == 1:
            head = re.sub(r'name="[^"]+"', 'name="*"', head)
        below = depth + 1 if depth else 1 if whatever_the_order and path in BUILD_ORDER else 0
        children = [dump(child, below) for child in node["children"]]
        if below == 1:
            children.sort()
        return "\n".join([head] + node["lines"] + children)

    return dump(".") + "\n" + "\n".join(sorted("\n".join(follow(line) for line in block) for block in rest))


def first_differences(old, new, limit=3):
    a, b = old.split("\n"), new.split("\n")
    out = []
    for i in range(min(len(a), len(b))):
        if a[i] != b[i]:
            out += ["      was  " + a[i][:160], "      is   " + b[i][:160]]
            if len(out) >= limit * 2:
                break
    return out or ["      %d lines against %d" % (len(a), len(b))]


def main():
    wanted = sys.argv[1:]
    levels = wanted or sorted(f[:-3] for f in os.listdir(os.path.join(ROOT, "tools/levels")) if f.endswith(".gd"))
    for level in levels:
        print("Building %s" % level)
        run(["tools/build_level.sh", level])
    if not wanted:
        print("Building the models")
        run(["tools/build_model.sh"])

    changed = []
    for line in git("status", "--porcelain", "--", "scenes/levels", "scenes/models").splitlines():
        changed.append((line[:2].strip(), line[3:]))

    # Models are saved as binary scenes: have Godot write both versions as text.
    scratch = tempfile.mkdtemp(prefix="build_check_")
    pairs = []
    for state, path in changed:
        if state == "M" and path.endswith(".scn"):
            stem = os.path.join(scratch, os.path.basename(path)[:-4])
            open(stem + "_was.scn", "wb").write(git("show", "HEAD:" + path, binary=True))
            pairs += [stem + "_was.scn", stem + "_was.tscn", os.path.join(ROOT, path), stem + "_is.tscn"]
    if pairs:
        run([GODOT, "--headless", "--path", ".", "--script", "tools/scene_as_text.gd", "--", *pairs])

    substance, same = 0, 0
    for state, path in changed:
        if state != "M":
            substance += 1
            print("  %s  %s" % ("new    " if state == "??" else "gone   ", path))
            continue
        if path.endswith(".tscn"):
            was, now = git("show", "HEAD:" + path), open(os.path.join(ROOT, path)).read()
        elif path.endswith(".scn"):
            stem = os.path.join(scratch, os.path.basename(path)[:-4])
            was, now = open(stem + "_was.tscn").read(), open(stem + "_is.tscn").read()
        else:
            substance += 1
            print("  changed  %s" % path)
            continue
        a, b = canonical(was), canonical(now)
        if a == b:
            same += 1
            git("checkout", "--", path)
            continue
        substance += 1
        if canonical(was, True) == canonical(now, True):
            print("  changed  %s: the same colliders in another order; fights may go differently" % path)
        else:
            print("  changed  %s" % path)
            print("\n".join(first_differences(a, b)))
    print("%d files came out the same and were put back." % same if same else "", end="\n" if same else "")
    print("Nothing changed in substance." if not substance else "%d files changed in substance." % substance)
    return 1 if substance else 0


if __name__ == "__main__":
    sys.exit(main())
