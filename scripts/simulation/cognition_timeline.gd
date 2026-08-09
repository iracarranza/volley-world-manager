class_name CognitionTimeline
extends RefCounted


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


static func _precedes(current: Resource, candidate: Resource) -> bool:
	if int(candidate.priority) != int(current.priority):
		return int(candidate.priority) > int(current.priority)
	if not is_equal_approx(float(candidate.starts_at), float(current.starts_at)):
		return float(candidate.starts_at) > float(current.starts_at)
	return int(candidate.sequence) > int(current.sequence)
