class_name PlayerSightlineSystem
extends RefCounted

const BallFlightModel := preload("res://scripts/simulation/ball_flight_model.gd")

const COURT_WIDTH_METERS: float = 9.0
const COURT_DEPTH_METERS: float = 18.0
const NET_HEIGHT_METERS: float = CourtConstants.NET_HEIGHT_METERS
const DEFAULT_EYE_HEIGHT_METERS: float = 1.72
## Only a fallback now, for a caller that cannot name the blockers. It used to be
## the answer for every block in the game, and as an answer it was wrong: 2.72 m
## is the tape plus a fist, while a blocker's hands are at their jumping reach,
## most of half a metre higher. A wall that short cannot hide a spike, which is
## why the honest geometry had nothing left to report until the real reach
## arrived.
const DEFAULT_BLOCK_TOP_METERS: float = 2.72
const BLOCK_HALF_WIDTH_METERS: float = 0.48
const SAMPLE_COUNT: int = 32

## How far a blocker's hands reach past the tape, and therefore where the far
## face of the wall is.
##
## **This constant is the fix for a wall that had no depth.** The test below used
## to cross each ray with the net plane itself, which quietly asserts that the
## blocker is an infinitely thin curtain -- and an infinitely thin curtain hides
## a ball that is level with it, because "level with" and "behind" are the same
## thing when the thing has no thickness. Measured on 283 real swings, the median
## sample the wall was credited with hiding had the ball **0.39 m past the tape**:
## beside the hands, inside the block's own reach, not behind them. At that depth
## the ray's crossing point sits 80% of the way to the ball, so the observer's
## own position contributed a fifth of the verdict and the wall hid a band **8.7
## metres wide on a 9-metre court** -- from a silhouette 0.96 m across. The
## docstring below promised geometry that "can differ for two defenders behind
## one wall"; it could not.
##
## A ball is behind the hands only once it is past the far face of them, and this
## is that face. Penetration over the net is a rule as much as an anatomy: a
## blocker may reach over, and a third of a metre is about as far as one does
## while still being able to block rather than merely stand.
const BLOCK_REACH_DEPTH_METERS: float = 0.35


## Returns the interval in which a particular defender's ray to the sampled
## ball crosses an occupied blocker silhouette. It is geometry, not a block-
## strategy bonus, and can therefore differ for two defenders behind one wall.
##
## That last clause was an assertion for as long as this file existed and is now
## a measurement. On 243 swings where the wall did not touch the ball
## (`tools/run_sightline_probe.gd`), the share of swings a defender saw cleanly
## runs 0.49 / 0.75 / 0.91 as they stand 0-1.5 m, 1.5-3 m and over 3 m off the
## blocker's line, and being fully blind is 9.4% behind the wall against 2.5%
## in the cross lane. The before-figure on the same probe is the flat one: 47.6%
## of defenders standing more than 1.5 m off the blocker's line lost the ball
## anyway, against 15.3% now.
static func occlusion_window(
	observer_position: Vector2,
	trajectory: Dictionary,
	block_event: Resource,
	observer_profile: Dictionary = {},
	## How high the hands actually got, in metres. Passed in rather than read off
	## the block event because the event does not carry it: `contact_height_meters`
	## was published on **0 of 207** blocks sampled, so the read that used to sit
	## below always collapsed to `DEFAULT_BLOCK_TOP_METERS` and every wall in the
	## game was the same height -- a height, at 2.72 m, that is the tape plus a
	## fist rather than anybody's reach. `BallPresentation.contact_height` already
	## resolves this from the blocker's own body for the renderer, and every
	## caller that has a block event has the profiles too.
	blocker_top_meters: float = -1.0,
) -> Dictionary:
	if trajectory.is_empty() or block_event == null:
		return {"occluded": false}
	var start_time := float(trajectory.get("start_time", 0.0))
	var duration := maxf(float(trajectory.get("duration", 0.0)), 0.01)
	var hidden_start := -1.0
	var hidden_end := -1.0
	var hidden_samples := 0
	for sample_index in range(SAMPLE_COUNT + 1):
		var progress := float(sample_index) / float(SAMPLE_COUNT)
		var ball_position := _trajectory_position(trajectory, progress)
		var hidden := _sample_is_hidden(
			observer_position, ball_position,
			_trajectory_height(trajectory, progress), block_event,
			float(observer_profile.get("eye_height_meters", DEFAULT_EYE_HEIGHT_METERS)),
			blocker_top_meters if blocker_top_meters > 0.0
				else DEFAULT_BLOCK_TOP_METERS,
		)
		var sample_time := start_time + duration * progress
		if hidden:
			hidden_samples += 1
			if hidden_start < 0.0:
				hidden_start = sample_time
			hidden_end = sample_time
	if hidden_start < 0.0:
		return {
			"occluded": false,
			"hidden_fraction": 0.0,
			"sample_count": SAMPLE_COUNT + 1,
		}
	var reacquired := minf(
		hidden_end + duration / float(SAMPLE_COUNT), start_time + duration
	)
	return {
		"occluded": true,
		"starts_at": hidden_start,
		"ends_at": reacquired,
		"reacquired_at": reacquired,
		"hidden_sample_count": hidden_samples,
		"sample_count": SAMPLE_COUNT + 1,
		## How long the defender had the ball in sight before it arrived, which is
		## the quantity a dig is actually made out of. Published here because it is
		## the only place that knows both when the wall gave the ball back and when
		## the flight ends -- `visibility_for` receives a window, not a trajectory.
		"seen_for_seconds": maxf(start_time + duration - reacquired, 0.0),
		## How much of the flight the wall actually took away.
		##
		## Published because the *degree* is the whole distinction between a
		## defender who briefly lost the ball behind an arm and one who never saw
		## it leave the hitter's hand, and the boolean above cannot express it.
		## Classified in perception, by `visibility_for`, so no renderer ever has
		## to decide what "partially" means.
		"hidden_fraction": float(hidden_samples) / float(SAMPLE_COUNT + 1),
	}


