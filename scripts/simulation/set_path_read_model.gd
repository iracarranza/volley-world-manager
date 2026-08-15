class_name SetPathReadModel
extends RefCounted

const CourtConstants := preload("res://scripts/data/court_constants.gd")

## The ball contact and the hitter's centre are not the same point. A hitter
## takes off behind the ball and reaches forward through it; placing their body
## on a set 20 cm from the tape visibly puts their torso through the net even
## when the ball itself is legal.
const BODY_BEHIND_CONTACT_WINGSPAN_SHARE: float = 0.28
const BODY_BEHIND_CONTACT_MIN_METERS: float = 0.42
const BODY_BEHIND_CONTACT_MAX_METERS: float = 0.66
## A swing is contacted above the striking shoulder, not on the body's centre
## line. Keeping x identical put the ball between the hands and could make a
## dominant-hand swing visibly meet the off hand. This is the lateral shoulder /
## reach share the body gives the ball, bounded for extreme wingspans.
const BODY_BESIDE_CONTACT_WINGSPAN_SHARE: float = 0.105
const BODY_BESIDE_CONTACT_MIN_METERS: float = 0.16
const BODY_BESIDE_CONTACT_MAX_METERS: float = 0.26

## Residual path-reading error after the hitter has observed the release. These
## are metres on the court, not normalized coordinates. The setter's actual
## miss contributes separately: a poor reader also keeps moving toward the spot
## they expected instead of fully correcting to the delivered ball.
const READ_ERROR_WORST_METERS: float = 0.46
const READ_ERROR_BEST_METERS: float = 0.045
const READ_FLIGHT_FULL_SECONDS: float = 1.05
const READ_FLIGHT_MIN_SECONDS: float = 0.20

## Contact bands. Clean is where ordinary arm adjustment absorbs the read;
## recoverable is the edge of a one-handed/off-axis swing. The latter expands
## with wingspan and control, so the same path error is not the same ball for
## every hitter.
const CLEAN_ERROR_WORST_METERS: float = 0.13
const CLEAN_ERROR_BEST_METERS: float = 0.25
const RECOVERABLE_ERROR_WORST_METERS: float = 0.52
const RECOVERABLE_ERROR_BEST_METERS: float = 0.82
const MISHIT_QUALITY_FLOOR: float = 0.34


## Where the hitter's centre should be when the hands meet this ball.
## `attacking_negative_y` is true for the home side, whose attack travels toward
## decreasing y; their body is therefore behind the ball at greater y.
static func body_position(
	hitter: VolleyballPlayer,
	ball_contact: Vector2,
	attacking_negative_y: bool,
) -> Vector2:
	var wingspan_m := float(hitter.wingspan_cm) / 100.0 \
		if hitter != null else 1.90
	var behind := clampf(
		wingspan_m * BODY_BEHIND_CONTACT_WINGSPAN_SHARE,
		BODY_BEHIND_CONTACT_MIN_METERS, BODY_BEHIND_CONTACT_MAX_METERS,
	)
	var direction := 1.0 if attacking_negative_y else -1.0
	var lateral_reach := clampf(
		wingspan_m * BODY_BESIDE_CONTACT_WINGSPAN_SHARE,
		BODY_BESIDE_CONTACT_MIN_METERS, BODY_BESIDE_CONTACT_MAX_METERS,
	)
	## Local right points toward +x for a home hitter facing -y and toward -x
	## for an opponent hitter facing +y. A left hand mirrors it.
	var local_right_world_x := 1.0 if attacking_negative_y else -1.0
	var striking_side := -1.0 \
		if hitter != null and str(hitter.dominant_hand) == "Left" else 1.0
	var body := Vector2(
		ball_contact.x - local_right_world_x * striking_side \
			* lateral_reach / CourtConstants.COURT_WIDTH_METERS,
		ball_contact.y + direction * behind / CourtConstants.COURT_LENGTH_METERS,
	)
	## A legal ball can be extremely tight; a torso cannot occupy the tape.
	var minimum_body_depth := BODY_BEHIND_CONTACT_MIN_METERS \
		/ CourtConstants.COURT_LENGTH_METERS
	body.y = maxf(body.y, CourtConstants.NET_Y + minimum_body_depth) \
		if attacking_negative_y else minf(
			body.y, CourtConstants.NET_Y - minimum_body_depth
		)
	return body


