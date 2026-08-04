class_name MovementTimingRatioCalibration
extends RefCounted

## Quantifies how far apart the engine's two movement-timing paths are.
##
## `RallySimulator._movement_time()` decides how long a traversal is allotted
## and therefore when contacts happen. `RallyMovementSystem.project_toward()`
## decides how far a player actually gets in a given time, and is what every
## reachability and arrival-margin decision is built on. They are separate code
## with separate formulas, and nothing has ever measured whether they agree.
##
## The disagreement is visible today: 2D playback has to honour the resolved
## duration, so it renormalises the model's traversal onto the phase. The ratio
## measured here *is* that renormalisation -- a value of 1.0 means the phase is
## drawn at the model's own pace, 0.5 means the player is drawn at half the
## speed the model says they move, and 2.0 means double.
##
## This changes nothing. It reports.

const ShadowMovementModel := preload("res://scripts/simulation/shadow_movement_system.gd")

## Event types where `start_position` is the actor's movement destination, which
## is the same mapping 2D playback uses in `_prepare_player_movement()`.
static func _destination_is_start_position(event_type: int) -> bool:
	return event_type in [
		RallyEvent.EventType.RECEPTION, RallyEvent.EventType.SET,
		RallyEvent.EventType.ATTACK, RallyEvent.EventType.DEFENSE,
	]
## Ratios outside this band would be plainly visible as slow motion or
## fast-forward during a phase.
const PERCEPTIBLE_LOW: float = 0.70
const PERCEPTIBLE_HIGH: float = 1.40


static func run(seed_count: int = 40, base_seed: int = 300000) -> Dictionary:
	var manager_script := load("res://scripts/managers/game_manager.gd")
	var ratios: Array[float] = []
	var unreachable := 0
	var by_event_type := {}
	for index in range(maxi(seed_count, 1)):
		var manager = manager_script.new()
		manager.seed_vertical_slice_data()
		manager.match_state.serving_home = false
		var result: Resource = manager.resolve_active_rally(base_seed + index)
		if result == null:
			continue
		var lineup: RotationLineup = manager.current_lineup()
		for raw_event in result.events:
			var event := raw_event as RallyEvent
			if event == null or not _has_movement(event):
				continue
			var profile := _profile_for(manager, int(event.actor_id))
			if profile == null:
				continue
			var allotted := float(event.metadata.get("movement_duration", 0.0))
			if allotted <= 0.01:
				continue
			var start := Vector2(event.metadata.get("movement_start", event.start_position))
			var destination := event.start_position
			var mode := _mode_for(int(event.event_type))
			var actor := RallyPlayerState.create(
				profile,
				&"opponent" if lineup.slot_for_player(int(event.actor_id)) < 0 else &"home",
				-1, start,
			)
			var opening := RallyKinematics.court_delta_meters(start, destination)
			if opening.length() < 0.05:
				## A traversal of a few centimetres says nothing about pace.
				continue
			actor.facing = opening.normalized()
			## The same speed the resolver credited this player with entering the
			## leg. Rebuilding the actor at rest and comparing that against a
			## duration the resolver computed *with* carried velocity measures the
			## difference between the two assumptions, not the difference between
			## the two models -- which is the only thing this gate exists to see.
			actor.velocity = Vector2(event.metadata.get(
				"movement_entry_velocity", Vector2.ZERO
			))
			var natural: float = ShadowMovementModel.natural_traversal_time(
				actor, destination, mode
			)
			if natural < 0.0:
				unreachable += 1
				continue
			var ratio := natural / allotted
			ratios.append(ratio)
			var type_name: String = str(RallyEvent.EventType.keys()[int(event.event_type)])
			if not by_event_type.has(type_name):
				by_event_type[type_name] = []
			by_event_type[type_name].append(ratio)
	return _summarize(ratios, by_event_type, unreachable)


static func _has_movement(event: RallyEvent) -> bool:
	return event.actor_id >= 0 \
		and event.metadata.has("movement_duration") \
		and _destination_is_start_position(int(event.event_type))


static func _mode_for(event_type: int) -> RallyPlayerState.MovementMode:
	match event_type:
		RallyEvent.EventType.RECEPTION, RallyEvent.EventType.DEFENSE:
			return RallyPlayerState.MovementMode.LATERAL
		RallyEvent.EventType.ATTACK:
			return RallyPlayerState.MovementMode.APPROACH
	return RallyPlayerState.MovementMode.TRANSITION


static func _profile_for(manager: Node, player_id: int) -> VolleyballPlayer:
	for player in manager.players:
		if int(player.id) == player_id:
			return player as VolleyballPlayer
	if manager.opponent_team != null:
		return manager.opponent_team.player_by_id(player_id) as VolleyballPlayer
	return null


static func _summarize(
	ratios: Array[float], by_event_type: Dictionary, unreachable: int
) -> Dictionary:
	if ratios.is_empty():
		return {"fixture_valid": false, "sample_count": 0, "unreachable": unreachable}
	var sorted: Array = ratios.duplicate()
	sorted.sort()
	var total := 0.0
	var perceptible := 0
	for ratio in ratios:
		total += ratio
		if ratio < PERCEPTIBLE_LOW or ratio > PERCEPTIBLE_HIGH:
			perceptible += 1
	var per_type := {}
	for type_name in by_event_type:
		var bucket: Array = by_event_type[type_name]
		var bucket_total := 0.0
		for ratio in bucket:
			bucket_total += float(ratio)
		per_type[type_name] = {
			"sample_count": bucket.size(),
			"mean_ratio": bucket_total / float(bucket.size()),
		}
	return {
		"fixture_valid": true,
		"sample_count": ratios.size(),
		"unreachable_within_window": unreachable,
		"mean_ratio": total / float(ratios.size()),
		"median_ratio": float(sorted[sorted.size() / 2]),
		"minimum_ratio": float(sorted[0]),
		"maximum_ratio": float(sorted[-1]),
		## The share of phases drawn fast or slow enough to read as wrong.
		"perceptible_rate": float(perceptible) / float(ratios.size()),
		"by_event_type": per_type,
		"coverage": {
			"multiple_event_types_observed": per_type.size() >= 2,
			"faster_than_allotted_observed": float(sorted[0]) < 1.0,
			"slower_than_allotted_observed": float(sorted[-1]) > 1.0,
		},
	}
