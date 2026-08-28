extends SceneTree

## Focused gate for the career-roster serve-receive regression.
##
## The vertical slice's ids happen to follow its role order. Career generation
## does not. This fixture deliberately remaps the same seven bodies to the career
## order before asking GameManager to build its mirrored opponent, then checks
## every rotation's passing unit and the authoritative ace/reception relationship.

const GameManagerScript := preload("res://scripts/managers/game_manager.gd")
const TeamScript := preload("res://scripts/models/team.gd")
const MatchFormatScript := preload("res://scripts/models/match_format.gd")
const RallySimulatorScript := preload("res://scripts/simulation/rally_simulator.gd")
const CoverageCalculatorScript := preload("res://scripts/simulation/coverage_calculator.gd")

const SEEDS_PER_ROTATION: int = 80
const FIRST_SEED: int = 68000

var checks := 0
var failures := 0


func _initialize() -> void:
	for argument in OS.get_cmdline_user_args():
		if str(argument).begins_with("--save="):
			_audit_saved_career(str(argument).trim_prefix("--save="))
			return
	var manager := _career_order_manager()
	_check(manager != null, "career-order fixture builds")
	if manager == null:
		_finish()
		return

	var expected_sources := _players_by_role(manager.players)
	var expected := {
		101: ["Setter", 0],
		102: ["Outside Hitter", 0],
		103: ["Middle Blocker", 0],
		104: ["Opposite", 0],
		105: ["Outside Hitter", 1],
		106: ["Libero", 0],
		107: ["Middle Blocker", 1],
	}
	var exact_role_mirror := true
	for opponent_id in expected:
		var specification: Array = expected[opponent_id]
		var role := str(specification[0])
		var occurrence := int(specification[1])
		var sources: Array = expected_sources.get(role, [])
		var source: VolleyballPlayer = sources[occurrence] as VolleyballPlayer
		var mirrored := manager.opponent_team.player_by_id(opponent_id) as VolleyballPlayer
		exact_role_mirror = exact_role_mirror and mirrored != null \
			and str(mirrored.position_role) == role \
			and int(mirrored.reception) == int(source.reception) \
			and int(mirrored.ball_control) == int(source.ball_control) \
			and int(mirrored.anticipation) == int(source.anticipation) \
			and is_equal_approx(float(mirrored.height_cm), float(source.height_cm))
	_check(exact_role_mirror, "opponent attributes mirror the same role, not a prototype id")

	var unassigned_receivers := 0
	var emergency_receivers := 0
	var aces := 0
	var successful_receptions := 0
	var longest_ace_run := 0
	var contact_controls: Array[float] = []
	for rotation_number in range(1, 7):
		var ace_run := 0
		for offset in range(SEEDS_PER_ROTATION):
			var rally_manager := _career_order_manager()
			rally_manager.opponent_team.select_rotation(rotation_number)
			rally_manager.match_state.opponent_rotation = rotation_number
			rally_manager.match_state.serving_home = true
			var result: Resource = rally_manager.resolve_active_rally(
				FIRST_SEED + rotation_number * 1000 + offset
			)
			var reception := _first_reception(result)
			if reception != null and bool(Dictionary(reception.metadata.get(
				"reception_terms", {}
			)).get("receiver_arrived", false)):
				contact_controls.append(float(Dictionary(reception.metadata.get(
					"reception_terms", {}
				)).get("contact_control", 0.0)))
			var assigned_ids := _opponent_passing_unit(rally_manager)
			if reception != null and int(reception.actor_id) not in assigned_ids:
				var arrival: Dictionary = reception.metadata.get("arrival", {})
				if bool(reception.metadata.get("emergency_receive", false)) \
						and bool(arrival.get("reachable", false)):
					emergency_receivers += 1
				else:
					unassigned_receivers += 1
			var is_ace := str(result.terminal_outcome) == "ace"
			if is_ace:
				aces += 1
				ace_run += 1
				longest_ace_run = maxi(longest_ace_run, ace_run)
				var terms: Dictionary = reception.metadata.get(
					"reception_terms", {}
				) if reception != null else {}
				_check(
					reception != null and not bool(reception.success)
						and str(terms.get("success_metric", "")) == "contact_control_roll"
						and (
							not bool(terms.get("receiver_arrived", false))
							or float(terms.get("outcome_roll", 1.0))
								< float(terms.get("failure_chance", 0.0))
						),
					"ace is the failed reception outcome for rotation %d seed %d" % [
						rotation_number, FIRST_SEED + rotation_number * 1000 + offset,
					],
				)
			else:
				ace_run = 0
				if reception != null and bool(reception.success):
					successful_receptions += 1
			rally_manager.free()
	_check(unassigned_receivers == 0, "every serve-reception actor belongs to the assigned passing unit")
	_check(successful_receptions > 0, "the career-order passing unit produces controlled receptions")
	_check(aces > 0, "the same fixture still permits physically failed receptions")
	_check(
		longest_ace_run < 10,
		"the six-rotation census does not reproduce a ten-ace deterministic collapse",
	)
	print("serve reception census: %d receptions, %d aces, max ace run %d, invalid unassigned %d, emergency %d" % [
		successful_receptions, aces, longest_ace_run, unassigned_receivers,
		emergency_receivers,
	])
	contact_controls.sort()
	if not contact_controls.is_empty():
		print("arrived contact control p02 %.3f p05 %.3f p07 %.3f p10 %.3f" % [
			_percentile(contact_controls, 0.02), _percentile(contact_controls, 0.05),
			_percentile(contact_controls, 0.07), _percentile(contact_controls, 0.10),
		])
	manager.free()
	_finish()


