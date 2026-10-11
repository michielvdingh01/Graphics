#!/usr/bin/env python3
"""Has a character made from a description, by two free demos on Hugging Face.

    tools/characters/generate.py <id> "<prompt>" [--seed=1] [--image=concept.png]
    tools/characters/generate.py --ration

FLUX.1-schnell (Apache-2.0) paints the character from the prompt, and
TRELLIS.2 (MIT) turns that picture into a textured model of a few hundred
thousand triangles. Both run on a GPU that Hugging Face shares out in daily
rations: two minutes for a visitor, five for a (free) account and forty for
a paying one, its pages say, counted from the first use and back 24 hours
after it. A step only starts if what it may take at most is still there: a
minute and a half for a picture, two minutes for each of the two steps of a
model. So a visitor gets pictures and never a model. Make a token at
https://huggingface.co/settings/tokens and put it in the file
~/.cache/huggingface/token, where Hugging Face's own tools keep it, or in the
environment as HF_TOKEN. It is sent to the two demos and nowhere else, and
never printed.

How much a step takes off the ration the demos do not say, and it is more
than the time it runs: on 11 October 2026 a picture ran for 3 to 8 seconds
and the two steps of a model for 21 and 22, and after one model and six
pictures, 68 seconds in all, there was nothing left; the day before it was
two models and five pictures. So paint few pictures, and reckon on one model
a day.

The script keeps count next to the token (zerogpu_ration.json): when each
step began and how long it ran, and what a demo said was left when it turned
a step away. From the last day that ran dry it takes how much goes into a
day. --ration says what is left by that count without going over the line,
and a model that would not fit is not begun (--anyway begins it all the
same). The count is of this script only.
What goes over the line is the prompt and the picture made from it: never use
this for a photo of a real person without their say-so.

The picture, the model and a note of what made them land in
assets/characters/.source/generated/<id>/, which is not in git. The model has
no skeleton: tools/import_character.sh takes it through the scan route, so the
prompt has to ask for someone standing with the arms away from the body and
the feet apart. With --image the picture is not made but taken from that file.
"""
import argparse
import datetime
import json
import os
import pathlib
import re
import shutil
import subprocess
import sys
import time
import urllib.error
import urllib.request
import uuid

ROOT = pathlib.Path(__file__).resolve().parents[2]
PAINTER = {"name": "FLUX.1-schnell", "host": "https://black-forest-labs-flux-1-schnell.hf.space", "license": "Apache-2.0"}
SCULPTOR = {"name": "TRELLIS.2-4B", "host": "https://microsoft-trellis-2.hf.space", "license": "MIT"}
AGENT = {"User-Agent": "GraphicsFPS-character-generate/0.1"}
# Where Hugging Face's own tools keep a token; a file is read by every program,
# whatever shell started it.
TOKEN_FILE = pathlib.Path.home() / ".cache/huggingface/token"
_token = os.environ.get("HF_TOKEN") or (TOKEN_FILE.read_text().strip() if TOKEN_FILE.exists() else "")
if _token:
    AGENT["Authorization"] = "Bearer " + _token
BLENDER = os.environ.get("BLENDER") or shutil.which("blender") or "/Applications/Blender.app/Contents/MacOS/Blender"
# Seconds of GPU a day by Hugging Face's pages, which is not what fits (see
# above): the count goes by the last day that ran dry, and by this until one has.
RATION = 300 if _token else 120
# What a step took when nothing has been counted yet: a guess on the safe side.
TOOK = {"infer": 10, "image_to_3d": 60, "extract_glb": 45}
LEDGER = TOKEN_FILE.with_name("zerogpu_ration.json")
DAY = datetime.timedelta(hours=24)


def _counted() -> list:
    try:
        return json.loads(LEDGER.read_text())
    except (OSError, ValueError):
        return []


def _count(entry: dict) -> None:
    entries = _counted()
    entries.append(dict(entry, at=datetime.datetime.now().isoformat(timespec="seconds")))
    LEDGER.parent.mkdir(parents=True, exist_ok=True)
    LEDGER.write_text(json.dumps(entries[-200:], indent="\t") + "\n")


def ration() -> dict:
    """The day's ration by the count: the seconds of steps that went into it
    so far (spent) and that go into a day (allowance: what had run when a
    day last ran dry, or the pages' figure until one has), whether a demo has
    said it is used up (dry), when the day began and what each step took the
    last time it ran."""
    began = None
    spent = 0.0
    dry = False
    allowance = float(RATION)
    took = dict(TOOK)
    for entry in _counted() + [{"at": datetime.datetime.now().isoformat(), "now": True}]:
        at = datetime.datetime.fromisoformat(entry["at"])
        if began is not None and at - began >= DAY:
            began = None
            spent = 0.0
            dry = False
        if "now" in entry:
            break
        if began is None:
            began = at
        if "left" in entry:
            # A demo turned a step away: what had run by then is what fits.
            if not dry:
                allowance = spent + float(entry["left"])
            dry = dry or float(entry["left"]) < 1.0
        else:
            spent += entry["seconds"]
            took[entry["step"]] = entry["seconds"]
    return {"spent": spent, "allowance": allowance, "left": 0.0 if dry else max(allowance - spent, 0.0), "dry": dry, "began": began, "took": took}


