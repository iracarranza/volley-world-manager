class_name CogniticonMarks
extends RefCounted

## The cogniticons as drawn marks, not as characters.
##
## `docs/design/COGNITICONS.md` and the visual review that went with it specify a
## vocabulary of **drawn** marks: shields for the four ways of dealing with their
## ball, blades for the three ways of doing something to it, hands for the pivot
## and the honest blank. What shipped was nine Unicode characters standing in for
## them -- `⛊ ⛉ ⛨ ⛰ ⇧ ⇡ ⬆ ⌒ •` -- in a `Label3D`.
##
## The stand-ins map one-to-one onto the designed marks, which is why every probe
## written against them reported the vocabulary as present. It is present as a
## placeholder. Three things the design asks for cannot be said with a character
## at all, and all three are the difference between a live read and a set of
## symbols:
##
## - a blade **fills from the bottom** as a hitter covers their run-up
## - a mark is **dashed** to mean available-but-not-committed, and dashed again
##   at lower opacity to mean it belongs to the other side
## - the family is carried by *shape*, so a shield and a blade differ at a
##   glance rather than by which arrow you are looking at
##
## This module is the blade family and the fill. Shields and hands follow; they
## need curve flattening, which the stroking below is already written for.
##
## ## Why rasterise rather than build geometry
##
## The marks are stroke-only paths in a 54x54 box. As geometry each one is a
## ribbon mesh with mitred joins and round caps -- more code, and it would have
## to be rebuilt whenever a width changed. As a texture each is a few hundred
## pixels of ink generated once at load and shared by all twelve volis, and the
## fill becomes a region on a sprite rather than a per-frame redraw.
##
## The cost is that a stroke width is baked in. That is acceptable here because
## the marks are drawn at one size by construction -- `fixed_size` billboards
## whose scale is a share of the viewport, not a world measurement.

## The design space every path below is written in, matching the review's own
## `viewBox="0 0 54 54"`. Keeping the numbers as authored means a path can be
## copied across without arithmetic, and arithmetic on a copied path is how a
## drawing quietly stops matching the thing it was approved as.
const CANVAS: float = 54.0
## Rasterised at four times that. Enough that the round caps do not stair-step
## at the size a billboard actually draws, and small enough that generating
## three of them at load is not noticeable.
const SCALE: int = 4
const PIXELS: int = 216

## **Ink and halo, not a family colour.**
##
## The review gives each family its own hue -- coral blades, blue shields, green
## hands. Drawn at size on a warm apricot court those hues sit *in* the palette
## rather than on top of it, and a mark that has to be found is not a mark that
## can be glanced at. So the ink is the one thing guaranteed to be nobody else's
## colour: white on Mikasa, near-black on Molten, at full strength.
##
## The family survives in the shape, which is where the review puts the weight
## anyway -- a shield and a blade differ at a glance without either being
## coloured, and losing the hue costs nothing that shape was not already saying.
const INK_DARK := Color(1.0, 0.99, 0.96)
const INK_LIGHT := Color(0.08, 0.09, 0.10)

## And the halo, which is what makes one ink work everywhere.
##
## A cogniticon floats above a head, so its ground is whatever happens to be
## behind it -- the lit court on one frame and the dark surround on the next.
## No single ink survives both. The `Label3D` tier already solved this with a
## 10 px outline in near-black; the drawn marks get the same idea, which is why
## a thinner stroke is affordable here: contrast is doing the work that width
## was doing before.
const HALO_DARK := Color(0.05, 0.07, 0.09, 0.85)
const HALO_LIGHT := Color(1.0, 0.98, 0.93, 0.85)
## How far the halo stands out past the ink, in design units, either side.
const HALO_SPREAD: float = 1.7

