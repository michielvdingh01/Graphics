shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, skip_vertex_transform;

// The fire and smoke of an explosion, and the smoke over a fire: soft balls
// that leave, slow down, swell and thin out as the dust in puff.gdshader
// does, but that the renderer does not light, and that can burn. A cloud
// that fills half the picture costs too much when every pixel of every ball
// has to look up its lights and shadows: an explosion a second took a third
// off the frame rate that way.
//
// So the light is worked out here, and nearly all of it once per ball.
// Whoever sets a cloud off says where its light comes from, see
// Fx.smoke_light(): one key light, which is the sun or a lamp, and what
// comes from all around. A ball on the side of the cloud that faces the key
// light gets it in full and one on the far side hardly any, a ball deep
// inside gets less from all around, and a fire in the cloud or under it
// lights it from there. For a ball that comes to what it gets whichever way
// a spot on it faces (`lit`) and what a spot gets on top of that for the way
// it faces (`tilt`), so that a pixel only has to say which way it faces, as
// a spot on the ball its card stands for. The billows are the noise, read
// twice: where the pixel is, and a little way towards the key light. Where
// the smoke gets thinner that way the pixel is on the lit side of a billow.
#include "fx_common.gdshaderinc"

// Three channels of tiling noise; the wear mask of the painted steel will do.
uniform sampler2D noise : filter_linear_mipmap, repeat_enable;

instance uniform float start = -100.0;
// Colour of the smoke where it is thickest, and how opaque that is.
instance uniform vec4 tint : source_color = vec4(0.5, 0.48, 0.45, 0.5);
// Speed it leaves at in m/s and how far from the normal it fans out.
instance uniform float speed = 1.5;
instance uniform float spread = 0.6;
// Radius of a ball when it appears and when it is gone, in metres.
instance uniform vec2 size = vec2(0.05, 0.35);
instance uniform float life = 1.2;
// Metres per second it drifts upwards.
instance uniform float rise = 0.1;
instance uniform float amount = 1.0;
// Light it gives off itself while it is young: a ball of fire, not of smoke.
instance uniform float glow = 0.0;
// Fraction of its life it burns for before it is smoke of the colour above:
// an explosion rather than a puff. `glow` is then how bright the fire is.
instance uniform float fire = 0.0;
// The way to the key light, and its colour times how strong it is where the
// cloud hangs. Left alone, the cloud is lit from above.
instance uniform vec3 key = vec3(0.0, 1.0, 0.0);
instance uniform vec3 key_light = vec3(2.0);
// The light that comes from all around.
instance uniform vec3 fill = vec3(0.5);
// A fire that burns under it: how strongly it lights the smoke, and the
// moment on the clock of the effects at which it is out.
instance uniform vec2 ember = vec2(0.0);

// How quickly the air stops it, per second.
const float DRAG = 5.0;
// How far a ball turns over while it flies out, in radians, and how far every
// second after that: the cloud rolls outwards over its top.
const float ROLL = 2.4;
const float CHURN = 0.3;
// What is left of the key light on the far side of a thick cloud.
const float KEY_THROUGH = 0.05;
// How much of the key light depends on the way a spot faces; the rest falls
// on all of the ball. Smoke scatters, so its dark side is not black.
const float KEY_TILT = 0.5;
// The same for the light from all around, more of which comes from above.
const float SKY_TILT = 0.4;
// How much of the light from all around is lost in the middle of the cloud.
const float DEEP = 0.6;
// How much further a spot counts as turned aside than it is on a ball: the
// light on smoke gets round it.
const float BULGE = 1.5;
// The colour of firelight on smoke, and how bright the fire in a cloud is.
const vec3 FIRE_LIGHT = vec3(1.0, 0.42, 0.12);
const float FIREBALL = 14.0;
// How high over a fire its light gets, in metres, and how many seconds
// before the fire is out it starts to fail.
const float EMBER_REACH = 1.3;
const float EMBER_DYING = 1.5;
// How much lighter the smoke is by the time it is gone, and how much lighter
// where it is thin than where it is thick: soot at the core, grey at the rim.
const float AGED = 0.4;
const float WISP = 0.6;
// How much of the key light comes through the thin rims of a cloud that
// hangs between it and the eye.
const float FORWARD = 0.8;
// How much of the fine grain of the noise is left out of the billows.
const float SOFT = 1.2;
// How far towards the key light the smoke is read a second time, in widths
// of the noise, and how much lighter or darker that makes a spot.
const float EMBOSS = 0.04;
const float RELIEF = 3.0;
// How much thicker smoke is when it is new than by the time it is gone.
const float YOUNG = 1.2;
// How much of a ball at the back of a thick cloud is left out. The cards are
// not drawn back to front, so one that hangs behind the others would show
// through them, with the side of the cloud that cannot be seen from here.
const float HIDDEN = 0.8;