func _audit_saved_career(save_id: String) -> void:
	var path := "user://careers/%s.json" % save_id.validate_filename()
	var file := FileAccess.open(path, FileAccess.READ)
	_check(file != null, "saved career %s opens" % save_id)
	if file == null:
		_finish()
		return
	var payload: Variant = JSON.parse_string(file.get_as_text())
	_check(payload is Dictionary, "saved career payload parses")
	if not (payload is Dictionary):
		_finish()
		return
	var data: Dictionary = payload
	var game_data: Dictionary = data.get("game_state", {})
	var career_data: Dictionary = data.get("career", {})
	var manager := GameManagerScript.new()
	manager.from_dict(game_data)
	var fixture_id := int(career_data.get("active_fixture_id", -1))
	var fixture: Dictionary = {}
	for raw_fixture in career_data.get("fixtures", []):
		if int(Dictionary(raw_fixture).get("id", -1)) == fixture_id:
			fixture = raw_fixture
			break
	if not fixture.is_empty():
		manager.set_opponent_region(
			str(fixture.get("opponent_region", "")),
			int(fixture.get("opponent_club_index", 0)),
		)
	print("saved fixture: %s (%s), rotation %d" % [
		manager.opponent_team.team_name, manager.opponent_team.region,
		manager.opponent_team.current_rotation,
	])
	for opponent_id in range(101, 108):
		var player := manager.opponent_team.player_by_id(opponent_id) as VolleyballPlayer
		print("  %d %-15s reception %d control %d" % [
			opponent_id, player.position_role, player.reception, player.ball_control,
		])

	var historical_run := 0
	var historical_max := 0
	for raw_row in Dictionary(game_data.get("match_state", {})).get(
		"rally_history", []
	):
		if str(Dictionary(raw_row).get("outcome", "")) == "ace":
			historical_run += 1
			historical_max = maxi(historical_max, historical_run)
		else:
			historical_run = 0
	print("saved historical maximum ace run: %d" % historical_max)
	var home_lineup: RotationLineup = manager.current_lineup()
	var home_server := manager.player_by_id(
		home_lineup.player_at_slot(1) if home_lineup != null else -1
	) as VolleyballPlayer
	if home_server != null:
		print("current home server: %s (%s) power %d technique %d placement %d consistency %d" % [
			home_server.display_name, home_server.position_role,
			home_server.serve_power, home_server.serve_technique,
			home_server.serve_placement, home_server.serve_consistency,
		])

	var career_name := str(career_data.get("career_name", save_id))
	var base_seed := absi(hash("%s|fixture|%d" % [career_name, fixture_id]))
	var history_size := Array(Dictionary(game_data.get("match_state", {})).get(
		"rally_history", []
	)).size()
	var future_run := 0
	var future_max := 0
	var future_aces := 0
	var invalid_unassigned := 0
	var emergency_receives := 0
	var printed_aces := 0
	var ace_short := 0
	var ace_deep := 0
	var ace_middle_depth := 0
	for offset in range(120):
		var sample := GameManagerScript.new()
		sample.from_dict(game_data)
		if not fixture.is_empty():
			sample.set_opponent_region(
				str(fixture.get("opponent_region", "")),
				int(fixture.get("opponent_club_index", 0)),
			)
		var result: Resource = sample.resolve_active_rally(
			base_seed + history_size + offset
		)
		var reception := _first_reception(result)
		if reception != null:
			var assigned := _opponent_passing_unit(sample) \
				if bool(sample.match_state.serving_home) \
				else _home_passing_unit(sample)
			if int(reception.actor_id) not in assigned:
				var emergency := bool(reception.metadata.get(
					"emergency_receive", false
				))
				var emergency_arrival: Dictionary = reception.metadata.get(
					"arrival", {}
				)
				if emergency and bool(emergency_arrival.get(
					"reachable", false
				)):
					emergency_receives += 1
				else:
					invalid_unassigned += 1
		var is_ace := str(result.terminal_outcome) == "ace"
		if is_ace:
			future_aces += 1
			var ace_landing := Vector2(reception.start_position) \
				if reception != null else Vector2.ZERO
			if ace_landing.y >= 0.40:
				ace_short += 1
			elif ace_landing.y <= 0.10:
				ace_deep += 1
			else:
				ace_middle_depth += 1
			future_run += 1
			future_max = maxi(future_max, future_run)
			if reception != null and printed_aces < 3:
				printed_aces += 1
				var terms: Dictionary = reception.metadata.get("reception_terms", {})
				var arrival: Dictionary = reception.metadata.get("arrival", {})
				var serve_event := result.events[0] as RallyEvent
				print(
					(
						"  ace seed %d actor %d q %.3f arrived %s fallback %s "
						+ "distance %.2f reach %.2f margin %.2f base %.3f pressure %.3f body %.3f target %s aim %s"
					) % [
						base_seed + history_size + offset, int(reception.actor_id),
						float(reception.quality),
						str(terms.get("receiver_arrived", false)),
						str(reception.metadata.get("reception_claim_fallback", false)),
						float(arrival.get("distance_meters", -1.0)),
						float(arrival.get("physical_reach_meters", -1.0)),
						float(arrival.get("reach_margin_meters", -1.0)),
						float(terms.get("base", 0.0)),
						float(terms.get("serve_pressure", 0.0))
							+ float(terms.get("risk_pressure", 0.0)),
						float(terms.get("body_penalty", 0.0)),
						str(serve_event.metadata.get("target", "")),
						str(serve_event.metadata.get("aim_point", Vector2.ZERO)),
					]
				)
				if printed_aces <= 3:
					var debug_simulator := RallySimulatorScript.new()
					var coverage: Dictionary = debug_simulator._opponent_reception_coverage(
						sample.opponent_team
					)
					var landing := Vector2(reception.start_position)
					var flight_time := float(reception.metadata.get("flight_time", 0.0))
					print("    landing %s flight %.3fs" % [landing, flight_time])
					for passer in coverage.players:
						var zone: Resource = coverage.zones.get(passer.id)
						var evaluated: Dictionary = CoverageCalculatorScript.evaluate_arrival(
							passer, zone, landing, flight_time, "reception"
						)
						print(
							"      %d %s origin %s dist %.2f reach %.2f reaction %.2f travel %.2f reachable %s" % [
								passer.id, passer.position_role, zone.center,
								float(evaluated.get("distance_meters", -1.0)),
								float(evaluated.get("physical_reach_meters", -1.0)),
								float(evaluated.get("reaction_delay", -1.0)),
								float(evaluated.get("travel_distance_meters", -1.0)),
								str(evaluated.get("reachable", false)),
							]
						)
		else:
			future_run = 0
		sample.free()
	print("next-seed audit: %d aces / 120, max run %d, invalid unassigned %d, emergency %d" % [
		future_aces, future_max, invalid_unassigned, emergency_receives,
	])
	print("ace landing depths: %d short, %d middle, %d deep" % [
		ace_short, ace_middle_depth, ace_deep,
	])
	_check(
		invalid_unassigned == 0,
		"saved career uses non-passers only for physically reachable emergency contacts",
	)
	_check(future_max < 10, "saved career no longer reproduces a ten-ace collapse")
	manager.free()
	_finish()


