class_name HitterPlacementModel
extends RefCounted

## Where a hitter wants the ball, inside the lane they were assigned.
##
## The set target used to be `CourtConstants.lane_target(lane)` -- one constant
## per lane, aimed at by the setter, with execution scatter as the only reason
## two attacks ever happened anywhere different. That has the causality backwards.
## A setter does not pick a dot and hope; a hitter has a spot they like and the
## setter tries to put the ball there. The lane names the region, the hitter names
## the coordinate inside it, and the setter's accuracy decides how close the ball
## comes to what was asked for.
##
## Three things decide the coordinate:
##
##   familiarity   a hitter drilled in this position sits near the middle of the
##                 lane where the shot is; one playing out of position drifts
##   memory        where this rally's swings have been working, and where they
##                 have not
##   unpredictability  how much a hitter refuses to settle into either
##
## The third is what stops the second from collapsing the offence onto a point.
## A hitter who learns hard and varies little becomes readable in a way the block
## already has the machinery to punish -- `OpponentTeam.observe_rally` counts
## lanes and tempos, and `anticipated_lane()` feeds the wall. This is the same
## loop pointed at coordinates, with a resistance term.

const CourtConstants := preload("res://scripts/data/court_constants.gd")
const FeatureFlags := preload("res://scripts/simulation/rally_feature_flags.gd")

## How far into a lane an unfamiliar hitter drifts from its middle, as a share of
## the lane's own half-width. A hitter who has never played the position does not
## have a spot; they take whatever the lane gives them.
const FAMILIARITY_DRIFT: float = 0.62
## How far a hitter's placement wanders rally to rally at full unpredictability,
## in metres along the net. Read against a lane about two metres wide: this moves
## a ball around inside its own lane rather than into the next one.
const UNPREDICTABLE_JITTER_METERS: float = 0.55
## How hard success and failure pull the preferred spot, in metres per swing.
##
## Sized against the number of swings a hitter actually takes in a match rather
## than picked for feel: a home hitter takes roughly a dozen, so a rate that
## moves the spot a tenth of a metre a swing can travel about a lane's half-width
## across a match and no further. A rate that could cross the lane in three
## swings would be a hitter with no habits at all.
const LEARNING_RATE_METERS: float = 0.11
## How much of what a hitter learned survives to the next swing. Not one, or a
## spot that worked in the first rotation still drags the offence in the fifth.
const MEMORY_RETENTION: float = 0.93
## The furthest the learned bias may travel from where the hitter started, in
## metres. A habit, not a relocation -- and it keeps the bias inside the lane
## without the clamp being the thing that decides placement.
const MEMORY_LIMIT_METERS: float = 1.10
## No set is tighter than this. A ball closer to the tape than a hand is not a
## set a hitter asks for, it is one the setter lost.
const TIGHTNESS_FLOOR_METERS: float = 0.18


## The point this hitter wants, in normalised court coordinates.
##
## `rally_seed` and the player's id together give a per-rally draw that consumes
## no `RandomNumberGenerator`, so adding this re-sequences nothing -- the same
## reason `_fallback_hitter`'s spread term was written that way before it became
## a real distribution.
static func preferred_point(
	hitter: VolleyballPlayer,
	lane: String,
	rally_seed: int,
	swing_index: int,
) -> Vector2:
	var span := CourtConstants.lane_range(lane)
	var centre := (span.x + span.y) * 0.5
	var half_width := maxf((span.y - span.x) * 0.5, 0.001)
	if hitter == null:
		return Vector2(centre, CourtConstants.lane_target(lane).y)

	## Where they sit in the lane before anything has happened this rally.
	##
	## Stable per player, so a hitter has a spot rather than a fresh opinion every
	## rally, and pushed toward the lane's edges as familiarity falls.
	var familiarity := _familiarity(hitter, lane)
	var seat := _signed_hash(hitter.id * 7919 + hash(lane), 1.0) \
		* half_width * FAMILIARITY_DRIFT * (1.0 - familiarity)

	## What this rally has taught them, and how much they let it.
	var unpredictability := clampf(float(hitter.unpredictability) / 100.0, 0.0, 1.0)
	var learned := _memory(hitter).get(lane, Vector2.ZERO) as Vector2
	var settle := 1.0 - unpredictability

	var jitter := _signed_hash(
		rally_seed + hitter.id * 131 + swing_index * 17, 1.0
	) * UNPREDICTABLE_JITTER_METERS * unpredictability

	var x := centre + seat \
		+ (float(learned.x) * settle + jitter) / CourtConstants.COURT_WIDTH_METERS
	## Never outside the lane they were assigned. The lane is the instruction; the
	## coordinate is how they read it.
	return Vector2(
		clampf(x, span.x, span.y),
		_depth(hitter, lane, learned, settle, rally_seed, swing_index),
	)