## The blade, as authored: `<rect x="21" y="6" width="12" height="30" rx="2">`
## over a guard `M13 40 H41` and a grip `M27 40 V48`.
const BLADE_RECT := Rect2(21.0, 6.0, 12.0, 30.0)
const BLADE_RADIUS: float = 2.0
## **Thinner than the review, because the ink is stronger than the review's.**
##
## 3.0 and 3.2 were drawn in a mid-tone family hue at partial opacity, where a
## stroke needs weight to register. At full-strength white or black over a halo
## it does not, and the same width then reads as a heavy sticker rather than a
## mark. Taken down about a quarter; the contrast pays for it.
##
## This is also what makes the eye possible: a pupil inside an outline only
## reads if the outline is thin enough to leave an interior.
const BLADE_STROKE: float = 2.2
const GUARD_STROKE: float = 2.4
## The serve is the same blade carried lower with a toss above it, so the rect
## moves rather than a second shape being invented: `x=21 y=14 w=12 h=28`, the
## guard at `M13 12 H41`, and the ball a filled `r=3.6` circle at `(27, 6)`.
const SERVE_RECT := Rect2(21.0, 14.0, 12.0, 28.0)
const SERVE_TOSS_CENTRE := Vector2(27.0, 6.0)
const SERVE_TOSS_RADIUS: float = 3.6
## `stroke-dasharray="5 4"`, which is what says *available* rather than
## *committed* on `preparing_attack`.
const DASH_ON: float = 5.0
const DASH_OFF: float = 4.0


## Which intents this module draws today.
##
## The renderer branches on this rather than on a family name, so each family
## switches from its Unicode stand-in to its drawn mark as it lands, instead of
## the whole layer waiting for the last one. Adding the shields means adding
## four entries here and their paths below; nothing else has to know.
const BLADE_INTENTS: Array[String] = [
	"preparing_attack", "approaching", "serving",
]


## ## The eye family -- where the voli is looking, and how hard
##
## A wider canvas than the intent marks, because an eye and its lead line are
## not square: `viewBox="0 0 70 56"` in the review. The three differ only in
## what leaves the eye, which is the whole design -- one eye, three leads:
##
## | mark | lead | means |
## |---|---|---|
## | `glance` | three short flicks, the middle longest | looked and moved on |
## | `track` | a dashed line | following it |
## | `fixed` | a solid line with an arrowhead | locked on, will not release |
##
## The pupil sits at x = 43 against an eye centred on 35, so it is **off-centre
## toward the lead**. That is the part that makes an eye read as looking rather
## than as staring out of the screen, and it is the reason the stroke had to come
## down: a 3-unit outline on a 9-unit radius leaves almost no interior for a
## 3.6-unit pupil to be seen in.
const EYE_CANVAS := Vector2(70.0, 56.0)
const EYE_CENTRE := Vector2(35.0, 28.0)
const EYE_RADII := Vector2(17.0, 9.0)
const PUPIL_CENTRE := Vector2(43.0, 28.0)
const PUPIL_RADIUS: float = 3.6
const EYE_STROKE: float = 2.0
## The one mark in the family drawn heavier, because "locked on" is the loudest
## thing this axis has to say.
const EYE_FIXED_STROKE: float = 2.4

const ATTENTION_MARKS: Array[String] = ["glance", "track", "fixed"]


## Every attention texture, by the hold it draws.
static func attention_textures(dark_theme: bool) -> Dictionary:
	var out := {}
	for mark in ATTENTION_MARKS:
		out[mark] = _eye(mark, dark_theme)
	return out