func _career_order_manager() -> Object:
	var manager := GameManagerScript.new()
	manager.seed_vertical_slice_data()
	var original := {}
	for player in manager.players:
		original[str(player.position_code)] = player
	var career_order: Array[VolleyballPlayer] = []
	for entry in [
		["S", 1], ["OH1", 2], ["OH2", 3], ["M1", 4],
		["M2", 5], ["OP", 6], ["L", 7],
	]:
		var player := original.get(str(entry[0])) as VolleyballPlayer
		if player == null:
			manager.free()
			return null
		player.id = int(entry[1])
		career_order.append(player)
	var team := TeamScript.new()
	team.team_name = "Career Order Fixture"
	team.apply_identity("Balanced")
	var error: String = manager.configure_managed_team(team, career_order)
	if not error.is_empty():
		push_error(error)
		manager.free()
		return null
	manager.start_new_match(MatchFormatScript.new())
	return manager


func _players_by_role(players: Array) -> Dictionary:
	var result := {}
	for raw_player in players:
		var player := raw_player as VolleyballPlayer
		if player == null:
			continue
		if not result.has(player.position_role):
			result[player.position_role] = []
		Array(result[player.position_role]).append(player)
	return result


func _opponent_passing_unit(manager: Object) -> Array[int]:
	var lineup: RotationLineup = manager.opponent_team.current_lineup()
	var passer_count := int(CourtConstants.SERVE_RECEIVE_FORMATIONS[
		CourtConstants.DEFAULT_SERVE_RECEIVE_FORMATION
	]["passer_count"])
	var slots := CourtConstants.roster_serve_receive_passer_slots(
		lineup, manager.opponent_team.players, passer_count
	)
	var ids: Array[int] = []
	for slot_number in slots:
		ids.append(int(lineup.player_at_slot(slot_number)))
	return ids


