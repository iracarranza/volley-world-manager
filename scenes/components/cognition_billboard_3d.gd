class_name CognitionBillboard3D
extends Label3D

## The 3D half of one cue, above one voli's head.
##
## A separate node rather than more state inside `player_actor_3d.gd`, which is
## the file Codex's new models and VFX are about to rewrite; the whole point of
## keeping this component apart is that the two lines of work touch different
## nodes. The actor gains one child and one call.
##
## **Parity is on the description, not on the drawing.** The tactical board
## rasterises `CognitionBadge.describe` into arcs and polygons; this turns the
## same dictionary into a glyph and a colour. They will never look alike and
## must always mean alike, so anything that decides *meaning* -- which state, how
## urgent, whether the eye is open -- happens in the badge module and neither
## renderer is allowed a rule of its own.

const BadgeModel := preload("res://scripts/systems/cognition_badge.gd")

## The glyph for each badge shape. Chosen so the silhouette survives at the
## distance a stationary camera actually puts a player at, which ruled out the
## eye shapes that read fine at 20 px on the board and turn to mush here.
const SHAPE_GLYPHS := {
	"circle": "◦",
	"wedge": "◗",
	"diamond": "◆",
	"dashed_ring": "◌",
	"burst": "✳",
}
const FACE_GLYPHS := {
	"upset": "✖",
	"sad": "▾",
	"confident": "▴",
	"pleased": "▴",
	"urgent": "!",
}
const TREND_GLYPHS := {1: "↑", -1: "↓"}

## The ambient tier: what a voli is doing when nothing more interesting is true
## of them.
##
## One mark per intent, grouped so a glance answers *which side of the ball* and
## a look answers the rest -- shields for the four ways of dealing with their
## ball, blades for the three ways of doing something to it, hands for the pivot,
## and a dot for a voli with nothing to add. The dot matters: without a mark,
## "no opinion" is indistinguishable from "not implemented", which is the state
## this layer started in at 0.75 volis of six.
const INTENT_GLYPHS := {
	"defending": "⛊", "covering": "⛉", "receiving": "⛨", "blocking": "⛰",
	"serving": "⇧", "preparing_attack": "⇡", "approaching": "⬆",
	"setting": "⌒", "watching": "•",
}
## `watching` was `·`, a middle dot, and it is **half of every mark drawn**.
##
## `run_cogniticon_screen_probe.gd`, eight rallies off the billboard nodes
## themselves: of the marks visible on screen, 49.2% are this one. It was also
## the least ink of any glyph in the set by a wide margin -- at the em size the
## ambient tier runs at, a middle dot is a few pixels.
##
## The comment above argues the dot has to exist, because without a mark "no
## opinion" is indistinguishable from "not implemented". An *invisible* dot
## fails that test by exactly the same argument, so it is a bullet: still the
## quietest thing in the vocabulary, still deliberately nothing in particular,
## but actually present.
## How far the ambient tier is held below the punctuating one.
##
## The whole two-tier rule in one number. An ambient mark is present on twelve
## volis at once and must never draw the eye; a state badge appears rarely and
## must be the only thing moving when it does. Sized and faded well under the
## badge so that going from 0.75 marks to twelve does not drown `lost_sight`,
## which fires 24 times in 47,000 cue-samples and lands because almost nothing
## else is lit.
## **The ambient tier was paying for quiet twice, and one of the two payments
## bought nothing.**
##
## It was 0.00010 against a badge running 0.00014 to 0.00022 -- 71% of the
## quietest badge and 45% of the loudest -- *and* held at 0.55 alpha. Reported
## from two frames of real playback: the marks cannot be made out at all, and
## the only ones legible on screen are the badge tier's solid diamonds.
##
## Size and contrast are not two ways of saying the same thing. **Size carries
## identity** -- which glyph is this, a shield or a blade -- and **contrast
## carries priority** -- should this pull my eye. Buying quiet with size spends
## the one thing the ambient layer exists for; `COGNITICONS.md` asks that "a
## glance anywhere on court tells you what that voli is doing", and a mark too
## small to identify answers that with nothing. Buying it with contrast costs
## only the pull, which is exactly what was meant to be given up.
##
## So the size goes up to where a shape is readable and the alpha comes down to
## pay for it. The two-tier rule is unchanged in its intent and now lives where
## it belongs: an ambient mark is *dimmer* than a state badge rather than
## smaller than one.
const AMBIENT_PIXEL_SIZE: float = 0.00020
const AMBIENT_ALPHA: float = 0.40

## One number for how large a cogniticon is, so "too small" is one edit rather
## than four.
##
## The badge was sized against a body -- roughly a head on screen -- which is the
## right *relationship* and turned out to be the wrong *number* at the camera
## distances the match centre actually uses. A head is a fine size for a mark you
## are looking for and too small for one you are supposed to read at a glance
## across twelve volis, which is what these are for.
##
## Every size below is a multiple of this, and the two-tier rule survives the
## scaling: ambient stays well under the state badge, because both move together.
const COGNITICON_SCALE: float = 1.45