static func _eye(mark: String, dark_theme: bool) -> ImageTexture:
	var width := int(EYE_CANVAS.x) * SCALE
	var height := int(EYE_CANVAS.y) * SCALE
	var stroke := EYE_FIXED_STROKE if mark == "fixed" else EYE_STROKE
	var paths: Array = [
		{"points": _ellipse(EYE_CENTRE, EYE_RADII), "closed": true,
			"width": stroke, "dash": 0.0},
	]
	match mark:
		"glance":
			## Three flicks, the middle one longest -- a look that arrived,
			## answered itself and left. Drawn at full strength rather than at
			## the review's staggered opacities, because opacity is what the
			## halo is spending and a mark cannot afford to pay twice.
			paths.append({"points": _line(56.0, 20.0, 64.0, 20.0),
				"closed": false, "width": stroke, "dash": 0.0})
			paths.append({"points": _line(56.0, 28.0, 67.0, 28.0),
				"closed": false, "width": stroke, "dash": 0.0})
			paths.append({"points": _line(56.0, 36.0, 64.0, 36.0),
				"closed": false, "width": stroke, "dash": 0.0})
		"track":
			paths.append({"points": _line(54.0, 28.0, 67.0, 28.0),
				"closed": false, "width": stroke, "dash": 3.0})
		_:
			paths.append({"points": _line(54.0, 28.0, 68.0, 28.0),
				"closed": false, "width": stroke, "dash": 0.0})
			## The arrowhead, as one open polyline so its corner mitres rather
			## than being two segments that cross.
			paths.append({"points": PackedVector2Array([
				Vector2(64.0, 23.0), Vector2(69.0, 28.0), Vector2(64.0, 33.0),
			]), "closed": false, "width": stroke, "dash": 0.0})
	var discs: Array = [{"centre": PUPIL_CENTRE, "radius": PUPIL_RADIUS}]
	return _composite(width, height, paths, discs, [], dark_theme)


static func _line(x1: float, y1: float, x2: float, y2: float) -> PackedVector2Array:
	return PackedVector2Array([Vector2(x1, y1), Vector2(x2, y2)])


## An ellipse as a closed polyline, for the same reason the rounded rect is one:
## one path representation, so dashes and caps behave identically everywhere.
static func _ellipse(centre: Vector2, radii: Vector2) -> PackedVector2Array:
	var points := PackedVector2Array()
	## Enough segments that the curve is smooth at four times design size and
	## few enough that the stroker is not visiting the same pixels forty times.
	for step in range(48):
		var angle := TAU * float(step) / 48.0
		points.append(centre + Vector2(cos(angle) * radii.x, sin(angle) * radii.y))
	return points


## Draw a mark as halo then ink, and flatten the two.
##
## Two passes rather than one, because a halo is a second colour and the stroker
## keeps the *maximum* coverage per pass -- which is what stops a rounded corner
## reading as a bead, and would blend two colours into mud if they shared a pass.
## So each colour gets its own layer and the ink composites over the halo.
static func _composite(
	width: int,
	height: int,
	paths: Array,
	discs: Array,
	fills: Array,
	dark_theme: bool,
) -> ImageTexture:
	var ink := INK_DARK if dark_theme else INK_LIGHT
	var halo := HALO_DARK if dark_theme else HALO_LIGHT
	var halo_layer := _layer(width, height, halo)
	var ink_layer := _layer(width, height, ink)
	for pass_index in range(2):
		var image := halo_layer if pass_index == 0 else ink_layer
		var colour := halo if pass_index == 0 else ink
		var extra := HALO_SPREAD * 2.0 if pass_index == 0 else 0.0
		for path in paths:
			_stroke(
				image, path["points"], float(path["width"]) + extra, colour,
				bool(path["closed"]), float(path.get("dash", 0.0)), DASH_OFF,
			)
		for disc in discs:
			_disc(
				image, disc["centre"],
				float(disc["radius"]) + extra * 0.5, colour,
			)
		for fill in fills:
			_fill_rounded_rect(
				image, fill["rect"], float(fill["radius"]), colour, extra * 0.5
			)
	_over(halo_layer, ink_layer)
	return ImageTexture.create_from_image(halo_layer)


static func _layer(width: int, height: int, colour: Color) -> Image:
	var image := Image.create(width, height, false, Image.FORMAT_RGBA8)
	image.fill(Color(colour.r, colour.g, colour.b, 0.0))
	return image


