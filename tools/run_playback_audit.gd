extends SceneTree

## Playback audit: what the 3D view is actually asked to draw.
##
## Replays `match_screen.gd`'s bookkeeping headlessly -- the same live-position
## dictionary, the same `_build_movement_plan` targets, the same per-flight
## durations -- and measures the ground each player is asked to cover in the
## time the ball is in the air. Impressions of "that looked impossible" become
## metres per second.
##
## Also checks the two structural questions: whether any event is attributed to
## the wrong side, and whether one defensive play emits as several actions.
##
## Run with:
##   godot --headless --path . --script res://tools/run_playback_audit.gd

const SEED_OF_INTEREST: int = 3801887944
## An elite volleyball player covers roughly 6 m/s at a flat-out sprint and
## noticeably less in a defensive shuffle. Anything above this over a whole
## flight is ground nobody covers.
const IMPLAUSIBLE_SPEED_MPS: float = 6.5

var _done: bool = false


func _process(_delta: float) -> bool:
	if _done:
		return true
	_done = true
	var career_manager := get_root().get_node("/root/CareerManager")
	var game_manager := get_root().get_node("/root/GameManager")
	if not career_manager.create_career(
			"__Playback Audit__", "Probe FC", "Landavol", "Club", "Balanced").is_empty():
		print("could not create career")
		return true
	while int(career_manager.career.absolute_week) < 2:
		career_manager.advance_week()
	if not career_manager.prepare_fixture(1).is_empty():
		print("could not prepare fixture")
		return true

	var home_ids := {}
	for player in game_manager.players:
		home_ids[int(player.id)] = true

	var side_mismatches: Array[String] = []
	var moves: Array[Dictionary] = []
	var sequences: Array[String] = []
	var double_contacts: Array[String] = []
	var rallies := 0

	while not bool(game_manager.match_state.match_complete) and rallies < 400:
		var result: Resource = game_manager.resolve_active_rally(SEED_OF_INTEREST + rallies)
		game_manager.record_rally(result)
		rallies += 1
		_audit_sides(result, home_ids, rallies, side_mismatches)
		_audit_movement(result, home_ids, rallies, moves)
		_audit_double_contacts(result, home_ids, rallies, double_contacts)
		if rallies <= 3:
			sequences.append(_sequence_text(result, home_ids, rallies))

	print("rallies audited: %d\n" % rallies)

	print("--- 1. side attribution ---")
	print("events whose declared side disagrees with roster membership: %d"
		% side_mismatches.size())
	for line in side_mismatches.slice(0, 8):
		print("   %s" % line)

	print("\n--- 2. ground covered per ball flight ---")
	_report_moves(moves)

	print("\n--- 3. same actor contacting twice in a row ---")
	_report_double_contacts(double_contacts)

	print("\n--- 4. sample event sequences ---")
	for text in sequences:
		print(text)
	return true


## Two ball contacts in a row by one player. In the rules that is a double
## contact; on screen it is the "one play that reads as several actions" the
## viewer described, because playback poses each event separately.
func _audit_double_contacts(
	result: Resource, home_ids: Dictionary, rally_number: int, out: Array[String]
) -> void:
	var contact_types := [
		RallyEvent.EventType.SERVE, RallyEvent.EventType.RECEPTION,
		RallyEvent.EventType.SET, RallyEvent.EventType.ATTACK,
		RallyEvent.EventType.BLOCK, RallyEvent.EventType.DEFENSE,
	]
	var previous_actor := -1
	var previous_type := ""
	for index in range(result.events.size()):
		var event := result.events[index] as RallyEvent
		if event == null or not (event.event_type in contact_types):
			continue
		var actor_id := int(event.actor_id)
		if actor_id >= 0 and actor_id == previous_actor:
			out.append("rally %d ev %d actor %d (%s) %s then %s" % [
				rally_number, index, actor_id,
				"home" if home_ids.has(actor_id) else "opp",
				previous_type, event.type_name(),
			])
		previous_actor = actor_id
		previous_type = event.type_name()


func _report_double_contacts(entries: Array[String]) -> void:
	print("occurrences: %d" % entries.size())
	var pairs := {}
	for entry in entries:
		var key := entry.substr(entry.find(") ") + 2)
		pairs[key] = int(pairs.get(key, 0)) + 1
	for key in pairs:
		print("   %-24s x%d" % [key, int(pairs[key])])
	for entry in entries.slice(0, 6):
		print("   %s" % entry)


func _audit_sides(
	result: Resource, home_ids: Dictionary, rally_number: int, out: Array[String]
) -> void:
	for index in range(result.events.size()):
		var event := result.events[index] as RallyEvent
		if event == null or int(event.actor_id) < 0:
			continue
		var declared := str(event.metadata.get("side", ""))
		if declared.is_empty():
			continue
		if (declared == "home") != home_ids.has(int(event.actor_id)):
			out.append("rally %d ev %d %s actor %d declared %s, roster says %s" % [
				rally_number, index, event.type_name(), int(event.actor_id), declared,
				"home" if home_ids.has(int(event.actor_id)) else "opponent",
			])


