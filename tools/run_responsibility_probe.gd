extends Node

## Paired serve-receive and responsibility audit.
##
##     godot --headless --path . res://tools/responsibility_probe.tscn
##
## Every rotation receives the same 200 seeds. Event ownership is read only
## from the resolver-authored `metadata.side`; an event without a side is
## reported and excluded instead of being guessed from an id range. The probe
## also runs two same-serve counterfactuals:
##
##   * legacy slots: the old back-row-slot passing unit;
##   * stable lanes: the roster-selected unit held in fixed outside/libero/
##     outside seams instead of production's minimum-travel assignment.
##
## The serve event must remain byte-equivalent in the three runs. That makes a
## change in first-contact results attributable to the receive assignment, not
## to a different serve draw.
const RALLIES_PER_ROTATION: int = 200
const ROTATION_COUNT: int = 6
const RECEPTION_TERM_KEYS: Array[String] = [
	"base", "serve_pressure", "risk_pressure", "body_penalty",
	"arrival_bonus", "support_bonus", "seam_penalty", "execution_noise",
	"unclamped_quality", "final_quality",
]


func _ready() -> void:
	await get_tree().process_frame
	var failures := _probe()
	get_tree().quit(1 if failures > 0 else 0)


func _probe() -> int:
	var career_manager: Node = get_node("/root/CareerManager")
	var game_manager: Node = get_node("/root/GameManager")
	var error: String = career_manager.create_career(
		"Responsibility Probe", "Probe VC", "Landavol", "Established", "Balanced"
	)
	if not error.is_empty():
		print("could not start a career: %s" % error)
		return 1
	game_manager.match_state.serving_home = false
	game_manager.opponent_team.select_rotation(1)

	var production := {}
	var legacy_slots := {}
	var stable_lanes := {}
	var ownership := {}
	for rotation in range(1, ROTATION_COUNT + 1):
		production[rotation] = _new_row()
		legacy_slots[rotation] = _new_row()
		stable_lanes[rotation] = _new_row()

	var failures := 0
	var serve_mismatches := 0
	for sample in range(RALLIES_PER_ROTATION):
		## Reused across all six rotations and all three receive shapes.
		var seed_value := hash("responsibility|paired|%d" % sample)
		for rotation in range(1, ROTATION_COUNT + 1):
			var select_error: String = game_manager.select_rotation(rotation)
			if not select_error.is_empty():
				print("rotation selection failed: %s" % select_error)
				failures += 1
				continue
			var lineup: RotationLineup = game_manager.current_lineup()
			var plan: Resource = game_manager.current_defensive_plan()
			var saved_plan: Dictionary = plan.to_dict()

			var production_result: Resource = game_manager.resolve_active_rally(seed_value)
			failures += _count_result(
				production[rotation], production_result, lineup, ownership, true
			)

			_apply_legacy_slot_receive(plan, lineup)
			var legacy_result: Resource = game_manager.resolve_active_rally(seed_value)
			failures += _count_result(
				legacy_slots[rotation], legacy_result, lineup, {}, false
			)

			_apply_stable_player_receive(plan, lineup, game_manager.players)
			var stable_result: Resource = game_manager.resolve_active_rally(seed_value)
			failures += _count_result(
				stable_lanes[rotation], stable_result, lineup, {}, false
			)

			plan.load_dict(saved_plan)
			if not _same_serve(production_result, legacy_result) \
					or not _same_serve(production_result, stable_result):
				serve_mismatches += 1

	_print_roster(game_manager.players)
	_print_production(production)
	_print_counterfactual(production, legacy_slots, stable_lanes, serve_mismatches)
	_print_ownership(ownership)
	if serve_mismatches > 0:
		failures += serve_mismatches
	print("=== probe invariants: %d failure(s)" % failures)
	return failures


func _new_row() -> Dictionary:
	return {
		"rallies": 0,
		"outcomes": {},
		"home_receptions": 0,
		"home_reception_success": 0,
		"home_attacks": 0,
		"opponent_attacks": 0,
		"floor_attempts": 0,
		"floor_success": 0,
		"coverage_attempts": 0,
		"coverage_success": 0,
		"missing_side": 0,
		"missing_reception_terms": 0,
		"receivers": {},
		"lanes": {},
		"serve_quality": [],
		"reception_quality": [],
		"reach_margin": [],
		"distance": [],
		"read_error": [],
		"term_samples": {},
		"reception_cases": [],
	}


