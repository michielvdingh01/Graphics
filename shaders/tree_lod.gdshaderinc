// Shared by what a tree is drawn with: shaders/crown.gdshader,
// shaders/tree_far.gdshader and shaders/bark.gdshader. A tree is drawn three
// times over, each time with less to it, and which of the three is seen goes
// by how far off the tree is, see tools/models/trees.gd. Where one gives way
// to the next, it does so a tuft at a time over a few metres, each tuft at a
// distance of its own: the tree never changes all at once, and nothing is
// left of it as a pattern of dots, which without an upscaler that looks
// over several frames is all a dither would be.
//
// What two drawings have in common, the plate of needles at the end of a
// limb, has the same tuft and so the same number in both: one of the two is
// there, never both and never neither. The bark, which is no tuft, changes
// over in the middle of the stretch.
//
// `shown` says over which distances from the foot of the tree a drawing comes
// in (x to y) and goes out again (z to w); one that does neither is all
// noughts, as is whatever else is drawn with these shaders. Each drawing of a
// tree has copies of its materials that say so. The renderer is told the
// same distances, as the visibility range of the drawing, and measures them
// from the same foot: see _finish() in tools/models/trees.gd.
uniform vec4 shown = vec4(0.0);

// True for what of this drawing is left to another one, at `node` the foot
// of the tree, from `eye`. The foot is where the tree's own transform puts
// it (MODEL_MATRIX[3]), which for a tree drawn as one of a MultiMesh is that
// tree and not the node that holds them all (scripts/grove.gd). `tuft` is the number of the tuft it belongs to,
// 0 to 1. What is left to another is folded up into a point where it
// stands, so that nothing of it is drawn, and its shadow goes with it: the
// eye is that of the camera also when the sun draws its shadows.
// The same with a number of its own for where it comes in and for where it
// goes: the far card of a tree of the Alps comes in where its nearer drawing
// goes, all at once, and goes where the ground takes over the wood, one tree
// at a time, each at a distance of its own.
bool given_way_by(vec3 node, vec3 eye, float coming_tuft, float going_tuft) {
	float away = distance(node, eye);
	float coming = shown.y > shown.x ? smoothstep(shown.x, shown.y, away) : 1.0;
	float going = shown.w > shown.z ? smoothstep(shown.z, shown.w, away) : 0.0;
	return coming_tuft >= coming || going_tuft < going;
}

bool given_way(vec3 node, vec3 eye, float tuft) {
	return given_way_by(node, eye, tuft, tuft);
}