varying float course;
// Where in the noise the billows of this ball are, and how far from there
// the key light is looked for.
varying vec2 at;
varying flat vec2 shift;
// The share of its fire that a ball has left.
varying flat float burning;
// The light on the ball, times its colour: see the top of this file. `relief`
// is what a billow gets extra on its lit side and `shine` what comes through
// a thin rim.
varying flat vec3 lit;
varying flat mat3 tilt;
varying flat vec3 relief;
varying flat vec3 shine;
// The densities at which the smoke of this ball begins to show and at which
// it is at its thickest, and how opaque that is.
varying flat vec3 veil;

void vertex() {
	vec3 random = VERTEX * 0.5 + 0.5;
	// They do not all leave at the same moment, unless they are blown out.
	float since = max(fx_time - start, 0.0);
	float age = fx_time - start - random.z * (fire > 0.0 ? 0.03 : 0.12) * life;
	float span = life * (0.6 + 0.4 * random.x);
	course = clamp(age / span, 0.0, 1.0);
	burning = fire > 0.0 ? max(1.0 - course / fire, 0.0) : 0.0;

	mat3 frame = mat3(MODEL_MATRIX);
	vec3 heading = frame * cone(NORMAL, spread);
	float flight = 1.0 - exp(-DRAG * age);
	vec3 away = heading * speed * (0.25 + 0.75 * random.y) * flight / DRAG;
	away.y += rise * age * (0.6 + 0.8 * random.x);
	float radius = mix(size.x, size.y, 1.0 - exp(-3.5 * course)) * (0.7 + 0.6 * random.z);
	vec3 view = (VIEW_MATRIX * vec4(MODEL_MATRIX[3].xyz + away, 1.0)).xyz;
	// One that hangs right in front of the lens would wipe out the view.
	radius *= smoothstep(0.15, 0.6, -view.z);

	// Where the ball is in its cloud: nothing in the middle, 1 at the edge.
	// The cloud is as far across as its balls have flown and drifted apart.
	float flown = speed * (1.0 - exp(-DRAG * since)) / DRAG;
	vec3 middle = frame[1] * flown * 0.35 * clamp(2.0 - spread, 0.0, 1.0) + vec3(0.0, rise * since, 0.0);
	vec3 place = (away - middle) / (0.75 * flown + 0.3 * abs(rise) * since + 0.25 * size.y);
	mat3 look = mat3(VIEW_MATRIX);
	// Thin smoke lets the key light through the cloud, and shows what hangs
	// at the back of it.
	float thick = smoothstep(0.3, 0.9, tint.a);

	// Soot thins out to grey as the smoke gets older.
	vec3 soot = tint.rgb * (1.0 + AGED * course);
	vec3 from_key = soot * key_light * mix(mix(1.0, KEY_THROUGH, thick), 1.0, smoothstep(-0.6, 0.4, dot(place, key)));
	vec3 from_around = soot * fill * (1.0 - DEEP * (1.0 - min(length(place), 1.0)));
	// A fire in the cloud lights it for as long as it burns, and one under it
	// lights what has not risen far yet.
	float embers = ember.x * (1.0 - smoothstep(ember.y - EMBER_DYING, ember.y, fx_time)) * exp(-max(away.y, 0.0) / EMBER_REACH);
	vec3 from_fire = soot * FIRE_LIGHT * (FIREBALL * burning * burning + embers);
	vec3 to_fire = -normalize(away + vec3(0.0, 0.3, 0.0));
	lit = from_key * (1.0 - KEY_TILT) + from_around * (1.0 - SKY_TILT) + from_fire * 0.5;
	mat3 facing_light = outerProduct(from_key, key) * KEY_TILT + outerProduct(from_around, vec3(0.0, 1.0, 0.0)) * SKY_TILT + outerProduct(from_fire, to_fire) * 0.5;
	relief = from_key * RELIEF;
	// A cloud between the eye and the key light glows at its thin rims.
	shine = soot * key_light * FORWARD * pow(max(dot(look * key, normalize(view)), 0.0), 3.0);

	// The card turns the way the cloud rolls: outwards over the top, whichever
	// side it is seen from.
	float turn = random.x * 6.28 - (look * heading).x * (ROLL * flight + CHURN * age);
	vec2 card = vec2(cos(turn), sin(turn));
	// From here on the light is told in the directions of the card, so that a
	// pixel has no turning to do.
	mat3 to_card = mat3(vec3(card.x, -card.y, 0.0), vec3(card.y, card.x, 0.0), vec3(0.0, 0.0, 1.0)) * look;
	tilt = facing_light * transpose(to_card);
	tilt[0] *= BULGE;
	tilt[1] *= BULGE;
	at = UV * 0.28 + random.xy * 7.0;
	shift = (to_card * key).xy * EMBOSS;

	// New smoke is thick, with an edge to it, the sharper the more opaque it
	// is; old smoke is gone first where it is thinnest.
	float gone = 0.5 * course * course;
	float behind = smoothstep(0.0, 0.8, -(look * place).z) * thick;
	veil = vec3(vec2(gone, gone + mix(1.0, 0.5, tint.a) + 0.3 * course) / (1.0 + YOUNG * (1.0 - course)),
			tint.a * (1.0 - HIDDEN * behind) * smoothstep(0.0, 0.08, course) * (1.0 - smoothstep(0.5, 1.0, course)));

	vec2 corner = UV * 2.0 - 1.0;
	view.xy += (card * corner.x + vec2(-card.y, card.x) * corner.y) * radius;
	VERTEX = view;
	NORMAL = vec3(0.0, 0.0, 1.0);
	if (age < 0.0 || age > span || UV2.x > amount) {
		VERTEX = vec3(0.0, 0.0, 1.0);
	}
}

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float inside = max(1.0 - dot(p, p), 0.0);
	// Thick in the middle and thinning to nothing at the rim, in billows:
	// two patterns of the noise, of which one gives way to the other.
	vec2 here = texture(noise, at, SOFT).rb;
	vec2 there = texture(noise, at + shift, SOFT).rb;
	float billow = mix(here.x, here.y, course);
	float density = inside * inside * (0.2 + 2.4 * billow * billow);
	// How far short of its thickest the smoke is here: 1 at the rim of it.
	float thin = 1.0 - smoothstep(veil.x, veil.y, density);
	float alpha = (1.0 - thin) * veil.z;

	// A spot faces the way the ball does there, and is lighter the thinner the
	// smoke gets from there towards the key light.
	float lean = billow - mix(there.x, there.y, course);
	vec3 colour = (1.0 + WISP * thin) * (max(lit + tilt * vec3(p, sqrt(inside)) + relief * lean, vec3(0.0)) + shine * thin);
	vec3 glowing = tint.rgb * glow * (1.0 - course);
	if (fire > 0.0) {
		// Burning, it is hottest where it is thickest: yellow through orange
		// to a dull red, and soot where it has burnt out. The thin parts go
		// out first, so the fire breaks up into the smoke it leaves.
		float heat = burning * (0.3 + 0.7 * inside) * (0.15 + 2.6 * billow * billow) + burning * burning * burning * 0.6;
		glowing = (vec3(1.0, 0.16, 0.02) * smoothstep(0.05, 0.4, heat) * 1.5 + vec3(1.0, 0.5, 0.12) * smoothstep(0.35, 0.8, heat) * 2.6 + vec3(1.0, 0.85, 0.6) * smoothstep(0.8, 1.3, heat) * 5.0) * glow;
		colour *= 1.0 - smoothstep(0.0, 0.3, heat);
		// Fire is not something to see through.
		alpha = mix(alpha, smoothstep(0.02, 0.25, density) * smoothstep(0.0, 0.04, course), smoothstep(0.0, 0.25, burning));
	}
	ALBEDO = colour + glowing;
	ALPHA = alpha;
}