func _count_result(
	row: Dictionary,
	result: Resource,
	lineup: RotationLineup,
	ownership: Dictionary,
	collect_ownership: bool,
) -> int:
	row["rallies"] = int(row["rallies"]) + 1
	if result == null:
		return 1
	var failures := 0
	var outcome := str(result.terminal_outcome)
	var outcomes: Dictionary = row["outcomes"]
	outcomes[outcome] = int(outcomes.get(outcome, 0)) + 1

	var home_receptions := 0
	var home_attacks := 0
	var opponent_attacks := 0
	for raw_event in result.events:
		var event: Resource = raw_event
		if event == null:
			continue
		var event_type := int(event.event_type)
		if event_type not in [
			RallyEvent.EventType.SERVE,
			RallyEvent.EventType.RECEPTION,
			RallyEvent.EventType.ATTACK,
			RallyEvent.EventType.DIG,
			RallyEvent.EventType.ATTACK_COVERAGE,
		]:
			continue
		var side := str(event.metadata.get("side", ""))
		if side not in ["home", "opponent"]:
			row["missing_side"] = int(row["missing_side"]) + 1
			failures += 1
			continue
		match event_type:
			RallyEvent.EventType.SERVE:
				if side == "opponent":
					_append_sample(row, "serve_quality", float(event.quality))
			RallyEvent.EventType.RECEPTION:
				if side == "home":
					home_receptions += 1
					row["home_receptions"] = int(row["home_receptions"]) + 1
					row["home_reception_success"] = \
						int(row["home_reception_success"]) + int(bool(event.success))
					_append_sample(row, "reception_quality", float(event.quality))
					_count_receiver(row, event, lineup)
					failures += _count_reception_terms(row, event)
			RallyEvent.EventType.ATTACK:
				if side == "home":
					home_attacks += 1
					row["home_attacks"] = int(row["home_attacks"]) + 1
					var lane := str(event.metadata.get("lane", "unknown"))
					var lanes: Dictionary = row["lanes"]
					lanes[lane] = int(lanes.get(lane, 0)) + 1
				else:
					opponent_attacks += 1
					row["opponent_attacks"] = int(row["opponent_attacks"]) + 1
			## This probe was already the only consumer that told the two apart,
			## and it did it by reading metadata off a shared type. The split
			## moves that distinction into the type itself; the counters are
			## unchanged, so its numbers are directly comparable across the change.
			RallyEvent.EventType.ATTACK_COVERAGE:
				if side == "home":
					row["coverage_attempts"] = int(row["coverage_attempts"]) + 1
					row["coverage_success"] = int(row["coverage_success"]) \
						+ int(bool(event.success))
			RallyEvent.EventType.DIG:
				if side == "home":
					row["floor_attempts"] = int(row["floor_attempts"]) + 1
					row["floor_success"] = int(row["floor_success"]) \
						+ int(bool(event.success))
		if collect_ownership and side == "home" \
				and event.metadata.has("nearest_id"):
			_count_ownership(ownership, event)

	## Event-sequence invariants catch the exact counter failure that prompted
	## this audit: a terminal home offensive result may not exist without a home
	## ATTACK event before it.
	if outcome in ["kill", "blocked", "attack_error"] and home_attacks <= 0:
		failures += 1
	if outcome in ["opponent_kill", "counter_block", "opponent_attack_error"] \
			and opponent_attacks <= 0:
		failures += 1
	if outcome == "ace" and (
		bool(result.home_team_won) or home_receptions != 1 or home_attacks != 0
	):
		failures += 1
	if outcome == "serve_error" and (
		not bool(result.home_team_won) or home_receptions != 0 or home_attacks != 0
	):
		failures += 1
	if outcome != "serve_error" and home_receptions != 1:
		failures += 1
	if result.events.is_empty() \
			or int(result.events[-1].event_type) != RallyEvent.EventType.POINT:
		failures += 1
	return failures


func _count_receiver(row: Dictionary, event: Resource, lineup: RotationLineup) -> void:
	var receivers: Dictionary = row["receivers"]
	var key := str(int(event.actor_id))
	var receiver: Dictionary = receivers.get(key, {
		"id": int(event.actor_id),
		"name": str(event.actor_name),
		"attempts": 0,
		"success": 0,
		"slots": {},
	})
	receiver["attempts"] = int(receiver["attempts"]) + 1
	receiver["success"] = int(receiver["success"]) + int(bool(event.success))
	var slot := lineup.slot_for_player(int(event.actor_id)) if lineup != null else -1
	var slots: Dictionary = receiver["slots"]
	slots[slot] = int(slots.get(slot, 0)) + 1
	receivers[key] = receiver


