#!/bin/sh
# Pictures the pines from eight sides for the card a tree is drawn with from afar, and imports the sheets;
# with "alpine" the trees of the Alps instead.
# It draws, so it takes its turn on the GPU: see tools/gpu_slot.sh. Build the models first
# (tools/build_model.sh trees), and again afterwards, so that they use what was pictured.
GODOT="${GODOT:-/Applications/Godot.app/Contents/MacOS/Godot}"
cd "$(dirname "$0")/.." && tools/godot.sh --script tools/gen_tree_cards.gd -- "$@" && exec "$GODOT" --headless --path . --import
