class_name CognitionTimeline
extends RefCounted

const CueModel := preload("res://scripts/models/player_cognition_cue.gd")


## One cue wins above each head. Higher semantic priority wins; ties go to the
## cue that started later, then to stable sequence order. Both courts call this
## exact sampler, so a replay cannot show two different thoughts at one time.
static func active_by_player(cues: Array, simulation_time: float) -> Dictionary:
	var active := {}
	for raw_cue in cues:
		var cue: Resource = raw_cue
		if cue == null or not cue.is_active_at(simulation_time):
			continue
		var player_id := int(cue.player_id)
		var current: Resource = active.get(player_id) as Resource
		if current == null or _precedes(current, cue):
			active[player_id] = cue
	return active


static func active_for_player(
	cues: Array, simulation_time: float, player_id: int
) -> Resource:
	return active_by_player(cues, simulation_time).get(player_id) as Resource


## The same sampler with the private thoughts removed, for a presentation that
## is a camera in a gym rather than a coaching instrument.
##
## Filtering *before* the one-winner rule rather than after it, because dropping
## the winner afterwards would leave that player with no badge at a moment when
## a public cue was genuinely available -- a spectator would see a player stop
## thinking, which is worse than seeing them think about something simple.
static func active_by_player_for_spectators(
	cues: Array, simulation_time: float
) -> Dictionary:
	var public: Array = []
	for raw_cue in cues:
		var cue: Resource = raw_cue
		if cue != null and cue.is_visible_to_spectators():
			public.append(cue)
	return active_by_player(public, simulation_time)


## Stamps stable ordering onto a freshly compiled stream.
##
## Two things depend on this and neither is cosmetic. `_precedes` breaks its
## final tie on `sequence`, so an unstamped stream would resolve overlaps by
## whatever order the compiler happened to append in -- which changes when a
## compiler stage is reordered, and a replay that changes is not a replay. And
## the gate asserts monotonic timestamps, which is only meaningful against a
## sorted stream.
##
## Sorted by start, then by the order the compiler produced them, so a
## deterministic compiler yields a deterministic stream.
static func finalize(cues: Array) -> Array:
	var ordered: Array = []
	for index in range(cues.size()):
		var cue: Resource = cues[index]
		if cue == null:
			continue
		## Provisional, and only to keep the sort stable across engine versions:
		## Godot's `sort_custom` is not guaranteed stable, so the tiebreaker has
		## to be a real field rather than the array's incoming order.
		cue.sequence = index
		cue.ends_at = maxf(
			cue.ends_at, cue.starts_at + CueModel.MINIMUM_DURATION_SECONDS
		)
		ordered.append(cue)
	ordered.sort_custom(func(left: Resource, right: Resource) -> bool:
		if not is_equal_approx(float(left.starts_at), float(right.starts_at)):
			return float(left.starts_at) < float(right.starts_at)
		return int(left.sequence) < int(right.sequence)
	)
	for index in range(ordered.size()):
		(ordered[index] as Resource).sequence = index
	return ordered


static func _precedes(current: Resource, candidate: Resource) -> bool:
	if int(candidate.priority) != int(current.priority):
		return int(candidate.priority) > int(current.priority)
	if not is_equal_approx(float(candidate.starts_at), float(current.starts_at)):
		return float(candidate.starts_at) > float(current.starts_at)
	return int(candidate.sequence) > int(current.sequence)
