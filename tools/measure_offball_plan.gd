extends SceneTree

## What `_build_movement_plan` actually asks for, leg by leg, in metres.
##
##     godot --headless --path . --script res://tools/measure_offball_plan.gd
##
## The companion to `measure_offball_travel.gd`, which says how far bodies move
## on screen and nothing about why. This calls the real `_build_movement_plan`
## -- not a reimplementation of it, which is how the previous two attempts at
## this question went wrong -- and prints, per leg, how many volis were given a
## target and how far each target is from where they are standing.
##
## Read it for the difference between "no target" and "a target they are already
## standing on". Those look identical on screen and have completely different
## causes: the first is a resolver that published nothing, the second is a
## resolver that published a position somebody is already in.
func _initialize() -> void:
	var GameManagerScript := load("res://scripts/managers/game_manager.gd")
	var Events := load("res://scripts/models/rally_event.gd")
	var manager: Object = GameManagerScript.new()
	manager.seed_vertical_slice_data()
	manager.match_state.serving_home = false

	var screen: Control = load("res://scenes/screens/match_screen.tscn").instantiate()
	get_root().add_child(screen)
	await process_frame
	var court = screen.match_court_3d

	var per_leg := {}
	var reversals := {}
	var wasted := {}
	var last_leg := {}
	var last_source := {}
	var pairs := {}
	for rally_seed in [12007, 12011, 12019, 12023, 12029, 12031, 12037, 12041]:
		var result: Resource = manager.resolve_active_rally(rally_seed)
		if result == null:
			continue
		screen.active_result = result
		screen.player_physical_profiles = result.player_physical_profiles.duplicate(true)
		court.setup_players(
			result.initial_home_positions, result.initial_opponent_positions
		)
		await process_frame
		var events: Array = result.events
		for index in range(events.size()):
			var event = events[index]
			var trajectory: Dictionary = event.metadata.get("outgoing_trajectory", {})
			if trajectory.is_empty():
				continue
			var next_index: int = screen._next_contact_index(events, index + 1)
			if next_index < 0:
				continue
			var next_contact = events[next_index]
			var duration := clampf(float(trajectory.get("duration", 0.5)), 0.08, 3.5)
			var plan: Dictionary = screen._build_movement_plan(event, next_contact, duration)
			var key := "%s->%s" % [
				Events.EventType.keys()[int(event.event_type)],
				Events.EventType.keys()[int(next_contact.event_type)],
			]
			var row: Dictionary = per_leg.get(key, {
				"legs": 0, "targets": 0, "moving": 0, "metres": 0.0,
				"window": 0.0, "drawn": 0.0, "actor_metres": 0.0, "actor_drawn": 0.0,
			})
			row["legs"] = int(row["legs"]) + 1
			row["window"] = float(row["window"]) + duration
			var actor_id := int(next_contact.actor_id)
			for raw_player_id in plan:
				var movement: Dictionary = plan[raw_player_id]
				var metres: float = screen._leg_metres(movement)
				if metres <= 0.05:
					continue
				## What the window can actually pay for. A leg paced longer than
				## the flight is simply unfinished when the flight ends.
				var leg_seconds := float(movement.get("seconds", duration))
				var drawn: float = metres * clampf(
					duration / maxf(leg_seconds, 0.0001), 0.0, 1.0
				)
				if int(raw_player_id) == actor_id:
					row["actor_metres"] = float(row["actor_metres"]) + metres
					row["actor_drawn"] = float(row["actor_drawn"]) + drawn
					continue
				## Off the ball: the volis this whole exercise is about.
				row["targets"] = int(row["targets"]) + 1
				row["moving"] = int(row["moving"]) + 1
				row["metres"] = float(row["metres"]) + metres
				row["drawn"] = float(row["drawn"]) + drawn
			per_leg[key] = row
			## **Does anybody get sent back where they just came from?**
			##
			## Reported from playback as an opposite outside hitter pacing back and
			## forth during defence and reception. A voli walking two metres one way
			## and two metres back has covered four metres of perfectly plausible
			## travel and gone nowhere, so no distance figure can see it -- only the
			## *direction* of successive legs can. A reversal is a leg whose heading
			## opposes the previous one for the same voli.
			for raw_player_id in plan:
				var player_id := int(raw_player_id)
				var movement: Dictionary = plan[raw_player_id]
				var leg: Vector2 = Vector2(movement.get("target", Vector2.ZERO)) \
					- Vector2(movement.get("start", Vector2.ZERO))
				if leg.length() < 0.01:
					continue
				var last: Variant = last_leg.get(player_id, null)
				if last is Vector2 and (last as Vector2).normalized().dot(
					leg.normalized()
				) < -0.35:
					reversals[player_id] = int(reversals.get(player_id, 0)) + 1
					wasted[player_id] = float(wasted.get(player_id, 0.0)) \
						+ minf(screen._leg_metres(movement), _metres(court, last as Vector2))
					## Which pair of legs turned them round, and what issued each
					## target. A reversal between two phase maps is a resolver
					## disagreeing with itself; a reversal between a phase map and a
					## base return is playback's two sources fighting.
					var pair := "%s after %s" % [
						_source(screen, next_contact, player_id),
						str(last_source.get(player_id, "?")),
					]
					pairs[pair] = int(pairs.get(pair, 0)) + 1
				last_leg[player_id] = leg
				last_source[player_id] = _source(screen, next_contact, player_id)
			## Advance the court the way playback would, so the next leg is
			## planned from where bodies got to rather than from the first frame.
			court.finish_movement_plan(plan, duration)

	print("off the ball, per leg. 'drawn' is what the flight has time to show.")
	print("%-22s %5s %7s %8s %8s %6s %9s %8s" % [
		"leg", "legs", "window", "offball", "asked m", "drawn", "% drawn", "actor m",
	])
	for key in per_leg:
		var row: Dictionary = per_leg[key]
		var legs := float(row["legs"])
		var asked := float(row["metres"])
		print("%-22s %5d %7.2f %8.2f %8.2f %6.2f %8.0f%% %8.2f" % [
			key, int(legs), float(row["window"]) / legs,
			float(row["moving"]) / legs, asked / legs, float(row["drawn"]) / legs,
			100.0 * float(row["drawn"]) / maxf(asked, 0.0001),
			float(row["actor_drawn"]) / legs,
		])
	print("")
	print("volis sent back the way they came, over %d rallies" % 8)
	print("%-6s %10s %12s" % ["voli", "reversals", "wasted m"])
	var ids := reversals.keys()
	ids.sort()
	for player_id in ids:
		print("%-6d %10d %12.2f" % [
			int(player_id), int(reversals[player_id]),
			float(wasted.get(player_id, 0.0)),
		])
	print("")
	print("what turned them round")
	for key in pairs:
		print("%-40s %d" % [key, int(pairs[key])])
	manager.free()
	quit()


## Who issued this voli's target for this leg: the resolver's phase map, or
## playback's own return-to-base.
func _source(screen, next_contact, player_id: int) -> String:
	for key in ["home_phase_targets", "opponent_phase_targets"]:
		if Dictionary(next_contact.metadata.get(key, {})).has(player_id):
			return "phase map"
	if int(next_contact.actor_id) == player_id:
		return "the contact"
	return "base return"


func _metres(court, delta: Vector2) -> float:
	return Vector2(
		delta.x * court.court_width, delta.y * court.court_length
	).length()
