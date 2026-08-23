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

## Event types whose contact publishes a movement destination. Most contacts use
## the ball's `start_position`; an attack publishes `body_contact_position`
## because the hitter's centre is behind the ball. This is the same distinction
## playback uses, so the diagnostic measures the timed leg rather than the old
## body-on-ball fiction.
static func _destination_is_start_position(event_type: int) -> bool:
	return event_type in [
		RallyEvent.EventType.RECEPTION, RallyEvent.EventType.SET,
		RallyEvent.EventType.ATTACK, RallyEvent.EventType.DIG,
		RallyEvent.EventType.ATTACK_COVERAGE,
	]


## **Which end this family's `movement_duration` was actually timed to.**
##
## The ratio below divides a modelled traversal by `movement_duration`, so the
## two have to describe the same journey. They do not describe the same journey
## for every family, because the resolver times each leg to a different end:
## the attack to `intended_hitter_body` and the set to the setter's contact,
## the reception to `serve_landing` and the dig to the ball's floor target.
## A hitter's centre stops behind the ball; a passer's platform reaches out to
## it.
##
## This used to be inferred from whether the event carried a
## `body_contact_position` at all, which worked only for as long as the two
## families timed to the body were the only two publishing it. M8 published that
## key from `_add_event` for every contact -- correctly, it is a real fact about
## every contact -- and the proxy silently became "always the body". The
## measured cost: RECEPTION 0.9952 -> 0.7802, DIG 0.9977 -> 0.6491,
## ATTACK_COVERAGE 1.0000 -> 0.5209, while SET and ATTACK stayed identical to
## four decimals because they were already on the body. Nothing about the engine
## moved; three of five numerators started measuring to an end their denominator
## had never been timed to.
##
## Naming the families is the repair rather than redrawing the bands, which
## would have been fitting a gate to an instrument change. The bands stand where
## they were measured.
static func _destination_is_body_contact(event_type: int) -> bool:
	return event_type in [
		RallyEvent.EventType.SET, RallyEvent.EventType.ATTACK,
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
			var destination := Vector2(event.start_position)
			if _destination_is_body_contact(int(event.event_type)):
				destination = Vector2(event.metadata.get(
					"body_contact_position", event.start_position
				))
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
			var waypoint: Variant = event.metadata.get(
				"navigation_waypoint", null
			)
			var natural: float = ShadowMovementModel.natural_traversal_time(
				actor, destination, mode, waypoint
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
		RallyEvent.EventType.RECEPTION, RallyEvent.EventType.DIG, \
		RallyEvent.EventType.ATTACK_COVERAGE:
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
