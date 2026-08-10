class_name CognitionBadge
extends RefCounted

## How one cue reads as a picture, in one place, for every renderer.
##
## The 2D tactical board draws with `draw_*` calls into a `Control`; the 3D
## billboard builds meshes facing a camera. They share no drawing code and must
## share every meaning, so the translation from semantics to appearance lives
## here and each renderer only decides how to put a circle on the screen.
##
## **Colour is never the only signal.** Every field this returns is redundant
## with another: an urgent cue is red *and* has a wide eye *and* carries `!`. A
## viewer who cannot separate the reds still reads the badge, and so does anyone
## looking at a greyscale screenshot in a bug report.

const CueModel := preload("res://scripts/models/player_cognition_cue.gd")

## Deliberately three hues, not a gradient. A badge is glanced at over a moving
## player, and a continuous colour ramp reads as one colour in motion.
const CALM_COLOR := Color(0.42, 0.62, 0.92)
const ALERT_COLOR := Color(0.95, 0.78, 0.24)
const URGENT_COLOR := Color(0.88, 0.30, 0.26)
const LOST_COLOR := Color(0.55, 0.55, 0.60)
const GOOD_COLOR := Color(0.28, 0.78, 0.42)

## Eye openness, as a share of the badge radius. Searching is narrow and
## scanning; recognition snaps wide; a lost sightline closes.
const EYE_SEARCHING: float = 0.42
const EYE_RECOGNIZING: float = 0.86
const EYE_COMMITTED: float = 0.70
const EYE_LOST: float = 0.12


## The full drawable reading of one cue.
##
## `pupil` is a unit-ish offset in the renderer's own screen space, so the
## caller supplies the direction to whatever the cue is attending to and this
## decides how far the eye travels toward it. A cue attending to nothing looks
## straight ahead rather than at the court's origin, which is what a raw
## `Vector2.ZERO` attention position would otherwise produce.
static func describe(cue: Resource, toward: Vector2 = Vector2.ZERO) -> Dictionary:
	if cue == null:
		return {}
	var state := str(cue.state)
	var urgency := clampf(float(cue.urgency), 0.0, 1.0)
	var certainty := clampf(float(cue.certainty), 0.0, 1.0)
	var visibility := str(cue.visibility)
	var eye := EYE_SEARCHING
	match state:
		"recognizing":
			eye = EYE_RECOGNIZING
		"committed", "calling":
			eye = EYE_COMMITTED
		"lost_sight":
			eye = EYE_LOST
		"reacting":
			eye = lerpf(EYE_SEARCHING, EYE_RECOGNIZING, float(cue.affect_intensity))
	if visibility == "occluded":
		eye = EYE_LOST
	elif visibility == "partially_obscured":
		eye = minf(eye, EYE_SEARCHING)

	var color := _color_for(cue)

	var direction := toward
	if direction.length() > 0.0001:
		## Bounded well inside the eye so the pupil never leaves it, which at a
		## twenty-pixel marker is the difference between a look and a defect.
		direction = direction.normalized() * clampf(certainty, 0.25, 1.0) * 0.42
	else:
		direction = Vector2.ZERO
	return {
		"eye_openness": clampf(eye, 0.0, 1.0),
		"pupil": direction,
		"color": color,
		## The icon names the volleyball job, while state controls whether that job
		## is still intent or has become execution.
		"icon": _icon_for(state, str(cue.action_kind), visibility),
		"punctuation": str(cue.punctuation),
		"is_call": state == "calling",
		"face": _face_for(cue),
		## -1, 0 or +1 rather than the raw float: an arrow either points up, down
		## or is not drawn, and a 0.08 trend drawn as a nearly-flat arrow reads as
		## a rendering error rather than as a small change.
		"trend_direction": (
			1 if float(cue.trend) > 0.15
			else (-1 if float(cue.trend) < -0.15 else 0)
		),
		"emphasis": clampf(maxf(urgency, float(cue.affect_intensity)), 0.0, 1.0),
	}


## Action decides the icon; state only decides which phase of that action is
## visible. Receive and floor-defence intent are shields and become eyes once
## the player moves. Blocking is the inverse: an eye reads the setter until the
## blocker commits, then the shield grades the wall. A call has no sound icon --
## the hitter's underlying attack remains a sword and punctuation carries voice.
static func _icon_for(state: String, action: String, visibility: String) -> String:
	if visibility != "visible" or state == "lost_sight":
		return "eye"
	match action:
		"receive", "defend":
			return "shield" if state == "committed" else "eye"
		"block":
			return "eye" if state == "searching" else "shield"
		"attack":
			return "sword"
	## Emotional aftermath deliberately has no generic reaction/burst icon. The
	## face and trend arrow already say what happened.
	if state == "reacting":
		return "none"
	return "eye"


## Graded execution owns colour. An eye that cannot see is always red; otherwise
## the common 0..1 execution scale reads red, amber, green. Ungraded cognition
## remains blue so confidence or urgency is never mistaken for performance.
static func _color_for(cue: Resource) -> Color:
	if str(cue.visibility) != "visible" or str(cue.state) == "lost_sight":
		return URGENT_COLOR
	var quality := float(cue.execution_quality)
	if quality >= 0.0:
		if quality >= 0.68:
			return GOOD_COLOR
		if quality >= 0.35:
			return ALERT_COLOR
		return URGENT_COLOR
	return CALM_COLOR


static func _face_for(cue: Resource) -> String:
	match str(cue.affect):
		"upset":
			return "upset"
		"sad":
			return "sad"
		"confident":
			return "confident"
		"pleased":
			return "pleased"
		"urgent":
			return "urgent"
	return ""


## Whether this cue is worth a badge at all.
##
## Idle ball-tracking is the floor of the priority ladder and is true of almost
## everyone almost always; drawing it would put a badge over all twelve players
## for the whole rally and turn the layer into wallpaper. The stream still
## carries those cues, because a renderer that wants to drive head direction
## from them should be able to.
static func is_worth_drawing(cue: Resource) -> bool:
	if cue == null:
		return false
	if str(cue.state) == "searching" and str(cue.attention_kind) == "ball" \
			and float(cue.urgency) < 0.65:
		return false
	return true