## Mirrors `match_screen.gd`: live positions seeded from the rally's initial
## dictionaries, then advanced one ball flight at a time toward each flight's
## movement targets. Only the two targets that name a specific player are
## modelled -- the staged next actor and the next contact's actor -- because the
## ambient `_support_target` drift is a small lerp toward the action and never
## the thing that looks wrong.
func _audit_movement(
	result: Resource, home_ids: Dictionary, rally_number: int, out: Array[Dictionary]
) -> void:
	var live := {}
	for raw_id in result.initial_home_positions:
		live[int(raw_id)] = Vector2(result.initial_home_positions[raw_id])
	for raw_id in result.initial_opponent_positions:
		live[int(raw_id)] = Vector2(result.initial_opponent_positions[raw_id])
	var events: Array = result.events
	for index in range(events.size()):
		var event := events[index] as RallyEvent
		if event == null:
			continue
		var trajectory: Dictionary = event.metadata.get("outgoing_trajectory", {})
		if trajectory.is_empty():
			continue
		var flight := clampf(float(trajectory.get("duration", 0.5)), 0.08, 3.5)
		var next_contact := _next_contact(events, index + 1)
		if next_contact == null:
			continue
		var targets := {}
		var staged_id := int(event.metadata.get("staged_next_actor_id", -1))
		if staged_id >= 0:
			targets[staged_id] = Vector2(
				event.metadata.get("staged_next_position", Vector2.ZERO)
			)
		var next_actor := int(next_contact.actor_id)
		if next_actor >= 0:
			targets[next_actor] = Vector2(next_contact.metadata.get(
				"movement_target", next_contact.start_position
			))
			## Playback resets the actor to the simulator's own `movement_start`
			## before drawing this leg, so the audit has to as well or it
			## measures a journey nobody draws.
			if next_contact.metadata.has("movement_start"):
				live[next_actor] = Vector2(next_contact.metadata["movement_start"])
		for raw_id in targets:
			var player_id := int(raw_id)
			var target := Vector2(targets[raw_id])
			var start: Vector2 = live.get(player_id, target)
			var metres := _court_metres(start, target)
			live[player_id] = target
			if metres < 0.05:
				continue
			out.append({
				"rally": rally_number, "event": index, "actor": player_id,
				"home": home_ids.has(player_id),
				"context": "%s -> %s" % [event.type_name(), next_contact.type_name()],
				"metres": metres, "seconds": flight,
				"speed": metres / flight,
				"from": start, "to": target,
			})


func _next_contact(events: Array, start_index: int) -> RallyEvent:
	for index in range(start_index, events.size()):
		var candidate := events[index] as RallyEvent
		if candidate == null:
			continue
		if candidate.event_type in [
			RallyEvent.EventType.SET_DECISION, RallyEvent.EventType.POINT,
		]:
			continue
		return candidate
	return null


func _sequence_text(result: Resource, home_ids: Dictionary, rally_number: int) -> String:
	var lines: Array[String] = ["rally %d (%s)" % [
		rally_number, str(result.terminal_outcome),
	]]
	for index in range(result.events.size()):
		var event := result.events[index] as RallyEvent
		if event == null:
			continue
		lines.append("   %02d %-13s %-8s actor %-4d (%.2f, %.2f) -> (%.2f, %.2f)  %s" % [
			index, event.type_name(),
			"home" if home_ids.has(int(event.actor_id)) else "opp",
			int(event.actor_id),
			event.start_position.x, event.start_position.y,
			event.end_position.x, event.end_position.y,
			event.headline,
		])
	return "\n".join(lines)


func _court_metres(from_point: Vector2, to_point: Vector2) -> float:
	var delta := to_point - from_point
	return Vector2(
		delta.x * CourtConstants.COURT_WIDTH_METERS,
		delta.y * CourtConstants.COURT_LENGTH_METERS,
	).length()


func _report_moves(moves: Array[Dictionary]) -> void:
	if moves.is_empty():
		print("no directed movement found")
		return
	var speeds: Array[float] = []
	for move in moves:
		speeds.append(float(move.speed))
	speeds.sort()
	var implausible := 0
	for speed in speeds:
		if speed > IMPLAUSIBLE_SPEED_MPS:
			implausible += 1
	print("directed movements: %d" % moves.size())
	print("implied speed m/s -- median %.2f  p90 %.2f  max %.2f" % [
		speeds[speeds.size() / 2],
		speeds[mini(int(float(speeds.size()) * 0.9), speeds.size() - 1)],
		speeds[-1],
	])
	print("above %.1f m/s: %d (%.1f%%)" % [
		IMPLAUSIBLE_SPEED_MPS, implausible,
		100.0 * float(implausible) / float(speeds.size()),
	])
	var by_context := {}
	for move in moves:
		var key := str(move.context)
		if not by_context.has(key):
			by_context[key] = {"count": 0, "bad": 0, "worst": 0.0}
		by_context[key]["count"] += 1
		if float(move.speed) > IMPLAUSIBLE_SPEED_MPS:
			by_context[key]["bad"] += 1
		by_context[key]["worst"] = maxf(float(by_context[key]["worst"]), float(move.speed))
	print("\nby transition:")
	for key in by_context:
		var row: Dictionary = by_context[key]
		print("   %-26s n=%-4d over-speed %-4d worst %.1f m/s" % [
			key, int(row.count), int(row.bad), float(row.worst),
		])
	var worst := moves.duplicate()
	worst.sort_custom(func(a, b): return float(a.speed) > float(b.speed))
	print("\nworst offenders:")
	for move in worst.slice(0, 10):
		print("   rally %d ev %d %-24s actor %d (%s) (%.2f,%.2f)->(%.2f,%.2f) %.2f m in %.2f s = %.1f m/s" % [
			move.rally, move.event, move.context, move.actor,
			"home" if move.home else "opp",
			move.from.x, move.from.y, move.to.x, move.to.y,
			move.metres, move.seconds, move.speed,
		])