## What contact point the hitter believes the released set will reach.
##
## `intended_contact` is the spot the hitter asked for; `delivered_contact` is
## where the set is actually going. Tracking blends between them, then carries
## a residual perception error. A fast tempo offers fewer frames of evidence,
## pair familiarity supplies expectation, and the hitter's own vision,
## anticipation and approach timing decide how much they can correct in motion.
static func evaluate(
	hitter: VolleyballPlayer,
	intended_contact: Vector2,
	delivered_contact: Vector2,
	flight_seconds: float,
	set_quality: float,
	pair_familiarity: float,
	seed_value: int,
	salt: String,
	attacking_negative_y: bool,
) -> Dictionary:
	var ability := clampf((
		float(hitter.court_vision) * 0.34
			+ float(hitter.anticipation) * 0.26
			+ float(hitter.approach_timing) * 0.30
			+ float(hitter.composure) * 0.10
	) / 100.0, 0.0, 1.0) if hitter != null else 0.0
	var flight_read := smoothstep(
		READ_FLIGHT_MIN_SECONDS, READ_FLIGHT_FULL_SECONDS,
		maxf(flight_seconds, 0.0),
	)
	var tracking := clampf(
		ability * 0.58 + flight_read * 0.24
			+ clampf(pair_familiarity, 0.0, 1.0) * 0.18,
		0.0, 1.0,
	)
	var perceived := intended_contact.lerp(delivered_contact, tracking)
	var error_band := lerpf(
		READ_ERROR_WORST_METERS, READ_ERROR_BEST_METERS, tracking
	) * lerpf(1.18, 0.82, clampf(set_quality, 0.0, 1.0))
	var key := seed_value + (hitter.id if hitter != null else -1) * 8191 \
		+ hash(salt)
	var error_x := _signed_hash(key + 17) * error_band
	var error_y := _signed_hash(key + 53) * error_band * 0.78
	perceived += Vector2(
		error_x / CourtConstants.COURT_WIDTH_METERS,
		error_y / CourtConstants.COURT_LENGTH_METERS,
	)
	## A perception can be wrong, but it does not tell a hitter to take off on
	## the other side of the tape. That would be a net-crossing decision rather
	## than a path read.
	var own_side_floor := 0.505
	perceived.y = maxf(perceived.y, own_side_floor) \
		if attacking_negative_y else minf(perceived.y, 1.0 - own_side_floor)
	var ideal_body := body_position(
		hitter, delivered_contact, attacking_negative_y
	)
	var perceived_body := body_position(
		hitter, perceived, attacking_negative_y
	)
	return {
		"read_quality": tracking,
		"ability": ability,
		"flight_read": flight_read,
		"pair_familiarity": clampf(pair_familiarity, 0.0, 1.0),
		"intended_contact": intended_contact,
		"delivered_contact": delivered_contact,
		"perceived_contact": perceived,
		"ideal_body_position": ideal_body,
		"perceived_body_position": perceived_body,
		"perception_error_meters": _court_distance_meters(
			perceived, delivered_contact
		),
		"delivery_error_meters": _court_distance_meters(
			intended_contact, delivered_contact
		),
		"residual_error_band_meters": error_band,
		"uses_delivered_truth": false,
	}


## Whether the body that actually arrived can still play the ball.
static func assess_contact(
	hitter: VolleyballPlayer,
	actual_body_position: Vector2,
	ideal_body_position: Vector2,
) -> Dictionary:
	var error := _court_distance_meters(
		actual_body_position, ideal_body_position
	)
	var control := clampf((
		float(hitter.approach_timing) * 0.34
			+ float(hitter.attack_accuracy) * 0.26
			+ float(hitter.ball_control) * 0.20
			+ float(hitter.improvisation) * 0.20
	) / 100.0, 0.0, 1.0) if hitter != null else 0.0
	var wingspan := clampf(
		inverse_lerp(1.65, 2.20, float(hitter.wingspan_cm) / 100.0),
		0.0, 1.0,
	) if hitter != null else 0.5
	var clean := lerpf(CLEAN_ERROR_WORST_METERS, CLEAN_ERROR_BEST_METERS, control)
	var recoverable := lerpf(
		RECOVERABLE_ERROR_WORST_METERS, RECOVERABLE_ERROR_BEST_METERS,
		control * 0.72 + wingspan * 0.28,
	)
	var severity := smoothstep(clean, recoverable, error)
	var outcome := "clean"
	if error > recoverable:
		outcome = "whiff"
	elif error > clean + (recoverable - clean) * 0.58:
		outcome = "mishit"
	elif error > clean:
		outcome = "strained"
	return {
		"outcome": outcome,
		"error_meters": error,
		"clean_error_meters": clean,
		"recoverable_error_meters": recoverable,
		"severity": severity,
		"quality_multiplier": 0.0 if outcome == "whiff" \
			else lerpf(1.0, MISHIT_QUALITY_FLOOR, severity),
		"whiffed": outcome == "whiff",
	}


static func _court_distance_meters(a: Vector2, b: Vector2) -> float:
	var delta := a - b
	return Vector2(
		delta.x * CourtConstants.COURT_WIDTH_METERS,
		delta.y * CourtConstants.COURT_LENGTH_METERS,
	).length()


static func _signed_hash(value: int) -> float:
	return float(posmod(value * 2654435761, 2001)) / 1000.0 - 1.0
