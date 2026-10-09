#!/usr/bin/env python3
"""Has a character made from a description, by two free demos on Hugging Face.

    tools/characters/generate.py <id> "<prompt>" [--seed=1] [--image=concept.png]

FLUX.1-schnell (Apache-2.0) paints the character from the prompt, and
TRELLIS.2 (MIT) turns that picture into a textured model of a few hundred
thousand triangles. Both run on a GPU that Hugging Face shares out in daily
rations. A visitor without an account gets two minutes and three turns, which
is three pictures and never a model: TRELLIS.2 asks for two turns of two
minutes. With a (free) account it fits, about one model a day: make a token at
https://huggingface.co/settings/tokens and put it in the environment as
HF_TOKEN. It is sent to the two demos and nowhere else, and never printed.
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
import shutil
import subprocess
import sys
import urllib.error
import urllib.request
import uuid

ROOT = pathlib.Path(__file__).resolve().parents[2]
PAINTER = {"name": "FLUX.1-schnell", "host": "https://black-forest-labs-flux-1-schnell.hf.space", "license": "Apache-2.0"}
SCULPTOR = {"name": "TRELLIS.2-4B", "host": "https://microsoft-trellis-2.hf.space", "license": "MIT"}
AGENT = {"User-Agent": "GraphicsFPS-character-generate/0.1"}
if os.environ.get("HF_TOKEN"):
    AGENT["Authorization"] = "Bearer " + os.environ["HF_TOKEN"]
BLENDER = os.environ.get("BLENDER") or shutil.which("blender") or "/Applications/Blender.app/Contents/MacOS/Blender"


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
                elif kind == "process_completed":
                    if not message.get("success", False):
                        output = message.get("output") or {}
                        raise RuntimeError("%s refused: %s" % (name, output.get("error") or output.get("title") or json.dumps(output)[:400]))
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
    parser.add_argument("id")
    parser.add_argument("prompt")
    parser.add_argument("--seed", type=int, default=1)
    parser.add_argument("--image", default="", help="use this picture instead of having one painted")
    parser.add_argument("--resolution", choices=("512", "1024", "1536"), default="1024")
    parser.add_argument("--only-image", action="store_true", help="stop after the picture, to look at it first")
    args = parser.parse_args()
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
        print("%s: %s makes the model, which takes a minute or two" % (args.id, SCULPTOR["name"]), file=sys.stderr)
        sculpt(picture, args.seed, args.resolution, model)
        note["models"].append("%s (%s) at %s" % (SCULPTOR["name"], SCULPTOR["license"], args.resolution))
    except (RuntimeError, urllib.error.URLError) as error:
        hint = ""
        if "ZeroGPU" in str(error):
            hint = ("\ngenerate: the day's ration of GPU time is used up. " + ("It comes back 24 hours after its first use." if "Authorization" in AGENT else
                    "Without an account it is too small for a model at all: set HF_TOKEN, see the top of this file."))
        sys.exit("generate: %s%s" % (error, hint))
    (folder / "note.json").write_text(json.dumps(note, indent="\t") + "\n")
    print(model)
    print("%s: next, tools/import_character.sh %s %s --height=1.8 --prompt=... --model=\"%s\"" % (
        args.id, model.relative_to(ROOT), args.id, ", ".join(note["models"])), file=sys.stderr)


if __name__ == "__main__":
    main()