## Source-over, in place on `base`.
static func _over(base: Image, top: Image) -> void:
	for y in range(base.get_height()):
		for x in range(base.get_width()):
			var over := top.get_pixel(x, y)
			if over.a <= 0.0:
				continue
			var under := base.get_pixel(x, y)
			var alpha := over.a + under.a * (1.0 - over.a)
			if alpha <= 0.0:
				continue
			base.set_pixel(x, y, Color(
				(over.r * over.a + under.r * under.a * (1.0 - over.a)) / alpha,
				(over.g * over.a + under.g * under.a * (1.0 - over.a)) / alpha,
				(over.b * over.a + under.b * under.a * (1.0 - over.a)) / alpha,
				alpha,
			))


## Every blade texture, by the intent it draws. Built once; the caller keeps it.
##
## `fill` is the blade's interior as a solid, drawn separately so the filling can
## be a region on a sprite rather than a texture regenerated every frame. The
## review clips it from the bottom edge upward, and a region does exactly that.
static func blade_textures(dark_theme: bool) -> Dictionary:
	return {
		"preparing_attack": _blade(true, BLADE_RECT, false, dark_theme),
		"approaching": _blade(false, BLADE_RECT, false, dark_theme),
		"serving": _blade(false, SERVE_RECT, true, dark_theme),
		"fill": _blade_fill(dark_theme),
	}


## The blade outline, its guard and its grip.
static func _blade(
	dashed: bool, rect: Rect2, tossed: bool, dark_theme: bool
) -> ImageTexture:
	var paths: Array = [
		{"points": _rounded_rect(rect, BLADE_RADIUS), "closed": true,
			"width": BLADE_STROKE, "dash": DASH_ON if dashed else 0.0},
	]
	var discs: Array = []
	if tossed:
		## The serve's guard is a bare cross-bar above the grip, and the toss is
		## a filled ball above that -- the one blade in the family that is not
		## planted, because a server is holding the ball rather than the floor.
		paths.append({"points": _line(13.0, 12.0, 41.0, 12.0), "closed": false,
			"width": GUARD_STROKE, "dash": 0.0})
		discs.append({"centre": SERVE_TOSS_CENTRE, "radius": SERVE_TOSS_RADIUS})
	else:
		## The guard and the grip, which are what stop a blade reading as a
		## thermometer once it starts filling.
		paths.append({"points": _line(13.0, 40.0, 41.0, 40.0), "closed": false,
			"width": GUARD_STROKE, "dash": 0.0})
		paths.append({"points": _line(27.0, 40.0, 27.0, 48.0), "closed": false,
			"width": GUARD_STROKE, "dash": 0.0})
	return _composite(PIXELS, PIXELS, paths, discs, [], dark_theme)


## The blade's interior as a solid, for the fill.
##
## Drawn to the blade's own rounded rect so the fill cannot spill past the
## outline it lives inside, which is what the review's clip-path guarantees by
## construction and a naive rectangle would not.
##
## Inked without a halo. The fill lives *behind* the outline, and a halo behind
## something already outlined is a second edge nobody asked for -- it read as a
## smudge growing up the blade.
static func _blade_fill(dark_theme: bool) -> ImageTexture:
	var ink := INK_DARK if dark_theme else INK_LIGHT
	var image := _layer(PIXELS, PIXELS, ink)
	_fill_rounded_rect(image, BLADE_RECT, BLADE_RADIUS, ink, 0.0)
	return ImageTexture.create_from_image(image)


## Where the fill's top edge sits, in design units, for a progress of 0 to 1.
##
## The review clips from y = 39 up to y = 4 across the full range, which
## overshoots the blade at both ends on purpose so the fill reads as full a
## little before progress does. Kept, because a blade that only looks full at
## exactly 1.0 reads as never quite arriving.
const FILL_BOTTOM: float = 39.0
const FILL_TOP: float = 4.0


## The region of the fill texture to draw, in texture pixels, for this progress.
##
## Bottom-anchored: the region always ends at the fill's bottom edge and its top
## rises with progress. Returned as a `Rect2` so the caller hands it straight to
## `Sprite3D.region_rect` without doing this arithmetic again -- it was done
## twice in the review's own markup and the two disagreed by half a unit.
static func fill_region(progress: float) -> Rect2:
	var covered := clampf(progress, 0.0, 1.0) * (FILL_BOTTOM - FILL_TOP)
	var top := (FILL_BOTTOM - covered) * float(SCALE)
	var bottom := FILL_BOTTOM * float(SCALE)
	return Rect2(0.0, top, float(PIXELS), maxf(bottom - top, 0.0))


