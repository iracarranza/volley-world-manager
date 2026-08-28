extends SceneTree

## M9-A: controlled tactical A/B certification.
##
## Same hand-authored roster, rotation and seed on both sides of every pair.
## Exactly one manager instruction changes. Gates stop at the first physical /
## actor-state consequence; terminal outcomes are printed only as observations.
##
## No balance target and no fitted magnitude lives in this instrument.

const GameManagerScript := preload("res://scripts/managers/game_manager.gd")
const RallyEventScript := preload("res://scripts/models/rally_event.gd")

const SEARCH_FROM := 76000
const SEARCH_SPAN := 500

var failures := 0


func _initialize() -> void:
	print("\n=== M9-A tactical A/B certification ===")
	_test_serve_target()
	_test_defensive_depth()
	_test_block_defense_relationship()
	_test_setter_release_target()
	if failures == 0:
		print("\nPASS: M9-A spatial tactical instructions reach authoritative rally state")
		quit(0)
		return
	push_error("FAIL: %d M9-A tactical A/B gates" % failures)
	quit(1)


func _gate(condition: bool, description: String) -> void:
	print("  %s  %s" % ["ok  " if condition else "FAIL", description])
	if not condition:
		failures += 1


func _test_serve_target() -> void:
	print("\nA1 serve target: Zone 5 <-> Zone 1")
	var pair := {}
	for seed_value in range(SEARCH_FROM, SEARCH_FROM + SEARCH_SPAN):
		var zone5 := _resolve(seed_value, true, {"serve_target": "Zone 5"})
		var zone1 := _resolve(seed_value, true, {"serve_target": "Zone 1"})
		var a: Resource = _event(zone5.rally, RallyEventScript.EventType.SERVE, "home")
		var b: Resource = _event(zone1.rally, RallyEventScript.EventType.SERVE, "home")
		if a != null and b != null and bool(a.success) and bool(b.success) \
				and a.metadata.has("aim_point") and b.metadata.has("aim_point"):
			pair = {"seed": seed_value, "a": a, "b": b,
				"out_a": zone5.outcome, "out_b": zone1.outcome}
			break
	_gate(not pair.is_empty(), "found same-seed successful serves for both calls")
	if pair.is_empty():
		return
	var a: Resource = pair.a
	var b: Resource = pair.b
	var aim_a := Vector2(a.metadata.aim_point)
	var aim_b := Vector2(b.metadata.aim_point)
	_gate(str(a.metadata.get("called_target", "")) == "Zone 5",
		"Zone 5 call reaches the serve decision")
	_gate(str(b.metadata.get("called_target", "")) == "Zone 1",
		"Zone 1 call reaches the serve decision")
	_gate(aim_a.x < aim_b.x,
		"same server/seed aims Zone 5 left of Zone 1 before outcome")
	print("    seed %d | aim x %.3f -> %.3f | realised landing x %.3f -> %.3f | terminal %s -> %s" % [
		int(pair.seed), aim_a.x, aim_b.x, a.end_position.x, b.end_position.x,
		str(pair.out_a), str(pair.out_b),
	])


func _test_defensive_depth() -> void:
	print("\nA2 defensive depth: Shallow <-> Deep")
	var pair := _find_opponent_attack_pair(
		{"defensive_depth": "Shallow"}, {"defensive_depth": "Deep"}
	)
	_gate(not pair.is_empty(), "found same-seed opponent attack under both depths")
	if pair.is_empty():
		return
	var shallow: Dictionary = pair.a.metadata.get("home_phase_targets", {})
	var deep: Dictionary = pair.b.metadata.get("home_phase_targets", {})
	_gate(not shallow.is_empty() and not deep.is_empty(),
		"opponent attack publishes home defensive actor state in both variants")
	var shared := _shared_ids(shallow, deep)
	_gate(not shared.is_empty(), "the two variants publish the same defenders for comparison")
	if shared.is_empty():
		return
	var shallow_y := _mean_axis(shallow, shared, false)
	var deep_y := _mean_axis(deep, shared, false)
	_gate(deep_y > shallow_y,
		"Deep produces a physically deeper established home shape than Shallow")
	var changed := _changed_positions(shallow, deep, shared)
	_gate(changed > 0, "manager depth call changes realised defender positions")
	print("    seed %d | mean home y %.4f -> %.4f | changed actors %d/%d | terminal %s -> %s" % [
		int(pair.seed), shallow_y, deep_y, changed, shared.size(),
		str(pair.out_a), str(pair.out_b),
	])