func _count_reception_terms(row: Dictionary, event: Resource) -> int:
	var terms: Dictionary = event.metadata.get("reception_terms", {})
	if terms.is_empty():
		row["missing_reception_terms"] = int(row["missing_reception_terms"]) + 1
		return 1
	var term_samples: Dictionary = row["term_samples"]
	for key in RECEPTION_TERM_KEYS:
		if not terms.has(key):
			continue
		var samples: Array = term_samples.get(key, [])
		samples.append(float(terms[key]))
		term_samples[key] = samples
	var arrival: Dictionary = event.metadata.get("arrival", {})
	_append_sample(row, "reach_margin", float(arrival.get("reach_margin_meters", 0.0)))
	_append_sample(row, "distance", float(arrival.get("distance_meters", 0.0)))
	_append_sample(row, "read_error", float(arrival.get("read_error_meters", 0.0)))
	var reception_cases: Array = row["reception_cases"]
	reception_cases.append({
		"quality": float(terms.get("final_quality", event.quality)),
		"arrived": bool(terms.get("receiver_arrived", true)),
	})

	var reconstructed := float(terms.get("base", 0.0)) \
		+ float(terms.get("serve_pressure", 0.0)) \
		+ float(terms.get("risk_pressure", 0.0)) \
		+ float(terms.get("body_penalty", 0.0)) \
		+ float(terms.get("arrival_bonus", 0.0)) \
		+ float(terms.get("support_bonus", 0.0)) \
		+ float(terms.get("seam_penalty", 0.0)) \
		+ float(terms.get("execution_noise", 0.0))
	var failures := 0
	if absf(reconstructed - float(terms.get("unclamped_quality", reconstructed))) \
			> 0.00001:
		failures += 1
	if absf(float(event.quality) - float(terms.get("final_quality", event.quality))) \
			> 0.00001:
		failures += 1
	return failures


func _count_ownership(ownership: Dictionary, event: Resource) -> void:
	## Reached only for events carrying `nearest_id`, which is a claim contest --
	## reception and floor dig. Attack coverage is an assigned shape, not a
	## claim, and never sets it.
	var kind := "RECEPTION" \
		if int(event.event_type) == RallyEvent.EventType.RECEPTION else "DIG"
	var bucket: Dictionary = ownership.get(kind, {
		"claims": 0,
		"contested": 0,
		"locked": 0,
		"locked_multi": 0,
		"overtaken": 0,
		"spacing": [],
		"overtake_meters": [],
		"winner_meters": [],
	})
	bucket["claims"] = int(bucket["claims"]) + 1
	if int(event.metadata.get("reachable_count", 0)) > 1:
		bucket["contested"] = int(bucket["contested"]) + 1
	if bool(event.metadata.get("immediate_lock", false)):
		bucket["locked"] = int(bucket["locked"]) + 1
		if int(event.metadata.get("immediate_owner_count", 0)) > 1:
			bucket["locked_multi"] = int(bucket["locked_multi"]) + 1
	var spacing := float(event.metadata.get("nearest_teammate_meters", -1.0))
	if spacing >= 0.0 and spacing < 900.0:
		var spacing_samples: Array = bucket["spacing"]
		spacing_samples.append(spacing)
	var nearest_id := int(event.metadata.get("nearest_id", -1))
	var winner := float(event.metadata.get("winner_distance_meters", -1.0))
	var nearest := float(event.metadata.get("nearest_distance_meters", -1.0))
	if winner >= 0.0:
		var winner_samples: Array = bucket["winner_meters"]
		winner_samples.append(winner)
	if nearest_id >= 0 and nearest_id != int(event.actor_id) \
			and winner >= 0.0 and nearest >= 0.0:
		bucket["overtaken"] = int(bucket["overtaken"]) + 1
		var overtake_samples: Array = bucket["overtake_meters"]
		overtake_samples.append(winner - nearest)
	ownership[kind] = bucket


func _apply_legacy_slot_receive(plan: Resource, lineup: RotationLineup) -> void:
	var setter_slot := lineup.slot_for_player(lineup.active_setter_id())
	var passer_count := _passer_count()
	var passers := CourtConstants.serve_receive_passer_slots(
		setter_slot, passer_count, -1
	)
	var formation := CourtConstants.serve_receive_formation(
		setter_slot, CourtConstants.DEFAULT_SERVE_RECEIVE_FORMATION, -1, false,
		passers,
	)
	_apply_receive_zones(plan, lineup, passers, formation, true)