## How far to shift a bottom-anchored region so it stays where it belongs.
##
## A `Sprite3D` centres whatever region it is given, so a region taken from the
## lower part of a texture would jump to the middle. The offset puts it back.
##
## Derived rather than guessed, because the first version was written by
## intuition and had the sign inverted -- which draws a fill that *descends* as
## progress rises, and looked plausible enough in code to ship. With the whole
## texture drawn, texture row `y` lands at world height `(H/2 - y)`, since
## texture y runs down and world y runs up. A region is drawn centred on its own
## midpoint `yc`, so putting it back means offsetting by `H/2 - yc`, and
## `yc = (top + bottom) / 2`.
static func fill_offset(region: Rect2) -> Vector2:
	return Vector2(
		0.0, (float(PIXELS) - region.position.y - region.end.y) * 0.5
	)


## A rounded rectangle as a closed polyline, in design units.
##
## Flattened here rather than drawn as an arc primitive because the stroker takes
## polylines and shields will need the same treatment for their cubics -- one
## path representation, so the dash pattern and the caps behave identically on
## every mark rather than per shape.
static func _rounded_rect(rect: Rect2, radius: float) -> PackedVector2Array:
	var r := minf(radius, minf(rect.size.x, rect.size.y) * 0.5)
	var points := PackedVector2Array()
	var corners := [
		[Vector2(rect.end.x - r, rect.position.y + r), -PI * 0.5, 0.0],
		[Vector2(rect.end.x - r, rect.end.y - r), 0.0, PI * 0.5],
		[Vector2(rect.position.x + r, rect.end.y - r), PI * 0.5, PI],
		[Vector2(rect.position.x + r, rect.position.y + r), PI, PI * 1.5],
	]
	for corner in corners:
		var centre: Vector2 = corner[0]
		var from: float = corner[1]
		var to: float = corner[2]
		for step in range(5):
			var angle := lerpf(from, to, float(step) / 4.0)
			points.append(centre + Vector2(cos(angle), sin(angle)) * r)
	return points


## Stroke a polyline into the image, with round caps and an optional dash.
##
## Distance-to-segment with a smooth edge, rather than Bresenham: the marks are
## small and a hard-edged 3 unit stroke at this size reads as a staircase. Only
## the pixels within a stroke's width of each segment are visited, so the cost is
## proportional to ink rather than to canvas.
static func _stroke(
	image: Image,
	points: PackedVector2Array,
	width: float,
	ink: Color,
	closed: bool,
	dash_on: float,
	dash_off: float,
) -> void:
	var segments: Array = []
	var count := points.size()
	var last := count if closed else count - 1
	for index in range(last):
		segments.append([points[index], points[(index + 1) % count]])
	if dash_on > 0.0:
		segments = _dash(segments, dash_on, dash_off)
	for segment in segments:
		_stroke_segment(image, segment[0], segment[1], width, ink)


## Cut a run of segments into dashes, measured along the path rather than per
## segment -- a dash pattern restarted at every corner is not a dash pattern.
static func _dash(segments: Array, on: float, off: float) -> Array:
	var out: Array = []
	var travelled := 0.0
	for segment in segments:
		var from: Vector2 = segment[0]
		var to: Vector2 = segment[1]
		var length := from.distance_to(to)
		if length <= 0.0001:
			continue
		var direction := (to - from) / length
		var cursor := 0.0
		while cursor < length:
			var cycle := fmod(travelled + cursor, on + off)
			var remaining := (on - cycle) if cycle < on else (on + off - cycle)
			var span := minf(remaining, length - cursor)
			if cycle < on:
				out.append([
					from + direction * cursor, from + direction * (cursor + span),
				])
			cursor += span
		travelled += length
	return out