func _test_block_defense_relationship() -> void:
	print("\nA3 block/defence relationship: Defend Line <-> Defend Cross")
	var pair := _find_opponent_attack_pair(
		{"block_defense_relationship": "Defend Line"},
		{"block_defense_relationship": "Defend Cross"}
	)
	_gate(not pair.is_empty(), "found same-seed opponent attack under both relationships")
	if pair.is_empty():
		return
	var line: Dictionary = pair.a.metadata.get("home_phase_targets", {})
	var cross: Dictionary = pair.b.metadata.get("home_phase_targets", {})
	var shared := _shared_ids(line, cross)
	_gate(not shared.is_empty(), "both relationships publish comparable home defenders")
	if shared.is_empty():
		return
	var line_x := _mean_axis(line, shared, true)
	var cross_x := _mean_axis(cross, shared, true)
	var attack_x := float(pair.a.start_position.x)
	var signed_expected := attack_x - 0.5
	var signed_observed := line_x - cross_x
	_gate(absf(signed_observed) > 0.000001,
		"Line and Cross produce different realised defensive geometry")
	if absf(signed_expected) > 0.000001:
		_gate(signed_observed * signed_expected > 0.0,
			"defensive shift follows the attack-side line/cross direction")
	var changed := _changed_positions(line, cross, shared)
	print("    seed %d | attack x %.3f | mean floor x line %.4f / cross %.4f | changed actors %d/%d | terminal %s -> %s" % [
		int(pair.seed), attack_x, line_x, cross_x, changed, shared.size(),
		str(pair.out_a), str(pair.out_b),
	])


func _test_setter_release_target() -> void:
	print("\nA4 setter release target: left <-> right")
	## Contrasting fixture inputs, not gameplay constants. Both are inside the
	## existing DefensivePlan setter-release bounds and change no model magnitude.
	var left := Vector2(0.35, 0.60)
	var right := Vector2(0.65, 0.60)
	var pair := {}
	for seed_value in range(SEARCH_FROM, SEARCH_FROM + SEARCH_SPAN):
		var a_run := _resolve(seed_value, false, {"setter_release_target": left})
		var b_run := _resolve(seed_value, false, {"setter_release_target": right})
		var a_receive: Resource = _event(a_run.rally, RallyEventScript.EventType.RECEPTION, "home")
		var b_receive: Resource = _event(b_run.rally, RallyEventScript.EventType.RECEPTION, "home")
		var a_set: Resource = _event(a_run.rally, RallyEventScript.EventType.SET, "home")
		var b_set: Resource = _event(b_run.rally, RallyEventScript.EventType.SET, "home")
		if a_receive == null or b_receive == null or a_set == null or b_set == null:
			continue
		if int(a_set.actor_id) != int(b_set.actor_id):
			continue
		if not a_receive.metadata.has("setter_release_target") \
				or not b_receive.metadata.has("setter_release_target") \
				or not a_receive.metadata.has("desired_pass_target") \
				or not b_receive.metadata.has("desired_pass_target") \
				or not a_set.metadata.has("body_contact_position") \
				or not b_set.metadata.has("body_contact_position"):
			continue
		pair = {"seed": seed_value, "ra": a_receive, "rb": b_receive,
			"sa": a_set, "sb": b_set, "out_a": a_run.outcome, "out_b": b_run.outcome}
		break
	_gate(not pair.is_empty(), "found same-seed home reception/set with same setter")
	if pair.is_empty():
		return
	var ra: Resource = pair.ra
	var rb: Resource = pair.rb
	var sa: Resource = pair.sa
	var sb: Resource = pair.sb
	var release_a := Vector2(ra.metadata.setter_release_target)
	var release_b := Vector2(rb.metadata.setter_release_target)
	var pass_a := Vector2(ra.metadata.desired_pass_target)
	var pass_b := Vector2(rb.metadata.desired_pass_target)
	var body_a := Vector2(sa.metadata.body_contact_position)
	var body_b := Vector2(sb.metadata.body_contact_position)
	_gate(release_a.is_equal_approx(left) and release_b.is_equal_approx(right),
		"manager release coordinates reach reception intent unchanged")
	_gate(pass_a.x < pass_b.x,
		"the platform aim moves toward the changed release seat")
	_gate(body_a.x < body_b.x,
		"the same setter physically contacts the second ball farther right when told right")
	print("    seed %d | release x %.3f -> %.3f | pass intent x %.3f -> %.3f | setter body x %.3f -> %.3f | terminal %s -> %s" % [
		int(pair.seed), release_a.x, release_b.x, pass_a.x, pass_b.x,
		body_a.x, body_b.x, str(pair.out_a), str(pair.out_b),
	])


