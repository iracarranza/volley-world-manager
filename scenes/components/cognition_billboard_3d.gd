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

const HEIGHT_ABOVE_HEAD_METERS: float = 0.42


func _init() -> void:
	## Always facing the camera and never occluded by the player it belongs to.
	## A thought that disappears behind a shoulder reads as a flicker.
	billboard = BaseMaterial3D.BILLBOARD_ENABLED
	no_depth_test = true
	fixed_size = true
	pixel_size = 0.0016
	font_size = 96
	outline_size = 24
	outline_modulate = Color(0.02, 0.02, 0.04, 0.85)
	horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	visible = false


## Shows one cue, or hides the badge when there is nothing worth showing.
##
## Returns the cue's attention target kind so the caller can decide whether to
## drive the head as well -- the actor's `look_toward` belongs to the actor, and
## this component should not reach into it.
func show_cue(cue: Resource, head_height_meters: float) -> void:
	if cue == null or not BadgeModel.is_worth_drawing(cue):
		visible = false
		return
	var reading: Dictionary = BadgeModel.describe(cue)
	if reading.is_empty():
		visible = false
		return
	var glyph := str(SHAPE_GLYPHS.get(str(reading.shape), "◦"))
	var face := str(FACE_GLYPHS.get(str(reading.face), ""))
	var punctuation := str(reading.punctuation)
	var trend := str(TREND_GLYPHS.get(int(reading.trend_direction), ""))
	## Punctuation and face sit beside the shape rather than replacing it, so a
	## badge never loses its state to its mood.
	text = "%s%s%s%s" % [face, glyph, punctuation, trend]
	modulate = Color(reading.color)
	## Emphasis reads as size, which survives at any distance and in any colour.
	pixel_size = lerpf(0.0013, 0.0021, float(reading.emphasis))
	position = Vector3(0.0, head_height_meters + HEIGHT_ABOVE_HEAD_METERS, 0.0)
	visible = true


func hide_cue() -> void:
	visible = false