static func _stroke_segment(
	image: Image, from: Vector2, to: Vector2, width: float, ink: Color
) -> void:
	var half := width * 0.5 * float(SCALE)
	var a := from * float(SCALE)
	var b := to * float(SCALE)
	## One pixel of feather either side of the edge. Any more and a 12 pixel
	## stroke loses a sixth of itself to the blur.
	var feather := 1.0
	var reach := half + feather + 1.0
	var min_x := maxi(int(floor(minf(a.x, b.x) - reach)), 0)
	var max_x := mini(int(ceil(maxf(a.x, b.x) + reach)), image.get_width() - 1)
	var min_y := maxi(int(floor(minf(a.y, b.y) - reach)), 0)
	var max_y := mini(int(ceil(maxf(a.y, b.y) + reach)), image.get_height() - 1)
	var span := b - a
	var length_squared := maxf(span.length_squared(), 0.000001)
	for y in range(min_y, max_y + 1):
		for x in range(min_x, max_x + 1):
			var point := Vector2(float(x) + 0.5, float(y) + 0.5)
			var t := clampf((point - a).dot(span) / length_squared, 0.0, 1.0)
			var distance := point.distance_to(a + span * t)
			var alpha := 1.0 - smoothstep(half - feather, half + feather, distance)
			if alpha > 0.0:
				_blend(image, x, y, ink, alpha)


static func _disc(
	image: Image, centre: Vector2, radius: float, ink: Color
) -> void:
	var c := centre * float(SCALE)
	var r := radius * float(SCALE)
	var reach := r + 2.0
	for y in range(maxi(int(c.y - reach), 0), mini(int(c.y + reach), image.get_height() - 1) + 1):
		for x in range(maxi(int(c.x - reach), 0), mini(int(c.x + reach), image.get_width() - 1) + 1):
			var distance := Vector2(float(x) + 0.5, float(y) + 0.5).distance_to(c)
			var alpha := 1.0 - smoothstep(r - 1.0, r + 1.0, distance)
			if alpha > 0.0:
				_blend(image, x, y, ink, alpha)


static func _fill_rounded_rect(
	image: Image, rect: Rect2, radius: float, ink: Color, grow: float = 0.0
) -> void:
	var r := minf(radius, minf(rect.size.x, rect.size.y) * 0.5) * float(SCALE)
	var scaled := Rect2(rect.position * float(SCALE), rect.size * float(SCALE))
	scaled = scaled.grow(grow * float(SCALE))
	var centre := scaled.position + scaled.size * 0.5
	var half := scaled.size * 0.5 - Vector2(r, r)
	for y in range(maxi(int(scaled.position.y - 2.0), 0), mini(int(scaled.end.y + 2.0), image.get_height() - 1) + 1):
		for x in range(maxi(int(scaled.position.x - 2.0), 0), mini(int(scaled.end.x + 2.0), image.get_width() - 1) + 1):
			var point := Vector2(float(x) + 0.5, float(y) + 0.5)
			var delta := (point - centre).abs() - half
			var outside := Vector2(maxf(delta.x, 0.0), maxf(delta.y, 0.0))
			var distance := outside.length() + minf(maxf(delta.x, delta.y), 0.0) - r
			var alpha := 1.0 - smoothstep(-1.0, 1.0, distance)
			if alpha > 0.0:
				_blend(image, x, y, ink, alpha)


## Source-over, keeping the highest coverage rather than accumulating it.
##
## Two segments meeting at a corner overlap, and adding their alphas there makes
## every join darker than the strokes it joins -- visible as beads at each corner
## of a rounded rect. Taking the maximum is what makes a join look like a join.
static func _blend(
	image: Image, x: int, y: int, ink: Color, alpha: float
) -> void:
	var existing := image.get_pixel(x, y)
	image.set_pixel(x, y, Color(
		ink.r, ink.g, ink.b, maxf(existing.a, clampf(alpha, 0.0, 1.0))
	))
