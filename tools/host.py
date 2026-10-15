"""What differs between the MacBook and the ASUS, for the Python tools.

The tools were written on macOS. On Windows they run from Git Bash, which
starts a shell script by itself but leaves Python unable to: a .sh file is no
program to Windows. Processes are listed differently, there is no clone that
takes no room on the disk, and the fonts live somewhere else. What a tool
needs of that it takes from here, so that it reads the same on both.
"""
import os
import re
import shutil
import subprocess
import sys

WINDOWS = os.name == "nt"

FONT = "C:/Windows/Fonts/arial.ttf" if WINDOWS else "/System/Library/Fonts/Supplemental/Arial.ttf"


def shell():
    """The sh of Git for Windows, which runs the tools' shell scripts."""
    found = shutil.which("sh")
    if found:
        return found
    git = subprocess.run(["git", "--exec-path"], capture_output=True, text=True).stdout.strip()
    # .../Git/mingw64/libexec/git-core -> .../Git/usr/bin/sh.exe
    return os.path.normpath(os.path.join(git, "..", "..", "..", "usr", "bin", "sh.exe"))


def command(argv):
    """`argv` as Windows can start it: a shell script goes through sh."""
    argv = [str(a) for a in argv]
    if WINDOWS and argv and argv[0].endswith(".sh"):
        return [shell()] + argv
    return argv


def replace_with(argv):
    """Runs `argv` in place of this process. Windows has no such thing, and
    its os.execv returns to whoever started this before the new one is done:
    there it waits for `argv` and exits with its status."""
    if WINDOWS:
        sys.stdout.flush()
        sys.exit(subprocess.run(command(argv)).returncode)
    os.execv(argv[0], argv)


def processes():
    """Every running process: (pid, program, how it was started). The program
    is its name without folder or .exe, and a Godot is "Godot" on both
    machines. On Windows the console Godot that only passes the output of the
    real one on is left out."""
    found = []
    if not WINDOWS:
        listed = subprocess.run(["ps", "-axo", "pid=,ucomm=,args="], capture_output=True, text=True).stdout
        for line in listed.splitlines():
            pid, program, started = (line.split(None, 2) + ["", ""])[:3]
            found.append((pid, program, started))
        return found
    script = "Get-CimInstance Win32_Process | ForEach-Object { '{0}`t{1}`t{2}' -f $_.ProcessId, $_.Name, $_.CommandLine }"
    listed = subprocess.run(["powershell", "-NoProfile", "-NonInteractive", "-Command", script], capture_output=True, text=True).stdout
    for line in listed.splitlines():
        pid, name, started = (line.split("\t", 2) + ["", ""])[:3]
        program = re.sub(r"\.exe$", "", name, flags=re.IGNORECASE)
        if program.lower().startswith("godot"):
            if program.lower().endswith("_console"):
                continue
            program = "Godot"
        found.append((pid, program, started))
    return found


def clone(source, target):
    """A copy of `source` at `target`: on macOS a clone that takes no room, on
    Windows an ordinary copy."""
    if WINDOWS:
        shutil.copyfile(source, target)
    else:
        subprocess.run(["cp", "-c", source, target], check=True)
