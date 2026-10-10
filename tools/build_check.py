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
import os
import re
import subprocess
import sys
import tempfile

from scene_text import Scene

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


def canonical(text, whatever_the_order=False):
    return Scene(text).canonical(BUILD_ORDER if whatever_the_order else ())


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