const BADGE_PIXEL_SIZE: float = 0.00017
const BADGE_PIXEL_SIZE_QUIET: float = 0.00014
const BADGE_PIXEL_SIZE_LOUD: float = 0.00022

const HEIGHT_ABOVE_HEAD_METERS: float = 0.30


func _init() -> void:
	## Always facing the camera and never occluded by the player it belongs to.
	## A thought that disappears behind a shoulder reads as a flicker.
	billboard = BaseMaterial3D.BILLBOARD_ENABLED
	no_depth_test = true
	## **Screen-relative, and therefore easy to get catastrophically wrong.**
	##
	## `fixed_size` keeps the label the same size however far the camera is, so
	## `pixel_size` is not a world measurement -- it is a share of the viewport.
	## At 0.0016 with a 96 pt face the glyphs came out several hundred pixels
	## tall: a single voli's badge covered most of the court, and six of them
	## covered the match. The 2D badge was sized against a 20 px marker and this
	## one was never sized against anything.
	##
	## A badge is a note about a body, so it wants to be a fraction of that body
	## on screen -- roughly a head. That is about a tenth of what was here.
	fixed_size = true
	pixel_size = BADGE_PIXEL_SIZE * COGNITICON_SCALE
	font_size = 96
	outline_size = 10
	outline_modulate = Color(0.02, 0.02, 0.04, 0.85)
	horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	visible = false


## Shows one cue, or hides the badge when there is nothing worth showing.
##
## Returns the cue's attention target kind so the caller can decide whether to
## drive the head as well -- the actor's `look_toward` belongs to the actor, and
## this component should not reach into it.
func show_cue(
	cue: Resource, head_height_meters: float, simulation_time: float = -1.0
) -> void:
	if cue == null or not BadgeModel.is_worth_drawing(cue):
		visible = false
		return
	var reading: Dictionary = BadgeModel.describe(cue)
	if reading.is_empty():
		visible = false
		return
	## The ambient tier draws its intent and stops there.
	##
	## An ambient cue is `committed` by construction, so running it through the
	## state vocabulary returns a diamond labelled COMMITTED for every voli on
	## court, permanently -- which is what shipped before this branch existed.
	## What it actually has to say is what this voli is doing, and the fade says
	## when it has finished saying it.
	if bool(reading.get("is_ambient", false)):
		var strength: float = cue.glyph_strength(simulation_time)
		if strength <= 0.01:
			visible = false
			_hide_mark()
			return
		## **A drawn mark where one exists, the character otherwise.**
		##
		## The blade family is drawn; the shields and hands are still standing in
		## as Unicode until they are. Branching on what has been drawn rather
		## than on the intent means each family switches over as it lands,
		## instead of the whole layer waiting for the last one.
		var intent := str(reading.get("intent", "watching"))
		if _draw_mark(intent, float(reading.get("progress", 0.0)), strength):
			text = ""
			visible = true
			position = Vector3(0.0, head_height_meters + MARK_LIFT_METERS, 0.0)
			return
		text = str(INTENT_GLYPHS.get(intent, "•"))
		var ambient_color := Color(reading.color)
		ambient_color.a = AMBIENT_ALPHA * strength
		modulate = ambient_color
		pixel_size = AMBIENT_PIXEL_SIZE * COGNITICON_SCALE
		position = Vector3(0.0, head_height_meters, 0.0)
		visible = true
		return
	var glyph := str(SHAPE_GLYPHS.get(str(reading.shape), "◦"))
	var face := str(FACE_GLYPHS.get(str(reading.face), ""))
	var punctuation := str(reading.punctuation)
	var trend := str(TREND_GLYPHS.get(int(reading.trend_direction), ""))
	## Punctuation and face sit beside the shape rather than replacing it, so a
	## badge never loses its state to its mood.
	text = "%s%s%s%s" % [face, glyph, punctuation, trend]
	modulate = Color(reading.color)
	## Emphasis still reads as size, across a range that stays a badge at both
	## ends rather than becoming scenery at one of them.
	pixel_size = lerpf(
		BADGE_PIXEL_SIZE_QUIET, BADGE_PIXEL_SIZE_LOUD, float(reading.emphasis)
	) * COGNITICON_SCALE
	position = Vector3(0.0, head_height_meters + HEIGHT_ABOVE_HEAD_METERS, 0.0)
	visible = true


func hide_cue() -> void:
	visible = false
	_hide_mark()


## The drawn marks, built once and shared by every voli on the court.
##
## Static because they are the same three textures twelve times over, and
## rasterising them per actor would be twelve times the work for one result.
static var _blades: Dictionary = {}
static var _blades_are_dark: bool = false