## How tight to the net this hitter wants it, inside the depth their lane allows.
##
## The zone owns the range now, so a quick is tight because quicks are tight and
## a pipe is deep because pipes are deep, rather than every lane sharing one
## constant with a special case bolted on for the pipe. That also makes this
## measurable: contact depth can be summarised per lane instead of pooled across
## lanes whose depths have nothing to do with each other, which is what made the
## first sweep of this unreadable.
##
## `seat` is not scaled by `settle`, and that was the bug in the first cut. An
## unpredictable hitter should have a preferred depth they vary *around*, not no
## preference at all -- multiplying the seat by `1 - unpredictability` gave the
## least predictable hitters the most rigidly central depth, which is backwards.
## Unpredictability widens the jitter. It resists the *learned* bias, because
## refusing to settle is refusing to be taught, and it leaves the innate seat
## alone -- the same shape the along-the-net axis already had.
static func _depth(
	hitter: VolleyballPlayer,
	lane: String,
	learned: Vector2,
	settle: float,
	rally_seed: int,
	swing_index: int,
) -> float:
	var range_m := CourtConstants.lane_depth_range_meters(lane)
	var centre_m := (range_m.x + range_m.y) * 0.5
	if not FeatureFlags.ENABLE_HITTER_TIGHTNESS:
		return CourtConstants.NET_Y + centre_m / CourtConstants.COURT_LENGTH_METERS
	var half_m := maxf((range_m.y - range_m.x) * 0.5, 0.01)
	var seat := _signed_hash(hitter.id * 6151 + hash(lane) * 3, 1.0) * half_m
	var jitter := _signed_hash(
		rally_seed + hitter.id * 271 + swing_index * 23, 1.0
	) * clampf(float(hitter.unpredictability) / 100.0, 0.0, 1.0) * half_m
	var metres := clampf(
		centre_m + seat + jitter + float(learned.y) * settle,
		range_m.x, range_m.y,
	)
	return CourtConstants.NET_Y + metres / CourtConstants.COURT_LENGTH_METERS


## Move this hitter's spot toward what worked and away from what did not.
##
## Called once per resolved swing. The pull is continuous rather than a jump to
## the last good coordinate: a hitter who relocates onto whichever ball they last
## killed is not learning, they are chasing, and it would make placement an
## argmax over near-ties in exactly the way the hitter *selection* was before it
## became a distribution.
static func learn(
	hitter: VolleyballPlayer,
	lane: String,
	contacted: Vector2,
	rewarded: bool,
) -> void:
	if hitter == null or lane.is_empty():
		return
	var memory := _memory(hitter)
	var learned := memory.get(lane, Vector2.ZERO) as Vector2
	var span := CourtConstants.lane_range(lane)
	var centre := (span.x + span.y) * 0.5
	## Where this swing happened relative to where they normally stand, in metres.
	var offset := (contacted.x - centre) * CourtConstants.COURT_WIDTH_METERS
	## Adaptable hitters learn faster; unpredictable ones refuse to settle, which
	## is the whole of what that attribute should mean and the reason it is not a
	## second accuracy stat.
	var rate := LEARNING_RATE_METERS \
		* lerpf(0.55, 1.35, clampf(float(hitter.adaptability) / 100.0, 0.0, 1.0)) \
		* (1.0 - clampf(float(hitter.unpredictability) / 100.0, 0.0, 1.0) * 0.75)
	var direction := 1.0 if rewarded else -1.0
	var moved := clampf(
		float(learned.x) * MEMORY_RETENTION + offset * rate * direction,
		-MEMORY_LIMIT_METERS, MEMORY_LIMIT_METERS,
	)
	## Both axes, not just the one along the net. A hitter learns "that was too
	## far off the net" the same way they learn "that was too far inside", and
	## recording only x would leave the y half of the memory permanently zero --
	## a value written by nobody and read by `_depth`, which is the built-and-
	## unconsumed shape from the other direction.
	##
	## It has no effect while `ENABLE_HITTER_TIGHTNESS` is off, by construction:
	## `_depth` returns the lane's own depth and never reads this. It is written
	## anyway so the two halves land together and the flag is the only thing
	## deciding whether tightness is live.
	var depth_range := CourtConstants.lane_depth_range_meters(lane)
	var depth_offset := (contacted.y - CourtConstants.NET_Y) \
		* CourtConstants.COURT_LENGTH_METERS \
		- (depth_range.x + depth_range.y) * 0.5
	var moved_depth := clampf(
		float(learned.y) * MEMORY_RETENTION + depth_offset * rate * direction,
		-MEMORY_LIMIT_METERS, MEMORY_LIMIT_METERS,
	)
	memory[lane] = Vector2(moved, moved_depth)


## Match-scoped and deliberately not exported. A hitter's habits inside one match
## are not a career fact, and persisting them would put a tuning surface into the
## save file before anyone has decided it should be one.
static func _memory(hitter: VolleyballPlayer) -> Dictionary:
	if not hitter.has_meta(&"placement_memory"):
		hitter.set_meta(&"placement_memory", {})
	return hitter.get_meta(&"placement_memory")


static func clear_memory(hitter: VolleyballPlayer) -> void:
	if hitter != null and hitter.has_meta(&"placement_memory"):
		hitter.remove_meta(&"placement_memory")


static func _familiarity(hitter: VolleyballPlayer, lane: String) -> float:
	var role := "Middle Blocker" if lane in ["Front Quick", "Right Quick"] \
		else str(hitter.position_role)
	return clampf(
		float(hitter.position_familiarity.get(role, 50)) / 100.0, 0.0, 1.0
	)


## A stable value in [-scale, scale] from an integer. No RNG, so nothing this
## touches re-sequences a seeded rally.
static func _signed_hash(value: int, scale: float) -> float:
	return (float(posmod(value * 2654435761, 1000)) / 500.0 - 1.0) * scale
