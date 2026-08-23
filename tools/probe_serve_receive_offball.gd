extends SceneTree

## Who is asked to move during the serve flight, and in what role?
##
## The reception event carries the serve leg's movement for all twelve. The
## question is not whether it exists -- it does -- but whether it describes
## volleyball: a receiver stepping to the ball, a setter already released toward
## the net, someone supporting the pass, hitters opening to their runways.
## Reported by role, because "1 of 6 moved" says nothing about which one.

const MANAGER := preload("res://scripts/managers/game_manager.gd")

static func _tally(rows: Dictionary, role: String, metres: float) -> void:
	if not rows.has(role):
		rows[role] = {"n": 0, "moved": 0, "total": 0.0, "worst": 0.0}
	var row: Dictionary = rows[role]
	row["n"] = int(row["n"]) + 1
	row["total"] = float(row["total"]) + metres
	row["worst"] = maxf(float(row["worst"]), metres)
	if metres > 0.05:
		row["moved"] = int(row["moved"]) + 1


func _initialize() -> void:
	var rows := {}
	var receptions := 0
	for side in range(2):
		for index in range(70):
			var manager = MANAGER.new()
			manager.seed_vertical_slice_data()
			manager.match_state.serving_home = side == 0
			var result: Resource = manager.resolve_active_rally(600000 + index)
			if result == null:
				continue
			var lineup: RotationLineup = manager.current_lineup()
			var setter_id := int(lineup.active_setter_id())
			var reception: RallyEvent = null
			for raw_event in result.events:
				var e := raw_event as RallyEvent
				if e != null and int(e.event_type) == RallyEvent.EventType.RECEPTION:
					reception = e
					break
			if reception == null:
				continue
			## The receiving side is the one the reception's actor belongs to.
			var home_receives := lineup.slot_for_player(int(reception.actor_id)) >= 0
			var map: Dictionary = reception.metadata.get(
				"home_phase_targets" if home_receives else "opponent_phase_targets", {}
			)
			var spawn: Dictionary = result.initial_home_positions if home_receives \
				else result.initial_opponent_positions
			if map.is_empty():
				continue
			receptions += 1
			for raw_id in map:
				var id := int(raw_id)
				if not spawn.has(id):
					continue
				var raw = map[raw_id]
				var target := Vector2(raw) if not (raw is Dictionary) \
					else Vector2(Dictionary(raw).get("target", spawn[id]))
				var metres := RallyKinematics.court_delta_meters(
					Vector2(spawn[id]), target
				).length()
				## `current_lineup()` is the home lineup, so `setter_id` only names
				## a setter on home receptions -- the opponent's setter lands in
				## "other" and the setter row therefore counts 56 of the 113, not
				## all of them. Left as is rather than plumbed: "other" is 0 of 509
				## moved, so the unclassified half is inside a row that is already
				## zero and no reading changes.
				var role := "receiver" if id == int(reception.actor_id) \
					else ("setter" if id == setter_id else "other")
				_tally(rows, role, metres)
			## The same leg, from the other side of the net. Counted because a
			## number for the receiving side alone reads as a limit of the leg;
			## side by side it reads as what it is, an asymmetry.
			var serve_map: Dictionary = reception.metadata.get(
				"opponent_phase_targets" if home_receives else "home_phase_targets", {}
			)
			var serve_spawn: Dictionary = result.initial_opponent_positions \
				if home_receives else result.initial_home_positions
			for raw_id in serve_map:
				var id := int(raw_id)
				if not serve_spawn.has(id):
					continue
				var raw = serve_map[raw_id]
				var target := Vector2(raw) if not (raw is Dictionary) \
					else Vector2(Dictionary(raw).get("target", serve_spawn[id]))
				_tally(rows, "serving side", RallyKinematics.court_delta_meters(
					Vector2(serve_spawn[id]), target
				).length())
	print("serve receptions sampled: %d (both serving sides)" % receptions)
	print("%-10s %7s %8s %9s %10s %8s" % [
		"role", "legs", "moved", "moved %", "mean m", "worst m",
	])
	for role in ["receiver", "setter", "other", "serving side"]:
		if not rows.has(role):
			continue
		var row: Dictionary = rows[role]
		var n := maxi(int(row["n"]), 1)
		print("%-10s %7d %8d %8.1f%% %10.3f %8.3f" % [
			role, int(row["n"]), int(row["moved"]),
			100.0 * float(row["moved"]) / float(n),
			float(row["total"]) / float(n), float(row["worst"]),
		])
	quit(0)