## What a defender's sightline reads as, from **how long they had the ball once
## the wall gave it back**.
##
## The previous pair of thresholds acted on the share of the *flight* that was
## hidden, and that is the wrong instrument in the specific way §0 warns about.
## A share of flight time says nothing about whether the defender could still
## play the ball: losing a ball for the first fifth of its flight and picking it
## up with four fifths to run is an ordinary blocked-view swing, while losing it
## for the same fifth immediately before it lands is a defender who never saw it.
## The old numbers could not tell those apart, and because a slow roll shot
## spends a large share of a short flight near the net, they read the harmless
## case as the severe one -- which is exactly what the screenshot caught.
##
## The replacement is not a new dial. The floor defence already decides how long
## a defender needs, in `rally_simulator._floor_defense_terms`: reaction delay
## runs `lerpf(0.34, 0.12, anticipation)`, from the slowest read in the game to
## the fastest. Those two numbers are the band, borrowed rather than invented.
## Reacquire the ball with more time left than even a *slow* defender needs and
## nothing was taken from you; reacquire it with less than the *quickest*
## defender needs and nothing was given back.
const SLOW_REACTION_SECONDS: float = 0.34
const QUICK_REACTION_SECONDS: float = 0.12


static func visibility_for(window: Dictionary) -> StringName:
	if not bool(window.get("occluded", false)):
		return &"visible"
	var seen_for := float(window.get("seen_for_seconds", 0.0))
	if seen_for >= SLOW_REACTION_SECONDS:
		return &"visible"
	if seen_for <= QUICK_REACTION_SECONDS:
		return &"occluded"
	return &"partially_obscured"


static func _sample_is_hidden(
	observer: Vector2,
	ball: Vector2,
	ball_height: float,
	block_event: Resource,
	eye_height: float,
	blocker_top: float,
) -> bool:
	var net_y := 0.5
	var span := ball.y - observer.y
	if absf(span) < 0.0001:
		return false
	## The plane that actually does the hiding is the **far face of the hands**,
	## not the tape. Which side of the tape that face sits on depends on who is
	## looking: a defender watching a ball come toward them sees the far face as
	## the one further away, so the wall is pushed away from the observer by the
	## blocker's reach. Crossing the tape instead is what let a ball still level
	## with the hands count as being behind them.
	var wall_y := net_y \
		+ signf(span) * BLOCK_REACH_DEPTH_METERS / COURT_DEPTH_METERS
	var ray_fraction := (wall_y - observer.y) / span
	## The wall only obscures a ball on the far side of it. `>= 1.0` is now a
	## real statement rather than a formality: a ball inside the blocker's own
	## reach fails it, which is the whole correction.
	if ray_fraction <= 0.0 or ray_fraction >= 1.0:
		return false
	var ray_x := lerpf(observer.x, ball.x, ray_fraction)
	var ray_height := lerpf(eye_height, ball_height, ray_fraction)
	## The wall runs from about the top of the net -- below that a ball is under
	## the tape and the block is irrelevant to it -- to the top of the hands.
	if ray_height < NET_HEIGHT_METERS or ray_height > blocker_top:
		return false
	var blocker_specs: Array[Dictionary] = []
	blocker_specs.append({
		"position": Vector2(block_event.metadata.get(
			"primary_position", Vector2(block_event.start_position.x, net_y)
		)),
		"close": float(block_event.metadata.get("primary_close", 0.0)),
	})
	if int(block_event.metadata.get("assist_id", -1)) >= 0:
		blocker_specs.append({
			"position": Vector2(block_event.metadata.get(
				"assist_position", Vector2(block_event.start_position.x, net_y)
			)),
			"close": float(block_event.metadata.get("assist_close", 0.0)),
		})
	for spec in blocker_specs:
		var close := clampf(float(spec.close), 0.0, 1.0)
		if close < 0.20:
			continue
		var half_width := BLOCK_HALF_WIDTH_METERS / COURT_WIDTH_METERS \
			* lerpf(0.55, 1.15, close)
		if absf(ray_x - Vector2(spec.position).x) <= half_width:
			return true
	return false


static func _trajectory_position(trajectory: Dictionary, progress: float) -> Vector2:
	var start := Vector2(trajectory.get("start_position", Vector2.ZERO))
	var end := Vector2(trajectory.get("end_position", start))
	var control := Vector2(trajectory.get("control_position", start.lerp(end, 0.5)))
	var inverse := 1.0 - progress
	return inverse * inverse * start + 2.0 * inverse * progress * control \
		+ progress * progress * end


static func _trajectory_height(trajectory: Dictionary, progress: float) -> float:
	return BallFlightModel.height_between(
		float(trajectory.get("start_height_meters", 2.8)),
		float(trajectory.get("end_height_meters", 0.2)),
		maxf(float(trajectory.get("duration", 0.1)), 0.01),
		progress,
	)