def fits(steps: list) -> bool:
    """True if these steps still go into the day, by the count."""
    state = ration()
    return state["left"] >= sum(state["took"][step] for step in steps)


def report() -> str:
    state = ration()
    lines = ["%d of %d seconds left by the count%s" % (
        state["left"], state["allowance"], "" if state["began"] is None else ", back in full at " + (state["began"] + DAY).strftime("%H:%M on %d %B"))]
    if state["dry"]:
        lines.append("a demo has said that today's ration is used up")
    lines.append("a step took, the last time: " + ", ".join("%s %d s" % (step, state["took"][step]) for step in TOOK))
    model = state["took"]["image_to_3d"] + state["took"]["extract_glb"]
    models = int(state["left"] // model)
    pictures = int((state["left"] - models * model) // state["took"]["infer"])
    lines.append("that is room for %d model%s and then %d picture%s" % (models, "" if models == 1 else "s", pictures, "" if pictures == 1 else "s"))
    return "\n".join(lines)


class Demo:
    """One visit to a Gradio demo: the calls of a visit share what the demo remembers."""

    def __init__(self, host: str):
        self.host = host
        self.visit = uuid.uuid4().hex[:12]
        with urllib.request.urlopen(urllib.request.Request(host + "/config", headers=AGENT)) as reply:
            config = json.load(reply)
        self.calls = {entry["api_name"]: entry["id"] for entry in config["dependencies"] if entry.get("api_name")}

    def call(self, name: str, *values) -> list:
        body = json.dumps({"data": list(values), "fn_index": self.calls[name], "session_hash": self.visit}).encode()
        request = urllib.request.Request(self.host + "/gradio_api/queue/join", data=body, headers=dict(AGENT, **{"Content-Type": "application/json"}))
        with urllib.request.urlopen(request) as reply:
            event = json.load(reply)["event_id"]
        stream = urllib.request.Request(self.host + "/gradio_api/queue/data?session_hash=" + self.visit, headers=AGENT)
        began = time.monotonic()
        with urllib.request.urlopen(stream, timeout=900) as reply:
            for line in reply:
                if not line.startswith(b"data:"):
                    continue
                message = json.loads(line[5:])
                if message.get("event_id") not in (None, event):
                    continue
                kind = message.get("msg")
                if kind == "estimation" and message.get("rank", 0) > 0:
                    print("  %s: number %d in the queue" % (name, message["rank"] + 1), file=sys.stderr)
                elif kind == "process_starts":
                    began = time.monotonic()
                elif kind == "process_completed":
                    if not message.get("success", False):
                        output = message.get("output") or {}
                        refusal = str(output.get("error") or output.get("title") or json.dumps(output)[:400])
                        # "... (120s requested vs. 85s left) ...": the demo's own count.
                        said = re.search(r"vs\.?\s*(\d+)\s*s left", refusal)
                        if said:
                            _count({"left": int(said.group(1))})
                        raise RuntimeError("%s refused: %s" % (name, refusal))
                    if name in TOOK:
                        # From leaving the queue to the answer: no less than the GPU ran for it.
                        _count({"step": name, "seconds": round(time.monotonic() - began, 1)})
                    return message["output"]["data"]
                elif kind in ("queue_full", "unexpected_error"):
                    raise RuntimeError("%s: %s" % (name, message.get("message") or kind))
        raise RuntimeError("%s: the demo hung up without an answer" % name)

    def send(self, path: pathlib.Path) -> dict:
        edge = uuid.uuid4().hex
        body = (("--%s\r\nContent-Disposition: form-data; name=\"files\"; filename=\"%s\"\r\nContent-Type: application/octet-stream\r\n\r\n" % (edge, path.name)).encode()
                + path.read_bytes() + ("\r\n--%s--\r\n" % edge).encode())
        request = urllib.request.Request(self.host + "/gradio_api/upload", data=body, headers=dict(AGENT, **{"Content-Type": "multipart/form-data; boundary=" + edge}))
        with urllib.request.urlopen(request) as reply:
            where = json.load(reply)[0]
        return {"path": where, "orig_name": path.name, "meta": {"_type": "gradio.FileData"}}

    def fetch(self, file: dict, target: pathlib.Path) -> None:
        url = file.get("url") or (self.host + "/gradio_api/file=" + file["path"])
        with urllib.request.urlopen(urllib.request.Request(url, headers=AGENT)) as reply:
            target.write_bytes(reply.read())


def paint(prompt: str, seed: int, target: pathlib.Path) -> None:
    demo = Demo(PAINTER["host"])
    # Upright, the shape of a person standing; four steps is what this model is made for.
    image, _ = demo.call("infer", prompt, seed, False, 832, 1344, 4)
    demo.fetch(image, target)


def sculpt(picture: pathlib.Path, seed: int, resolution: str, target: pathlib.Path) -> None:
    # The demo would have the backdrop removed by another demo, at the price
    # of a GPU turn. A picture that comes without one is only cropped.
    loose = picture.with_name("cutout.png")
    done = subprocess.run([BLENDER, "-b", "--factory-startup", "--python", str(pathlib.Path(__file__).with_name("cutout.py")), "--", str(picture), str(loose)],
                          stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True, stdin=subprocess.DEVNULL)
    if done.returncode != 0 or not loose.exists():
        raise RuntimeError("could not cut the figure out of its backdrop:\n" + done.stdout[-600:])
    demo = Demo(SCULPTOR["host"])
    demo.call("start_session")
    cut_out = demo.call("preprocess_image", demo.send(loose))[0]
    cut_out = dict(cut_out, meta={"_type": "gradio.FileData"})
    # The sliders as the demo has them: shape, then detail, then texture.
    demo.call("image_to_3d", cut_out, seed, resolution, 7.5, 0.7, 12, 5.0, 7.5, 0.5, 12, 3.0, 1.0, 0.0, 12, 3.0)
    model = demo.call("extract_glb", None, 300000, 2048)
    demo.fetch(model[1] or model[0], target)
    try:
        demo.call("end_session")
    except (RuntimeError, urllib.error.URLError):
        pass


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("id", nargs="?")
    parser.add_argument("prompt", nargs="?")
    parser.add_argument("--seed", type=int, default=1)
    parser.add_argument("--image", default="", help="use this picture instead of having one painted")
    parser.add_argument("--resolution", choices=("512", "1024", "1536"), default="1024")
    parser.add_argument("--only-image", action="store_true", help="stop after the picture, to look at it first")
    parser.add_argument("--ration", action="store_true", help="say what is left of the day's ration by the count, and stop")
    parser.add_argument("--anyway", action="store_true", help="begin a model even if the count says it will not fit")
    args = parser.parse_args()
    if args.ration:
        print(report())
        return
    if not args.id or args.prompt is None:
        parser.error("an id and a prompt, or --ration")
    folder = ROOT / "assets/characters/.source/generated" / args.id
    folder.mkdir(parents=True, exist_ok=True)
    picture = folder / "concept.webp"
    note = {"id": args.id, "prompt": args.prompt, "seed": args.seed, "made": datetime.date.today().isoformat(), "models": []}
    try:
        if args.image:
            picture.write_bytes(pathlib.Path(args.image).read_bytes())
            note["picture"] = "supplied: " + pathlib.Path(args.image).name
        elif args.only_image or not picture.exists():
            # A picture that was looked at and found good with --only-image is the one that gets used.
            print("%s: %s paints the picture" % (args.id, PAINTER["name"]), file=sys.stderr)
            paint(args.prompt, args.seed, picture)
        if not args.image:
            note["models"].append("%s (%s)" % (PAINTER["name"], PAINTER["license"]))
        if args.only_image:
            print(picture)
            return
        model = folder / (args.id + ".glb")
        if not args.anyway and not fits(["image_to_3d", "extract_glb"]):
            sys.exit("generate: a model does not fit in what is left of the day's ration, and half a model is a turn wasted.\n%s\n"
                     "The picture is kept; run this again then, or with --anyway if the count is wrong." % report())
        print("%s: %s makes the model, which takes a minute or two" % (args.id, SCULPTOR["name"]), file=sys.stderr)
        sculpt(picture, args.seed, args.resolution, model)
        note["models"].append("%s (%s) at %s" % (SCULPTOR["name"], SCULPTOR["license"], args.resolution))
    except (RuntimeError, urllib.error.URLError) as error:
        hint = ""
        if "ZeroGPU" in str(error):
            hint = ("\ngenerate: the day's ration of GPU time is used up. " + ("It comes back 24 hours after its first use." if "Authorization" in AGENT else
                    "Without an account it is too small for a model at all: it needs a token, see the top of this file."))
        sys.exit("generate: %s%s" % (error, hint))
    (folder / "note.json").write_text(json.dumps(note, indent="\t") + "\n")
    print(model)
    print("%s: next, tools/import_character.sh %s %s --height=1.8 --prompt=... --model=\"%s\"" % (
        args.id, model.relative_to(ROOT), args.id, ", ".join(note["models"])), file=sys.stderr)


if __name__ == "__main__":
    main()
