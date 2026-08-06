shader_type canvas_item;

// A print screen laid over the interface.
//
// Panels carry their elevation as a *drop shadow* in almost every UI, and a drop
// shadow is the single most "bold and clean" device there is -- it is a lighting
// model, and it says the surfaces are sheets of glass floating above each other.
// A halftone screen says the opposite: that they are printed, on stock, by
// somebody. Same job, different claim about what the thing is made of.
//
// So depth here is *dot density*, not shadow. An inset well is screened heavily
// and reads as recessed; a raised panel is screened lightly and reads as close
// to the reader. Nothing is blurred, nothing is offset, and the whole interface
// stays flat -- which is what keeps it from drifting back toward the material
// look this replaces.
//
// Note the built-in is `FRAGCOORD`, not `FRAGMENT_COORD` -- the latter is the
// spatial shader's name for it and canvas_item does not have it.
//
// **Screen space on purpose.** The grid is anchored to the viewport rather than
// to each panel, so neighbouring cards share one continuous screen the way ink
// on a page does. Per-panel UVs would give every card its own grid origin and
// the seams between them would read as a tiling error.

// Grid period in pixels. Larger is coarser and more obviously a dot; smaller
// slides toward a flat tint and stops being worth having.
uniform float period : hint_range(2.0, 24.0) = 6.0;

// Dot radius as a fraction of the period. Past ~0.5 the dots touch and the
// pattern inverts into a grid of gaps, which reads as mesh rather than print.
uniform float radius : hint_range(0.05, 0.5) = 0.30;

// How hard the dots bite into the surface colour. This is the one value that
// decides whether the treatment is texture or pattern; it wants to be low enough
// that you notice it only when you look for it.
uniform float strength : hint_range(0.0, 1.0) = 0.14;

// What the dots are made of. Passed in from `UIPalette` rather than derived from
// the surface, so a dark theme screens with its ink and a light theme with its
// own warm shadow instead of both reaching for black.
uniform vec4 tint : source_color = vec4(0.0, 0.0, 0.0, 1.0);

// Classic screen angle. Anything near 0 or 90 aligns the dots with the pixel
// grid and they alias into stripes the moment the window is resized.
uniform float angle_degrees : hint_range(0.0, 90.0) = 15.0;

// How much softer the dot edge is than a hard circle. Fully hard edges alias
// badly at this size; this is antialiasing, not a stylistic softening.
uniform float edge_softness : hint_range(0.001, 0.5) = 0.12;

void fragment() {
	float theta = radians(angle_degrees);
	mat2 screen = mat2(vec2(cos(theta), -sin(theta)), vec2(sin(theta), cos(theta)));
	vec2 cell = fract((screen * FRAGCOORD.xy) / period) - 0.5;
	// `1.0 - smoothstep` so the dot is where the mask is high; the multiply by
	// COLOR.a is what keeps the screen inside the stylebox rather than printing
	// it across the panel's rounded corners and its transparent margin.
	float dot_mask = 1.0 - smoothstep(
		radius - edge_softness, radius + edge_softness, length(cell)
	);
	COLOR.rgb = mix(COLOR.rgb, tint.rgb, dot_mask * strength * COLOR.a);
}
