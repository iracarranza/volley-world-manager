class_name FaceExpressions
extends RefCounted

## Faces, built from the same primitives as the rest of the body.
##
## The alternative was a drawn texture on a quad in front of the head, which is
## cheaper and gives finer control -- and would have read as a sticker. Every
## other feature on these bodies is a box or a sphere sitting in space, so a
## painted face would have been the only flat thing on an actor made of solids.
## Small solids projected onto the head's surface curve with it and light with
## it, which is what makes the face belong to the head rather than sit on it.
##
## Five expressions, deliberately few. These read at playback scale, where a head
## is a few dozen pixels tall and the only things that survive are the *sign* of
## the mouth curve and the *tilt* of the eyes. Subtler sets do not survive the
## distance, and a face nobody can read at match scale is a face that only exists
## in the roster.

const NEUTRAL: String = "neutral"

## The five, and what each is for.
##
## `mouth_curve` is signed: positive lifts the corners above the centre (a
## smile), negative drops them below it. `eye_tilt` is signed too, in degrees,
## and it is the whole difference between worried and cross -- inner ends raised
## reads as concern, inner ends lowered reads as a scowl, and nothing else about
## the two faces needs to differ. `eye_squash` flattens the eye toward a line.
const EXPRESSIONS := {
	## Corners up, eyes squeezed by the cheeks.
	"happy": {
		"mouth_curve": 1.00, "mouth_half_width": 0.36,
		"eye_tilt": 5.0, "eye_squash": 0.66,
	},
	## The default. Short flat mouth -- the `:l` of the pair.
	"neutral": {
		"mouth_curve": 0.00, "mouth_half_width": 0.19,
		"eye_tilt": 0.0, "eye_squash": 1.00,
	},
	## The long neutral, `:|`. Same zero curve, twice the width.
	##
	## Worth having as its own expression rather than as a wider neutral: a mouth
	## drawn right across the face with no curve at all is not a milder version of
	## anything, it is its own reading -- deadpan, unimpressed, waiting. It is the
	## face for a voli who has been told something and has not decided yet.
	"flat": {
		"mouth_curve": 0.00, "mouth_half_width": 0.44,
		"eye_tilt": 0.0, "eye_squash": 0.58,
	},
	## Corners down, inner brow ends up.
	"worried": {
		"mouth_curve": -0.62, "mouth_half_width": 0.26,
		"eye_tilt": 17.0, "eye_squash": 1.12,
	},
	## Corners further down, narrower, inner brow ends down.
	"cross": {
		"mouth_curve": -0.95, "mouth_half_width": 0.21,
		"eye_tilt": -21.0, "eye_squash": 0.88,
	},
}

## Where the features sit, in head-normalised coordinates: u across, v up, both
## on [-1, 1] against the head's own semi-axes. Authored this way so one set of
## numbers serves a 0.105-radius Stalk head and a 0.185-radius Feli head without
## a per-type table.
const EYE_U: float = 0.40
const EYE_V: float = 0.19
const MOUTH_V: float = -0.34
## How far the mouth's centre travels from its corners at full curve.
const MOUTH_BOW: float = 0.19
## Segments per mouth. Seven is where the curve stops reading as a staircase at
## roster distance; more costs mesh instances on every actor on court.
const MOUTH_SEGMENTS: int = 7

const EYE_WIDTH: float = 0.30
const EYE_HEIGHT: float = 0.30
const FEATURE_DEPTH: float = 0.10
const MOUTH_THICKNESS: float = 0.10
## Lift off the surface, in head radii. Enough that a feature never z-fights with
## the skull it is sitting on.
const SURFACE_LIFT: float = 0.02
## A muzzle is a much smaller sphere than a skull, so it curves away far faster
## under the same mouth. At the skull's lift the outer segments sank into it and
## the smile came out looking like gritted teeth -- a row of separate dark chips
## rather than one stroke.
const MUZZLE_LIFT: float = 0.13
## And the mouth has to sit nearer the muzzle's middle. `MOUTH_V` is authored for
## a face with a whole skull under it; carried straight onto a muzzle it lands on
## the bottom lip and falls off the curve.
const MUZZLE_V_COMPRESS: float = 0.50


static func names() -> Array[String]:
	var result: Array[String] = []
	for key in EXPRESSIONS:
		result.append(str(key))
	return result


static func has(expression: String) -> bool:
	return expression in EXPRESSIONS


## A stable face per voli.
##
## Hashed from the id the same way `BodyTypeModels.produce_for` picks a produce,
## so a voli wears the same face every time you open the roster. A face that
## resampled on each refresh would read as a bug even while working exactly as
## specified.
##
## This is a placeholder for a real decision, not the decision: see
## `docs/design/CLUB_LIFE.md` on whether an expression is part of who a voli is
## or a report on how they are doing. Random is what you use while that is
## unresolved, because it at least makes the roster look inhabited.
static func for_player(player_id: int) -> String:
	var ordered := names()
	ordered.sort()
	return ordered[absi(hash("face:%d" % player_id)) % ordered.size()]