func _apply_stable_player_receive(
	plan: Resource,
	lineup: RotationLineup,
	players: Array,
) -> void:
	var setter_slot := lineup.slot_for_player(lineup.active_setter_id())
	var passers := CourtConstants.roster_serve_receive_seam_slots(
		lineup, players, _passer_count()
	)
	var formation := CourtConstants.serve_receive_formation(
		setter_slot, CourtConstants.DEFAULT_SERVE_RECEIVE_FORMATION, -1, false,
		passers, true,
	)
	_apply_receive_zones(plan, lineup, passers, formation, false)


func _apply_receive_zones(
	plan: Resource,
	lineup: RotationLineup,
	passers: Array[int],
	formation: Dictionary,
	legacy_priority: bool,
) -> void:
	for slot in range(1, 7):
		var player_id := lineup.player_at_slot(slot)
		var zone: Resource = plan.reception_zones.get(player_id) as Resource
		if zone == null:
			continue
		zone.center = Vector2(formation.get(slot, CourtConstants.slot_position(slot)))
		zone.enabled = slot in passers
		zone.radius_meters = 3.2
		zone.priority = (2 if slot in [5, 6] else 1) if legacy_priority \
			else (2 if zone.enabled else 1)


func _passer_count() -> int:
	return int(CourtConstants.SERVE_RECEIVE_FORMATIONS[
		CourtConstants.DEFAULT_SERVE_RECEIVE_FORMATION
	]["passer_count"])


func _same_serve(left_result: Resource, right_result: Resource) -> bool:
	var left := _opponent_serve(left_result)
	var right := _opponent_serve(right_result)
	if left == null or right == null:
		return left == right
	return bool(left.success) == bool(right.success) \
		and is_equal_approx(float(left.quality), float(right.quality)) \
		and Vector2(left.start_position).is_equal_approx(Vector2(right.start_position)) \
		and Vector2(left.end_position).is_equal_approx(Vector2(right.end_position)) \
		and str(left.metadata.get("target", "")) == str(right.metadata.get("target", ""))


func _opponent_serve(result: Resource) -> Resource:
	if result == null:
		return null
	for raw_event in result.events:
		var event: Resource = raw_event
		if event != null and int(event.event_type) == RallyEvent.EventType.SERVE \
				and str(event.metadata.get("side", "")) == "opponent":
			return event
	return null


func _append_sample(row: Dictionary, key: String, value: float) -> void:
	var samples: Array = row[key]
	samples.append(value)


func _print_roster(players: Array) -> void:
	print("=== exact generated roster: reception inputs")
	for raw_player in players:
		var player := raw_player as VolleyballPlayer
		if player == null:
			continue
		print("  id %2d  %-20s %-15s %-4s  rec %2d control %2d composure %2d  composite %.3f" % [
			player.id, player.display_name, player.position_role, player.position_code,
			player.reception, player.ball_control, player.composure,
			float(player.reception) * 0.0065 + float(player.ball_control) * 0.0020
				+ float(player.composure) * 0.0015,
		])


func _print_production(rows: Dictionary) -> void:
	print("=== production: %d paired rallies per rotation" % RALLIES_PER_ROTATION)
	for rotation in range(1, ROTATION_COUNT + 1):
		var row: Dictionary = rows[rotation]
		var outcomes: Dictionary = row["outcomes"]
		var attacks := int(row["home_attacks"])
		print("  R%d  ace %3d  kill %3d  blocked %3d  attack_error %3d  serve_error %3d" % [
			rotation,
			int(outcomes.get("ace", 0)),
			int(outcomes.get("kill", 0)),
			int(outcomes.get("blocked", 0)),
			int(outcomes.get("attack_error", 0)),
			int(outcomes.get("serve_error", 0)),
		])
		print("      reception %3d/%3d  home attacks %3d  opp attacks %3d  blocked/attack %.3f" % [
			int(row["home_reception_success"]), int(row["home_receptions"]),
			attacks, int(row["opponent_attacks"]),
			float(outcomes.get("blocked", 0)) / maxf(float(attacks), 1.0),
		])
		print("      floor %3d/%3d  attack coverage %3d/%3d  receivers %s" % [
			int(row["floor_success"]), int(row["floor_attempts"]),
			int(row["coverage_success"]), int(row["coverage_attempts"]),
			_receiver_summary(row),
		])
		var terms: Dictionary = row["term_samples"]
		print("      medians q %.3f  serve %.3f  base %.3f  body %.3f  arrival %.3f  seam %.3f  reach %.3f m  read %.3f m" % [
			_median(row["reception_quality"]), _median(row["serve_quality"]),
			_median(terms.get("base", [])), _median(terms.get("body_penalty", [])),
			_median(terms.get("arrival_bonus", [])),
			_median(terms.get("seam_penalty", [])),
			_median(row["reach_margin"]), _median(row["read_error"]),
		])
		print("      projected aces @ .18/.14/.10: %d / %d / %d" % [
			_projected_aces(row, 0.18), _projected_aces(row, 0.14),
			_projected_aces(row, 0.10),
		])
		print("      counter health: missing side %d  missing reception terms %d" % [
			int(row["missing_side"]), int(row["missing_reception_terms"]),
		])