func _home_passing_unit(manager: Object) -> Array[int]:
	var lineup: RotationLineup = manager.current_lineup()
	var passer_count := int(CourtConstants.SERVE_RECEIVE_FORMATIONS[
		CourtConstants.DEFAULT_SERVE_RECEIVE_FORMATION
	]["passer_count"])
	var slots := CourtConstants.roster_serve_receive_passer_slots(
		lineup, manager.players, passer_count
	)
	var ids: Array[int] = []
	for slot_number in slots:
		ids.append(int(lineup.player_at_slot(slot_number)))
	return ids


func _first_reception(result: Resource) -> RallyEvent:
	if result == null:
		return null
	for raw_event in result.events:
		var event := raw_event as RallyEvent
		if event != null and event.event_type == RallyEvent.EventType.RECEPTION:
			return event
	return null


func _check(condition: bool, description: String) -> void:
	checks += 1
	if condition:
		return
	failures += 1
	push_error("FAIL: %s" % description)


func _percentile(values: Array[float], fraction: float) -> float:
	if values.is_empty():
		return 0.0
	var index := clampi(roundi(fraction * float(values.size() - 1)), 0, values.size() - 1)
	return float(values[index])


func _finish() -> void:
	if failures == 0:
		print("PASS: %d serve-reception authority checks" % checks)
	else:
		print("FAIL: %d of %d serve-reception authority checks" % [failures, checks])
	quit(0 if failures == 0 else 1)
