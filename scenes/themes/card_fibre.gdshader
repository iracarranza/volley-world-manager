shader_type canvas_item;

// Manila card, which is not paper and is not cloth.
//
// The journal's substrate is a *halftone screen*: a regular dot grid at a fixed
// angle, which is what a reproduction looks like. The clipboard and the
// whiteboard have no substrate texture at all, because bleached office stock and
// melamine are both manufactured to be featureless.
//
// A folder is the fourth case and it is the only one where the texture is the
// *material* rather than something done to it. Manila is unbleached pulp with
// the fibre still visible in it -- short dark specks lying flat in the direction
// the sheet was made, pale flecks where a fibre bundle never took the dye, and a
// slow unevenness across the sheet from how the pulp settled.
//
// So there is no grid here and no angle. A regular pattern would say the surface
// was printed on, and the whole claim of this medium is that nothing was printed
// on it: a folder is a thing you put printed things inside.
//
// **Screen space, like the halftone, and for the same reason.** These folders
// came out of one box of card. Anchoring the fleck per panel would give each
// folder its own patch of stock and the drawer would read as a collage; anchored
// to the viewport, the specks run continuously behind all of them and the drawer
// reads as one material seen through several cut-outs.

// How big one fibre cell is, in pixels, across its short axis. The specks are
// drawn longer than this along x -- see `FIBRE_ASPECT` -- because a fibre in a
// sheet lies down rather than standing on end, and a square speck reads as
// digital noise.
uniform float grain : hint_range(0.5, 8.0) = 1.0;

// What share of cells carry a speck. Low: a fleck you can count is a texture
// somebody applied, and a fleck you cannot is stock.
uniform float density : hint_range(0.0, 0.6) = 0.12;

// How hard a speck bites. Held well under the halftone's, because a fibre is a
// small dark thing *in* the sheet and a halftone dot is ink *on* it.
uniform float strength : hint_range(0.0, 1.0) = 0.34;

// The dark speck and the pale one. Two colours rather than one signed offset,
// because unbleached pulp is dark specks of bark and pale bundles of undyed
// fibre and those are not the same colour in opposite directions.
uniform vec4 speck : source_color = vec4(0.28, 0.22, 0.14, 1.0);
uniform vec4 pale : source_color = vec4(0.98, 0.95, 0.86, 1.0);

// The slow unevenness across the sheet, from how the pulp settled on the wire.
// Its period is two orders of magnitude above the fibre's, which is what keeps
// the two from reading as one middling-frequency mush.
uniform float mottle_period : hint_range(8.0, 400.0) = 110.0;
uniform float mottle_strength : hint_range(0.0, 0.4) = 0.05;

// Same job as the halftone's: `grain` is in pixels, so without this the fleck
// gets proportionally finer as the window grows and the stock turns into flat
// colour at fullscreen.
uniform float viewport_scale : hint_range(0.25, 4.0) = 1.0;

// How much of the pale speck survives. One on paper-bright stock; well under it
// on the dark theme, where a light fleck is the highest-contrast mark on the
// page and reads as weave rather than as fibre.
uniform float pale_scale : hint_range(0.0, 1.0) = 1.0;

// A speck is about twice as long as it is wide, and one pixel across.
//
// The first render had it three-to-one at a two-pixel grain, which put a visible
// six-by-two dash on the stock every few pixels: not fibre, confetti. The whole
// difference between a material and a pattern is whether you can resolve one
// unit of it, and at six pixels you can. Under two, you cannot, and the sheet
// goes back to being a sheet with something in it.
const float FIBRE_ASPECT = 2.2;

// Dave Hoskins' hash21, and the second one tried.
//
// The obvious two-line `fract(p * vec2(a, b))` hash correlates badly on integer
// input, and the first dark render showed exactly what that looks like at this
// scale: not noise but *corduroy*, a field of vertical stripes running the whole
// height of the page. A fibre texture whose specks line up in columns is a weave,
// and a weave is the journal's material.
float hash21(vec2 p) {
	vec3 q = fract(vec3(p.xyx) * 0.1031);
	q += dot(q, q.yzx + 33.33);
	return fract((q.x + q.y) * q.z);
}

float value_noise(vec2 p) {
	vec2 cell = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = hash21(cell);
	float b = hash21(cell + vec2(1.0, 0.0));
	float c = hash21(cell + vec2(0.0, 1.0));
	float d = hash21(cell + vec2(1.0, 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

void fragment() {
	float pitch = max(grain * viewport_scale, 0.5);
	vec2 cell = floor(FRAGCOORD.xy / vec2(pitch * FIBRE_ASPECT, pitch));

	// Two independent draws, so a cell can be dark, pale or neither -- and the
	// dark one wins where they collide, because a speck of bark is opaque.
	float dark = step(1.0 - density * 0.55, hash21(cell));
	float light = step(1.0 - density * 0.5, hash21(cell + 19.73)) * (1.0 - dark);

	float mottle = value_noise(FRAGCOORD.xy / max(mottle_period * viewport_scale, 1.0));

	// Every term multiplied by `COLOR.a`, which is what keeps the stock inside
	// the stylebox instead of printing across its rounded corners and its
	// transparent margin.
	vec3 stock = COLOR.rgb;
	stock = mix(stock, speck.rgb, mottle * mottle_strength * COLOR.a);
	stock = mix(stock, speck.rgb, dark * strength * COLOR.a);
	stock = mix(stock, pale.rgb, light * strength * 0.65 * pale_scale * COLOR.a);
	COLOR.rgb = stock;
}
