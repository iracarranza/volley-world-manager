class_name PlatformAim
extends RefCounted

## Where a passer's forearms must point for the ball to leave the way it did.
##
## **A ball rebounds about the normal of the surface it hits.** That is the whole
## model: the platform's facing is the bisector of the incoming and outgoing
## directions, and both of those are already stamped on every reception and dig
## event as `incoming_trajectory` and `outgoing_trajectory`. Nothing here is
## estimated and nothing new is simulated -- this reads two facts the resolver
## already published and says what arms consistent with them look like.
##
## **Why this belongs to playback and not to the simulator.** The resolver
## decides *where the ball goes* from platform feasibility, body alignment and
## execution; adding an arm angle to that decision would be a second opinion
## about an outcome it already owns. But it never says where the arms *were*,
## because it does not need to -- so the drawing was left to invent them, and it
## invented a constant. The angle is therefore derived here, downstream, from the
## result rather than as an input to it. The simulator stays the authority; the
## drawing stops contradicting it.
##
## Before this, `platform_yaw` was 0 for a planted contact and 30 for an
## off-axis one, and `contact_direction` was passed into the pose and forwarded
## only to the recovery. The arms never saw the ball at all: every square pass in
## the game had identical forearms regardless of whether the ball came from the
## service line or off a blocker's hands two metres away.

## Visual vocabulary semantics
##
## This supplies the contact-facing detail shared by clean, moving, strained,
## reaching, and off-axis reception/dig poses. A comfortable platform keeps most
## of the correction in the forearms; awkward geometry carries the residual into
## trunk turn and stance. It describes the platform consistent with the recorded
## flights and never revises the contact or its result.

const BallFlightModel := preload("res://scripts/simulation/ball_flight_model.gd")
const CourtWidthMeters: float = 9.0
const CourtLengthMeters: float = 18.0

## How far a passer can take the platform off the line their body faces before
## the body has to come with it.
##
## Shoulders and a trunk twist buy roughly this much; past it a player is not
## angling a platform, they are turning to face somewhere else. The residual
## past this bound is exactly what makes a contact off-axis, which is what
## `posture_for` returns it for.
const MAX_PLATFORM_YAW_DEGREES: float = 46.0
## And how far off square the platform is allowed to read at all before the
## contact is something other than a pass -- a one-arm dig, a shoulder. Past
## this the drawing should stop pretending it is a platform.
const EXTREME_YAW_DEGREES: float = 88.0

## Pitch bounds. A platform is a surface out in front, angled down toward the
## incoming ball and up toward the target; it is never vertical and never flat.
const MIN_PITCH_DEGREES: float = -34.0
const MAX_PITCH_DEGREES: float = 38.0


## The platform's required facing, in world terms, from the two flights.
##
## Returns `valid = false` when either flight is missing, which is the honest
## answer for a contact whose trajectories were not published -- the caller then
## keeps whatever the posture would have given it, rather than being handed a
## confident zero.
static func solve(
	incoming_trajectory: Dictionary, outgoing_trajectory: Dictionary
) -> Dictionary:
	var incoming := _direction_of(incoming_trajectory, true)
	var outgoing := _direction_of(outgoing_trajectory, false)
	if incoming == Vector3.ZERO or outgoing == Vector3.ZERO:
		return {"valid": false, "yaw_degrees": 0.0, "pitch_degrees": 0.0}
	## The bisector. `-incoming` because the normal points back along the way the
	## ball came, not with it.
	var normal := (-incoming).normalized() + outgoing.normalized()
	if normal.length_squared() < 0.0001:
		## The ball came straight back the way it arrived -- a dead-on dig. The
		## normal is degenerate, so take the outgoing line, which is the one a
		## viewer can check against the drawn flight.
		normal = outgoing.normalized()
	normal = normal.normalized()
	var horizontal := Vector2(normal.x, normal.z)
	if horizontal.length_squared() < 0.000001:
		return {"valid": false, "yaw_degrees": 0.0, "pitch_degrees": 0.0}
	return {
		"valid": true,
		## Court yaw: 0 points down-court, positive toward +x, matching how
		## `_turn_toward` reads a heading.
		"yaw_degrees": rad_to_deg(atan2(horizontal.x, horizontal.y)),
		"pitch_degrees": clampf(
			rad_to_deg(asin(clampf(normal.y, -1.0, 1.0))),
			MIN_PITCH_DEGREES, MAX_PITCH_DEGREES,
		),
	}


