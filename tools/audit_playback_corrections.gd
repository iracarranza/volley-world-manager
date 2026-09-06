extends SceneTree

## Every playback correction, classified and traced back to the resolver.
##
## A correction is what `TacticalCourt._phase_path` emits when it has no
## published path and the drawn body is not where the simulation says it is.
## By construction it is never motion the simulation decided, so each one is a
## disagreement between two resolver statements. This finds which two.
##
## For each correction it records the action being drawn, where the target came
## from, and -- the part that matters -- the *previous* leg this body was on,
## because a body only ends up in the wrong place by failing to finish something.
##
## Run:
##   godot --headless --path . --script res://tools/audit_playback_corrections.gd

const GM := preload("res://scripts/managers/game_manager.gd")
const TC := preload("res://scenes/components/tactical_court.gd")

const BANDS := [1000, 4000, 9000, 15000, 22000, 31000]
const PER_BAND := 25


func _initialize() -> void:
	var manager: Object = GM.new()
	manager.seed_vertical_slice_data()
	var court: Object = TC.new()
	get_root().add_child(court)
	court.set_lineup(manager.rotations[1], manager.players)
	court.set_opponent_team(manager.opponent_team, true)

	var by_action := {}
	var by_source := {}
	var by_prior := {}
	var total := 0
	var legs := 0
	var worst := 0.0
	var worst_note := ""
	var histogram := {}

	for band in BANDS:
		for seed_value in range(band, band + PER_BAND):
			var result: Variant = manager.resolve_active_rally(seed_value)
			if result == null:
				continue
			var events: Array = result.events
			court.begin_rally_playback(
				result.get("initial_home_positions") \
					if result.get("initial_home_positions") is Dictionary else {},
				result.get("initial_opponent_positions") \
					if result.get("initial_opponent_positions") is Dictionary else {},
			)
			## What each body was last asked to do, so a correction can name the
			## leg it is cleaning up after.
			var prior_leg := {}
			for index in range(events.size() - 1):
				var played: Variant = events[index]
				var upcoming: Variant = events[index + 1]
				court.animate_spatial_transition(played, upcoming, 1.0)
				for raw_player_id in court.unit_movement_targets:
					var player_id := int(raw_player_id)
					var path: Dictionary = court.movement_paths.get(player_id, {})
					if path.is_empty():
						continue
					legs += 1
					var action: String = str(
						RallyEvent.EventType.keys()[upcoming.event_type]
					)
					if not bool(path.get("correction", false)):
						prior_leg[player_id] = {
							"action": action, "authoritative": true,
							"reached": _reached(upcoming, player_id),
						}
						continue
					total += 1
					var start: Vector2 = court.unit_movement_starts.get(
						player_id, Vector2.ZERO
					)
					var target: Vector2 = court.unit_movement_targets[player_id]
					var gap: float = start.distance_to(target)
					var role := "off-ball"
					if player_id == court.movement_player_id:
						role = "contact actor"
					var source := "phase_positions"
					for key in ["home_phase_targets", "opponent_phase_targets"]:
						var mapped: Variant = upcoming.metadata.get(key, {})
						if mapped is Dictionary and mapped.has(player_id):
							source = "phase_targets"
					var previous: Dictionary = prior_leg.get(player_id, {})
					var prior_key := "%s after %s%s" % [
						action,
						str(previous.get("action", "nothing")),
						"" if bool(previous.get("reached", true)) \
							else " (LEG NOT REACHED)",
					]
					by_action[action] = int(by_action.get(action, 0)) + 1
					by_source["%s / %s" % [source, role]] = int(
						by_source.get("%s / %s" % [source, role], 0)
					) + 1
					by_prior[prior_key] = int(by_prior.get(prior_key, 0)) + 1
					var bucket := "%.2f" % snappedf(gap, 0.05)
					histogram[bucket] = int(histogram.get(bucket, 0)) + 1
					if gap > worst:
						worst = gap
						worst_note = "seed %d, player %d, %s, from %s" % [
							seed_value, player_id, action,
							str(previous.get("action", "nothing")),
						]
					prior_leg[player_id] = {
						"action": action, "authoritative": false, "reached": true,
					}
				court.finish_event_animation()

	print("=== correction audit ===")
	print("%d drawn legs, %d corrections (%.2f%%)" % [
		legs, total, 100.0 * float(total) / maxf(float(legs), 1.0)
	])
	print("worst spatial disagreement %.4f court units -- %s" % [worst, worst_note])
	_dump("by action being drawn", by_action)
	_dump("by target source / role", by_source)
	_dump("by the leg it follows", by_prior)
	_dump("size histogram (court units)", histogram)
	quit()


## Whether the resolver's own published path for this body on this event says it
## got where it was going.
func _reached(event: Variant, player_id: int) -> bool:
	var published: Variant = null
	if int(event.actor_id) == player_id:
		published = event.metadata.get("movement_path", null)
	if published == null:
		for key in ["home_phase_intents", "opponent_phase_intents"]:
			var intents: Variant = event.metadata.get(key, {})
			if intents is Dictionary and intents.get(player_id, null) is Dictionary:
				published = (intents[player_id] as Dictionary).get("path", null)
	if published == null:
		return true
	return bool(published.reached_target)


func _dump(title: String, table: Dictionary) -> void:
	print("\n-- %s" % title)
	var keys: Array = table.keys()
	keys.sort_custom(func(a, b): return int(table[a]) > int(table[b]))
	for key in keys:
		print("   %-46s %d" % [key, table[key]])