func _print_counterfactual(
	production: Dictionary,
	legacy_slots: Dictionary,
	stable_lanes: Dictionary,
	serve_mismatches: int,
) -> void:
	print("=== paired first-contact counterfactual")
	print("    production = roster passers/minimum travel; stable = same passers/fixed player lanes; legacy = rotation slots")
	for rotation in range(1, ROTATION_COUNT + 1):
		var prod: Dictionary = production[rotation]
		var legacy: Dictionary = legacy_slots[rotation]
		var stable: Dictionary = stable_lanes[rotation]
		print("  R%d  aces prod %3d  stable %3d  legacy %3d   primary prod [%s] stable [%s]" % [
			rotation,
			_outcome_count(prod, "ace"),
			_outcome_count(stable, "ace"),
			_outcome_count(legacy, "ace"),
			_receiver_summary(prod),
			_receiver_summary(stable),
		])
	print("  same-serve mismatches: %d of %d paired triplets" % [
		serve_mismatches, RALLIES_PER_ROTATION * ROTATION_COUNT,
	])


func _print_ownership(ownership: Dictionary) -> void:
	var kinds: Array = ownership.keys()
	kinds.sort()
	for kind in kinds:
		var bucket: Dictionary = ownership[kind]
		print("=== %s ownership (home side only)" % kind)
		print("  claims %d, contested %d, immediate lock %d, shared lock %d" % [
			int(bucket["claims"]), int(bucket["contested"]),
			int(bucket["locked"]), int(bucket["locked_multi"]),
		])
		print("  nearest player overtaken %d (%.2f%% of contested)" % [
			int(bucket["overtaken"]),
			100.0 * float(bucket["overtaken"]) / maxf(float(bucket["contested"]), 1.0),
		])
		_report("  nearest reachable teammate spacing (m)", bucket["spacing"])
		_report("  winner extra distance over nearest (m)", bucket["overtake_meters"])
		_report("  winner distance to ball (m)", bucket["winner_meters"])


func _receiver_summary(row: Dictionary) -> String:
	var receivers: Dictionary = row["receivers"]
	var summaries: Array[Dictionary] = []
	for key in receivers:
		summaries.append(receivers[key])
	summaries.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a["attempts"]) > int(b["attempts"])
	)
	var parts: Array[String] = []
	for receiver in summaries:
		parts.append("%s#%d %d/%d" % [
			str(receiver["name"]), int(receiver["id"]),
			int(receiver["success"]), int(receiver["attempts"]),
		])
	return ", ".join(parts)


func _outcome_count(row: Dictionary, outcome: String) -> int:
	return int(Dictionary(row["outcomes"]).get(outcome, 0))


func _projected_aces(row: Dictionary, threshold: float) -> int:
	var count := 0
	for raw_case in row["reception_cases"]:
		var reception_case: Dictionary = raw_case
		if not bool(reception_case.get("arrived", true)) \
				or float(reception_case.get("quality", 0.0)) < threshold:
			count += 1
	return count


func _median(samples: Array) -> float:
	if samples.is_empty():
		return 0.0
	var values: Array[float] = []
	for raw in samples:
		values.append(float(raw))
	values.sort()
	return values[values.size() / 2]


func _report(label: String, samples: Array) -> void:
	if samples.is_empty():
		print("%s: no samples" % label)
		return
	var values: Array[float] = []
	for raw in samples:
		values.append(float(raw))
	values.sort()
	var total := 0.0
	for value in values:
		total += value
	print("%s: n=%d  p05 %.2f  median %.2f  mean %.2f  p95 %.2f  max %.2f" % [
		label, values.size(),
		values[int(floor(float(values.size() - 1) * 0.05))],
		values[values.size() / 2],
		total / float(values.size()),
		values[int(floor(float(values.size() - 1) * 0.95))],
		values[-1],
	])
