#!/usr/bin/env python3
"""Clones into the import cache of this checkout what another checkout has
already imported.

    tools/clone_imports.py <other checkout>           clone what is missing or stale here
    tools/clone_imports.py <other checkout> --list    only say what that would be

A branch that brings lightmaps, models or textures brings their sources, not
what Godot made of them: that is in .godot/imported/, outside Git. A checkout
that merges such a branch has the editor import them all again, minutes per
lightmap on every core, and until then a game that is started without the
editor loads what the cache still holds: the lightmap of before on the walls
of after. The worktree the branch was built in has every one of them.

Of each imported file that is missing here, or that was made of another
version of its source than the one this checkout has now, the copy of the
other checkout is taken when that one was made of this version: the checksum
Godot keeps next to an imported file says of what. The copies are clones
(cp -c), which take no room on the disk.

The editor keeps a list of its own, .godot/editor/filesystem_cache10, with of
every source the checksum of its .import file as it was when it was imported.
Where a branch changed an .import file, a lightmap with another number of
layers for one, the editor imports again whatever the cache holds. So the
line of such a source is taken from the other checkout's list as well, when
it was written for the .import file that is here now. That only helps with
the editor of this checkout closed: an open one goes by what it has in memory
and writes its list over this one. Nothing else is touched.
"""
import hashlib
import os
import re
import subprocess
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
CACHE = ".godot/imported"
EDITOR_LIST = ".godot/editor/filesystem_cache10"


def checksum(path):
    """What Godot wrote of the source next to an imported file: its md5, or None."""
    try:
        found = re.search(r'source_md5="([0-9a-f]+)"', open(path).read())
    except OSError:
        return None
    return found.group(1) if found else None


def md5_of(path):
    digest = hashlib.md5()
    with open(path, "rb") as source:
        for piece in iter(lambda: source.read(1 << 20), b""):
            digest.update(piece)
    return digest.hexdigest()


def imports():
    """Every .import file of this checkout: what Git tracks, or without Git what is there."""
    listed = subprocess.run(["git", "-C", ROOT, "ls-files", "-z", "*.import"], capture_output=True, text=True)
    if listed.returncode == 0:
        return listed.stdout.split("\0")
    found = []
    for folder, folders, files in os.walk(ROOT):
        # Not the cache itself, and not the worktrees of others under .claude.
        folders[:] = [name for name in folders if not name.startswith(".")]
        found += [os.path.relpath(os.path.join(folder, name), ROOT) for name in files if name.endswith(".import")]
    return found


def clone(source, target):
    if os.path.exists(target):
        os.remove(target)
    subprocess.run(["cp", "-c", source, target], check=True)


def editor_list(checkout):
    """The editor's list of a checkout: its lines, and where the line of each source is."""
    try:
        lines = open(os.path.join(checkout, EDITOR_LIST)).read().split("\n")
    except OSError:
        return None, {}
    where = {}
    folder = None
    for i, line in enumerate(lines):
        if line.startswith("::"):
            folder = line.split("::")[1]
        elif folder is not None and "::" in line:
            where[folder + line.split("::", 1)[0]] = i
    return lines, where


def open_editor():
    """The editor that has this checkout open, as ps shows it, or None."""
    said = subprocess.run(["ps", "-axo", "pid=,ucomm=,args="], capture_output=True, text=True).stdout
    for line in said.splitlines():
        pid, program, started = (line.split(None, 2) + ["", ""])[:3]
        # Not a tool's run (tools/godot.sh gives those no sound) and not the
        # game the editor started, which reports back to it.
        if program not in ("Godot", "(Godot)") or "--headless" in started or "--audio-driver Dummy" in started or "--remote-debug" in started:
            continue
        at = subprocess.run(["lsof", "-a", "-p", pid, "-d", "cwd", "-Fn"], capture_output=True, text=True).stdout
        places = [found[1:] for found in at.splitlines() if found.startswith("n")]
        places += re.findall(r"--path\s+(\S+)", started)
        if any(os.path.isdir(place) and os.path.samefile(place, ROOT) for place in places):
            return "%s %s" % (pid, started[:80])
    return None