## Every feature of one face, as specs the actor can hand straight to
## `BodyTypeModels.build_mesh`.
##
## `radius` is the head's horizontal semi-axis and `half_height` its vertical
## one -- heads are slightly wide ellipsoids rather than spheres, so a face
## authored against a single radius would sit too high and too narrow.
## `mouth_override`, when given, moves the mouth off the skull and onto whatever
## is already sticking out of the face. See `_build_face` -- it is derived from
## the body type's own cosmetics rather than restated here, so a muzzle that
## moves takes its mouth with it.
##   `anchor` -- head-local centre to draw the mouth around
##   `scale`  -- width multiplier, since a muzzle is narrower than a skull
##   `omit`   -- the part *is* the mouth; draw eyes only
static func parts(
	expression: String, radius: float, half_height: float,
	mouth_override: Dictionary = {}
) -> Array[Dictionary]:
	var spec: Dictionary = EXPRESSIONS.get(
		expression, EXPRESSIONS[NEUTRAL]
	)
	var result: Array[Dictionary] = []
	var squash := float(spec.get("eye_squash", 1.0))
	var tilt := float(spec.get("eye_tilt", 0.0))
	for side in [-1.0, 1.0]:
		result.append({
			"name": "EyeL" if side < 0.0 else "EyeR",
			"shape": "box",
			"size": Vector3(
				EYE_WIDTH * radius,
				EYE_HEIGHT * radius * squash,
				FEATURE_DEPTH * radius,
			),
			"position": _surface(EYE_U * side, EYE_V, radius, half_height),
			## Mirrored, so a positive tilt raises the *inner* end on both sides
			## rather than rotating the whole face one way.
			##
			## Negated because the rig faces -Z: a positive rotation about Z reads
			## as *clockwise* to anyone standing in front of the voli, which lifts
			## the outer end rather than the inner one. Without this, worried and
			## cross wear each other's brows -- the mouths stay right and only the
			## eyes swap, which is the worst kind of wrong, because both faces
			## still look like perfectly good faces.
			"rotation": Vector3(0.0, 0.0, -tilt * side),
		})

	if bool(mouth_override.get("omit", false)):
		return result

	var mouth_scale := float(mouth_override.get("scale", 1.0))
	var anchor: Variant = mouth_override.get("anchor")
	var half_width := float(spec.get("mouth_half_width", 0.2)) * mouth_scale
	var curve := float(spec.get("mouth_curve", 0.0))
	var step := 2.0 * half_width / float(MOUTH_SEGMENTS - 1)
	for index in range(MOUTH_SEGMENTS):
		var u := -half_width + step * float(index)
		var along := u / maxf(half_width, 0.0001)
		## Parabola: at the corners the offset is zero, at the centre it is full.
		## A positive curve therefore drops the centre and leaves the corners
		## high, which is a smile.
		var v := MOUTH_V - curve * MOUTH_BOW * (1.0 - along * along)
		var position: Vector3
		if anchor == null:
			position = _surface(u, v, radius, half_height)
		else:
			## Wrapped onto the muzzle exactly the way it wraps a head, by handing
			## `_surface` the muzzle's own semi-axes. The first attempt drew the
			## mouth flat and offset it from the head's dimensions, which put it on
			## the muzzle's bottom lip where it disappeared over the curve.
			position = (anchor as Vector3) + _surface(
				u / maxf(mouth_scale, 0.001),
				v * MUZZLE_V_COMPRESS,
				float(mouth_override.get("radius", radius)),
				float(mouth_override.get("half_height", half_height)),
				MUZZLE_LIFT,
			)
		## Segments overlap by a quarter so the mouth reads as one stroke
		## rather than as beads.
		result.append({
			"name": "Mouth%d" % index,
			"shape": "box",
			"size": Vector3(
				step * radius * 1.25,
				MOUTH_THICKNESS * radius,
				FEATURE_DEPTH * radius,
			),
			"position": position,
			"rotation": Vector3.ZERO,
		})
	return result


## Project a normalised (u, v) onto the front of the head's ellipsoid.
##
## The head is (x/radius)^2 + (y/half_height)^2 + (z/radius)^2 = 1, so with u and
## v already normalised against their own semi-axes the depth falls straight out.
## Forward is -Z, matching the rest of the rig.
static func _surface(
	u: float, v: float, radius: float, half_height: float,
	lift: float = SURFACE_LIFT
) -> Vector3:
	var inside := clampf(1.0 - u * u - v * v, 0.0, 1.0)
	var depth := sqrt(inside)
	return Vector3(
		u * radius,
		v * half_height,
		-(depth + lift) * radius,
	)
