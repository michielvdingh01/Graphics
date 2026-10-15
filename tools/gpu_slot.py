#!/usr/bin/env python3
"""The GPU slot of tools/gpu_slot.sh for Windows, where there is no lockf:
    python3 tools/gpu_slot.py command [arguments]

Takes the slot, runs the command and frees the slot when it ends. The slot is
a lock on a file that every checkout shares, %APPDATA%/Godot/gpu-slot.lock;
Windows lets go of it the moment this process is gone, however it went. Next
to it, in gpu-slot, stands who has it. GPU_SLOT and GPU_SLOT_WAIT work as in
tools/gpu_slot.sh, which starts this.
"""
import msvcrt
import os
import subprocess
import sys
import time

import host

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))


def main():
    if len(sys.argv) < 2:
        sys.exit("usage: tools/gpu_slot.sh command [arguments]")
    argv = sys.argv[1:]
    slot = os.environ.get("GPU_SLOT") or os.path.join(os.environ["APPDATA"], "Godot", "gpu-slot")
    wait = float(os.environ.get("GPU_SLOT_WAIT", "1800"))
    os.makedirs(os.path.dirname(slot), exist_ok=True)

    def holder():
        try:
            with open(slot, encoding="utf-8") as said:
                return said.read().strip()
        except OSError:
            return "nobody says"

    lock = open(slot + ".lock", "a+b")

    def take():
        try:
            lock.seek(0)
            msvcrt.locking(lock.fileno(), msvcrt.LK_NBLCK, 1)
            return True
        except OSError:
            return False

    if not take():
        print("Waiting for the GPU slot, which has: %s" % holder(), file=sys.stderr)
        until = time.monotonic() + wait
        while not take():
            if time.monotonic() > until:
                print("Gave up after %d s of waiting for the GPU slot, which has: %s" % (wait, holder()), file=sys.stderr)
                return 75
            time.sleep(1.0)
    # Who has it, for whoever waits: the command without the path to it.
    shown = " ".join([os.path.basename(argv[0])] + argv[1:])[:200]
    with open(slot, "w", encoding="utf-8") as said:
        said.write("pid %d since %s, from %s: %s\n" % (os.getpid(), time.strftime("%H:%M:%S"), ROOT.replace("\\", "/"), shown))
    try:
        done = subprocess.run(host.command(argv), env=dict(os.environ, GPU_SLOT_HELD="1"))
    except KeyboardInterrupt:
        return 130
    return done.returncode


if __name__ == "__main__":
    sys.exit(main())