## This billboard's own two sprites: the mark, and the fill behind it.
##
## Two nodes rather than one, because the fill is a *region* of a second texture
## clipped from the bottom -- which is how the visual review draws it, and is
## what lets the outline stay whole while the interior rises. One node would
## need the fill baked into the mark, which is a texture per progress value.
var _mark: Sprite3D
var _mark_fill: Sprite3D


## Draw this intent as a mark, or report that nothing is drawn for it yet.
func _draw_mark(intent: String, progress: float, strength: float) -> bool:
	if not CogniticonMarks.BLADE_INTENTS.has(intent):
		return false
	_ensure_marks()
	var texture: Texture2D = _blades.get(intent, null)
	if texture == null:
		return false
	_mark.texture = texture
	_mark.modulate = Color(1.0, 1.0, 1.0, MARK_ALPHA * strength)
	_mark.pixel_size = AMBIENT_PIXEL_SIZE * COGNITICON_SCALE * MARK_PIXEL_RATIO
	_mark.visible = true
	## Only the intents that accumulate carry a fill, and the review is explicit
	## that the fill is *distance covered* and never *likelihood of arriving* --
	## a hitter who will be late still fills, because they are running.
	var fills := intent == "approaching" and progress > 0.001
	_mark_fill.visible = fills
	if fills:
		var region := CogniticonMarks.fill_region(progress)
		_mark_fill.texture = _blades["fill"]
		_mark_fill.region_enabled = true
		_mark_fill.region_rect = region
		_mark_fill.offset = CogniticonMarks.fill_offset(region)
		_mark_fill.modulate = Color(1.0, 1.0, 1.0, MARK_ALPHA * strength * 0.72)
		_mark_fill.pixel_size = _mark.pixel_size
	return true


## How much larger a drawn mark is than the character it replaces.
##
## A glyph is drawn at a font size and fills a fraction of its em box; a mark
## fills its own canvas edge to edge. Matched by eye against the plate so the
## two tiers keep the relationship the gate asserts -- the mark reads at the
## size the character was *supposed* to, rather than at the size it managed.
const MARK_PIXEL_RATIO: float = 0.82

## How far above the crown the mark sits, in metres.
##
## **The reason a mark felt detached from its voli.** It was centred *on*
## `_cognition_head_height`, which is the scalp -- so half the mark overlapped
## the head and half towered above it, and at `fixed_size` that half does not
## shrink with distance. A big shape straddling the top of a head reads as
## something hovering near the voli rather than as something belonging to them.
##
## Sitting it just clear of the crown instead, with the size down, puts the ink
## in the space directly above the head where a thought bubble goes. Small and
## in metres: the mark is screen-relative and this is not, so a large gap would
## open up as the camera pulled back.
const MARK_LIFT_METERS: float = 0.13

## **A drawn mark is opaque; the character it replaced was not.**
##
## `AMBIENT_ALPHA` is 0.40, and applying it here would have thrown away the
## whole reason the marks are drawn in ink and halo: the contrast *is* the
## legibility, and fading it to 40% puts back the problem the ink was chosen to
## solve. The two-tier rule survives elsewhere -- an ambient mark is a thin
## outline where a state badge is a solid glyph, so the badge still carries more
## weight at the same opacity.
##
## The fill sits under the outline at a lower share, so a full blade still reads
## as an edge with an interior rather than as a solid slab.
const MARK_ALPHA: float = 0.76


func _hide_mark() -> void:
	if _mark != null:
		_mark.visible = false
	if _mark_fill != null:
		_mark_fill.visible = false


func _ensure_marks() -> void:
	if _blades.is_empty() or _blades_are_dark != _mark_theme_is_dark():
		_blades_are_dark = _mark_theme_is_dark()
		_blades = CogniticonMarks.blade_textures(_blades_are_dark)
	if _mark == null:
		_mark_fill = _new_mark_sprite()
		_mark = _new_mark_sprite()
		## The fill is added first so the outline draws over it, which is what
		## keeps the blade's edge crisp as the interior rises past it.
		add_child(_mark_fill)
		add_child(_mark)


func _new_mark_sprite() -> Sprite3D:
	var sprite := Sprite3D.new()
	sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	sprite.no_depth_test = true
	sprite.fixed_size = true
	sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	sprite.transparent = true
	sprite.shaded = false
	sprite.visible = false
	return sprite


## Which ink the marks are drawn in.
##
## Told, not derived. `UIPalette` is a table rather than a state -- every call
## site passes the mode in -- so a billboard asking it "which theme is on" would
## be inventing a second answer to a question the actor is already handed by
## `apply_ui_palette`. Defaulted to Mikasa because that is what the match centre
## opens in.
var light_mode: bool = false


func _mark_theme_is_dark() -> bool:
	return not light_mode