## The platform's facing relative to the body, and what is left over.
##
## `body_yaw_degrees` is where the passer is facing. The platform can be taken
## `MAX_PLATFORM_YAW_DEGREES` off that; whatever remains is the part the body
## could not absorb, and it is the honest measure of "could not square up".
static func relative(
	aim: Dictionary, body_yaw_degrees: float
) -> Dictionary:
	if not bool(aim.get("valid", false)):
		return {"valid": false, "yaw_degrees": 0.0, "residual_degrees": 0.0}
	var wanted := rad_to_deg(angle_difference(
		deg_to_rad(body_yaw_degrees), deg_to_rad(float(aim.yaw_degrees))
	))
	var allowed := clampf(
		wanted, -MAX_PLATFORM_YAW_DEGREES, MAX_PLATFORM_YAW_DEGREES
	)
	return {
		"valid": true,
		"yaw_degrees": allowed,
		"pitch_degrees": float(aim.pitch_degrees),
		## Signed, so a renderer can lean the trunk the way the reach went.
		"residual_degrees": wanted - allowed,
	}


## Which posture the geometry itself implies.
##
## The simulator classifies a contact from alignment and edge-ratio thresholds,
## and two of its four branches are unreachable -- measured, `reaching` fires on
## 0.0% of receptions and `off-axis` on 2.5% of digs. This does **not** replace
## that classification; the resolver owns what a contact *cost*. It is a second,
## purely geometric opinion about what the contact *looked like*, and playback
## takes whichever of the two is more specific.
##
## A body that had to give up more than a few degrees of platform was not square,
## whatever the alignment term said about it.
static func posture_for(relative_aim: Dictionary, fallback: String) -> String:
	if not bool(relative_aim.get("valid", false)):
		return fallback
	var residual := absf(float(relative_aim.get("residual_degrees", 0.0)))
	if residual >= EXTREME_YAW_DEGREES - MAX_PLATFORM_YAW_DEGREES:
		return "reaching"
	if residual > 1.0:
		return "off-axis"
	return fallback


## A flight's direction as a 3D vector in metres, at the end a contact happens.
##
## `at_end` picks which end: a ball *arriving* is read at the end of its flight,
## a ball *leaving* at the start of its. Reading both from the same end is how a
## bisector ends up describing the wrong two lines.
static func _direction_of(trajectory: Dictionary, at_end: bool) -> Vector3:
	if trajectory.is_empty():
		return Vector3.ZERO
	var start := Vector2(trajectory.get("start_position", Vector2.ZERO))
	var end := Vector2(trajectory.get("end_position", start))
	var horizontal := Vector2(
		(end.x - start.x) * CourtWidthMeters,
		(end.y - start.y) * CourtLengthMeters,
	)
	if horizontal.length_squared() < 0.000001:
		return Vector3.ZERO
	var duration := maxf(float(trajectory.get("duration", 0.0)), 0.01)
	## The vertical component from the flight's own gravity solve rather than
	## from the two endpoint heights: a ball that rose and fell between them has
	## a straight-line slope of zero and a real vertical speed of several metres
	## per second, and the platform is angled against the second one.
	var vertical := BallFlightModel.rise_speed_between(
		float(trajectory.get("start_height_meters", 2.0)),
		float(trajectory.get("end_height_meters", 0.9)),
		duration,
		1.0 if at_end else 0.0,
	)
	var horizontal_speed := horizontal.length() / duration
	return Vector3(
		horizontal.x / duration, vertical, horizontal.y / duration
	).normalized() if horizontal_speed > 0.0 else Vector3.ZERO
