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
	"setting": "⌒", "watching": "·",
}
## How far the ambient tier is held below the punctuating one.
##
## The whole two-tier rule in one number. An ambient mark is present on twelve
## volis at once and must never draw the eye; a state badge appears rarely and
## must be the only thing moving when it does. Sized and faded well under the
## badge so that going from 0.75 marks to twelve does not drown `lost_sight`,
## which fires 24 times in 47,000 cue-samples and lands because almost nothing
## else is lit.
const AMBIENT_PIXEL_SIZE: float = 0.00010
const AMBIENT_ALPHA: float = 0.55

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
			return
		text = str(INTENT_GLYPHS.get(str(reading.get("intent", "watching")), "·"))
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
