extends SceneTree

## D0 -- one ordinary rally, walked end to end, at every boundary.
##
##     godot --headless --path . \
##       --script res://tools/run_first_draft_walk.gd
##
## The packet's D0 is a **diagnostic**, explicitly "not required to produce a
## particular winner". It exists so the causal chain can be read rather than
## inferred: at every boundary, which ball arrived, whether it is the one the
## previous contact published, who actually played it, when, and how many volis
## were already in motion toward the next thing.
##
## Deliberately one rally printed in full rather than a thousand summarised. The
## censuses beside it already answer "how often"; this answers "what does one
## look like", which is the question a reader has when a census says 100% and
## they want to know 100% of *what*.
##
## Reads only what the resolver published. If a column is empty here, the engine
## did not say -- which is the same instrument the C0 census uses, pointed at one
## rally instead of three hundred.

const GameManagerScript := preload("res://scripts/managers/game_manager.gd")
const RallyEventScript := preload("res://scripts/models/rally_event.gd")

## Chosen for length rather than for outcome: a rally that reaches a transition
## exercises more boundaries than one that ends on the serve. Nothing about the
## result is asserted.
const SEEDS: Array[int] = [71004, 71011, 71042]


func _initialize() -> void:
	for seed_value in SEEDS:
		_walk(seed_value)
	quit(0)


func _walk(seed_value: int) -> void:
	var manager: Object = GameManagerScript.new()
	manager.seed_vertical_slice_data()
	manager.match_state.serving_home = true
	var rally: Resource = manager.resolve_active_rally(seed_value)
	if rally == null:
		manager.free()
		return
	print("\n================ seed %d, home serving ================\n" % seed_value)
	var previous_out := {}
	var previous_name := ""
	for event in rally.events:
		var kind := int(event.event_type)
		var name := str(RallyEventScript.EventType.keys()[kind])
		var meta: Dictionary = event.metadata
		var incoming: Dictionary = meta.get(
			"incoming_trajectory", meta.get("incoming_pass_trajectory", {})
		)
		var outgoing: Dictionary = meta.get("outgoing_trajectory", {})
		print("#%-2d %-16s %-22s  t=%s  %s" % [
			int(event.sequence), name, str(event.actor_name),
			_stamp(meta), "ok" if bool(event.success) else "FAILED",
		])
		if not incoming.is_empty():
			var upstream := str(previous_out.get("authoritative_flight_id", ""))
			var mine := str(incoming.get("authoritative_flight_id", ""))
			var chain := "-- first ball"
			if not previous_name.is_empty():
				chain = "same launch as %s" % previous_name if \
					not mine.is_empty() and mine == upstream \
					else "DIFFERENT LAUNCH from %s" % previous_name
			print("      in   %s  %s" % [_flight(incoming), chain])
		if not outgoing.is_empty():
			print("      out  %s" % _flight(outgoing))
		var intent: Dictionary = meta.get("platform_intent", {})
		if not intent.is_empty():
			print("      for  %s, aimed at voli %d, anchor %s" % [
				str(intent.get("purpose", "?")),
				int(intent.get("intended_recipient_id", -1)),
				str(Vector2(intent.get("target_anchor", Vector2.ZERO))),
			])
		var realised := int(meta.get("realised_interceptor_id", -1))
		if realised >= 0:
			print("      met by voli %d  (%s)" % [
				realised, str(meta.get("free_flight_resolution", "?")),
			])
		_print_traffic(meta)
		if not outgoing.is_empty():
			previous_out = outgoing
			previous_name = name
	manager.free()


## How many volis were already moving toward the next thing when this contact
## happened, and whether they got there. The C6 fields make this printable at
## all; before them a leg could only say where somebody ended up.
func _print_traffic(meta: Dictionary) -> void:
	var moving := 0
	var early := 0
	var short := 0
	var slack := 0.0
	for key in ["home_phase_intents", "opponent_phase_intents"]:
		for raw_player_id in Dictionary(meta.get(key, {})):
			var record: Dictionary = Dictionary(meta[key])[raw_player_id]
			if not record.has("traversal_seconds"):
				continue
			var traversal := float(record["traversal_seconds"])
			var window := float(record.get("window_seconds", 0.0))
			if traversal <= 0.02 or window <= 0.0:
				continue
			moving += 1
			if traversal < window - 0.0005:
				early += 1
				slack += window - traversal
			else:
				short += 1
	if moving == 0:
		return
	print("      %d volis in motion: %d arrived early (%.2fs spare each), %d ran out" % [
		moving, early, slack / maxf(float(early), 1.0), short,
	])


func _stamp(meta: Dictionary) -> String:
	for key in ["contact_time", "event_time", "physical_time"]:
		if meta.has(key):
			return "%.3f" % float(meta[key])
	return "  -  "


func _flight(trajectory: Dictionary) -> String:
	var role := str(trajectory.get("trajectory_role", "unresolved"))
	return "%-13s %s -> %s  %.2fs  %s" % [
		str(trajectory.get("trajectory_type", "?")),
		str(Vector2(trajectory.get("start_position", Vector2.ZERO))),
		str(Vector2(trajectory.get("end_position", Vector2.ZERO))),
		float(trajectory.get("duration", 0.0)),
		role if role != "unresolved" else "(resolved outside M5)",
	]