def main():
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    flags = {a for a in sys.argv[1:] if a.startswith("--")}
    if len(args) != 1 or flags - {"--list"}:
        sys.exit(__doc__)
    only_list = "--list" in flags
    other = os.path.abspath(args[0])
    if not os.path.isdir(os.path.join(other, CACHE)):
        sys.exit("%s has no import cache: there is no %s in it." % (other, CACHE))
    if os.path.samefile(other, ROOT):
        sys.exit("That is this checkout.")
    os.makedirs(os.path.join(ROOT, CACHE), exist_ok=True)
    ours_list, ours_at = editor_list(ROOT)
    theirs_list, theirs_at = editor_list(other)
    taken = []
    size = 0
    not_there = []
    lines = []
    for listed in imports():
        if not listed:
            continue
        text = open(os.path.join(ROOT, listed)).read()
        source = re.search(r'source_file="res://([^"]+)"', text)
        files = re.search(r"dest_files=\[([^\]]*)\]", text)
        if not source or not files or not os.path.isfile(os.path.join(ROOT, source.group(1))):
            continue
        made = [path[len("res://"):] for path in re.findall(r'"(res://[^"]+)"', files.group(1))]
        if not made:
            continue
        # The editor's line of this source, when it was written for another
        # .import file than the one here and the other checkout's for this one.
        name = "res://" + source.group(1)
        if ours_list and theirs_list and name in ours_at and name in theirs_at:
            written_for = "<>%s<>" % md5_of(os.path.join(ROOT, listed))
            if written_for not in ours_list[ours_at[name]] and written_for in theirs_list[theirs_at[name]]:
                lines.append(name)
        # One checksum for all that was made of a source: the name they share,
        # up to the hash of where the source is.
        stem = re.match(r"(.*-[0-9a-f]{32})\.", made[0])
        if not stem:
            continue
        sum_file = stem.group(1) + ".md5"
        theirs = checksum(os.path.join(other, sum_file))
        ours = checksum(os.path.join(ROOT, sum_file))
        whole = all(os.path.isfile(os.path.join(ROOT, path)) for path in made)
        if whole and ours == theirs:
            # The same import in both, or no checksum in either: nothing to
            # gain, whatever it was made of.
            continue
        now = md5_of(os.path.join(ROOT, source.group(1)))
        if whole and ours == now:
            continue
        if theirs != now or not all(os.path.isfile(os.path.join(other, path)) for path in made):
            not_there.append(source.group(1))
            continue
        for path in made + [sum_file]:
            size += os.path.getsize(os.path.join(other, path))
            if not only_list:
                clone(os.path.join(other, path), os.path.join(ROOT, path))
        taken.append(source.group(1))

    for name in taken:
        print(("would clone  " if only_list else "cloned  ") + name)
    for name in not_there:
        print("not there   " + name)
    print("%s what Godot made of %d sources, %.0f MB%s." % (
        "Would clone" if only_list else "Cloned", len(taken), size / 1e6,
        "; %d more are missing or stale here and were not made of this version there either: the editor imports those" % len(not_there) if not_there else ""))

    if not lines:
        return 0
    if ours_list[0] != theirs_list[0]:
        print("The editor's list of %s was written with other settings: %d sources whose .import file changed will be imported again." % (other, len(lines)))
        return 0
    editor = open_editor()
    if editor:
        print("The editor has this checkout open (%s): it will import %d sources again whose .import file changed. Close it and run this again to prevent that." % (editor, len(lines)))
        return 0
    if only_list:
        print("Would take the editor's line of %d sources whose .import file changed." % len(lines))
        return 0
    for name in lines:
        ours_list[ours_at[name]] = theirs_list[theirs_at[name]]
    aside = os.path.join(ROOT, EDITOR_LIST + ".new")
    with open(aside, "w") as out:
        out.write("\n".join(ours_list))
    os.replace(aside, os.path.join(ROOT, EDITOR_LIST))
    print("Took the editor's line of %d sources whose .import file changed." % len(lines))
    return 0


if __name__ == "__main__":
    sys.exit(main())
