#!/usr/bin/env python3
"""Gives every file of this checkout that Git tracks and that is the same as in
another checkout the modification time it has there:

    tools/match_times.py <other checkout>

A new worktree starts with a copy of the import cache of the main checkout
(see CLAUDE.md), but its files are as new as the checkout. Godot sees a newer
file and imports it again, minutes per lightmap. The same as the `touch -r`
loop in CLAUDE.md, in one process: on Windows that loop starts two programs
for each of the four thousand files and takes minutes.
"""
import os
import subprocess
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))


def main():
    if len(sys.argv) != 2 or not os.path.isdir(sys.argv[1]):
        sys.exit(__doc__)
    other = sys.argv[1]
    names = subprocess.run(["git", "-C", ROOT, "ls-files", "-z"], capture_output=True, check=True).stdout.decode().split("\0")
    same = differ = 0
    for name in names:
        ours, theirs = os.path.join(ROOT, name), os.path.join(other, name)
        if not name or not os.path.isfile(ours) or not os.path.isfile(theirs):
            continue
        if os.path.getsize(ours) == os.path.getsize(theirs):
            with open(ours, "rb") as a, open(theirs, "rb") as b:
                if a.read() == b.read():
                    stat = os.stat(theirs)
                    os.utime(ours, ns=(stat.st_atime_ns, stat.st_mtime_ns))
                    same += 1
                    continue
        differ += 1
    print("%d files took the time of %s, %d differ" % (same, other, differ))


if __name__ == "__main__":
    main()