func _find_opponent_attack_pair(a_change: Dictionary, b_change: Dictionary) -> Dictionary:
	for seed_value in range(SEARCH_FROM, SEARCH_FROM + SEARCH_SPAN):
		var a_run := _resolve(seed_value, false, a_change)
		var b_run := _resolve(seed_value, false, b_change)
		var a: Resource = _event(a_run.rally, RallyEventScript.EventType.ATTACK, "opponent")
		var b: Resource = _event(b_run.rally, RallyEventScript.EventType.ATTACK, "opponent")
		if a == null or b == null:
			continue
		if Dictionary(a.metadata.get("home_phase_targets", {})).is_empty() \
				or Dictionary(b.metadata.get("home_phase_targets", {})).is_empty():
			continue
		return {"seed": seed_value, "a": a, "b": b,
			"out_a": a_run.outcome, "out_b": b_run.outcome}
	return {}


func _resolve(seed_value: int, serving_home: bool, changes: Dictionary) -> Dictionary:
	var manager: Object = GameManagerScript.new()
	manager.seed_vertical_slice_data()
	manager.selected_rotation = 1
	manager.match_state.serving_home = serving_home
	var plan: Resource = manager.current_defensive_plan()
	if changes.has("serve_target"):
		plan.serve_target = str(changes.serve_target)
	if changes.has("defensive_depth"):
		plan.defensive_depth = str(changes.defensive_depth)
	if changes.has("block_defense_relationship"):
		plan.block_defense_relationship = str(changes.block_defense_relationship)
	if changes.has("block_intent"):
		plan.block_intent = str(changes.block_intent)
	if changes.has("setter_release_target"):
		plan.set_setter_release_target(
			manager.current_lineup().active_setter_id(),
			Vector2(changes.setter_release_target)
		)
	var rally: Resource = manager.resolve_active_rally(seed_value)
	var outcome := str(rally.terminal_outcome) if rally != null else "none"
	manager.free()
	return {"rally": rally, "outcome": outcome}


func _event(rally: Resource, event_type: int, side: String) -> Resource:
	if rally == null:
		return null
	for event_resource in rally.events:
		var event := event_resource as Resource
		if event == null or int(event.event_type) != event_type:
			continue
		if str(event.metadata.get("side", "")) == side:
			return event
	return null


func _shared_ids(a: Dictionary, b: Dictionary) -> Array[int]:
	var ids: Array[int] = []
	for raw_id in a:
		var player_id := int(raw_id)
		if b.has(raw_id) or b.has(player_id) or b.has(str(player_id)):
			ids.append(player_id)
	return ids


func _position_of(map: Dictionary, player_id: int) -> Vector2:
	if map.has(player_id):
		return Vector2(map[player_id])
	if map.has(str(player_id)):
		return Vector2(map[str(player_id)])
	return Vector2.ZERO


func _mean_axis(map: Dictionary, ids: Array[int], x_axis: bool) -> float:
	if ids.is_empty():
		return NAN
	var total := 0.0
	for player_id in ids:
		var point := _position_of(map, player_id)
		total += point.x if x_axis else point.y
	return total / float(ids.size())


func _changed_positions(a: Dictionary, b: Dictionary, ids: Array[int]) -> int:
	var changed := 0
	for player_id in ids:
		if _position_of(a, player_id).distance_to(_position_of(b, player_id)) > 0.000001:
			changed += 1
	return changed
