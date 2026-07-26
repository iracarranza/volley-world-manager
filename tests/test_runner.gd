extends SceneTree

const GAME_MANAGER_SCRIPT := preload("res://scripts/managers/game_manager.gd")
const RALLY_EVENT_SCRIPT := preload("res://scripts/models/rally_event.gd")
const ROTATION_LEGALITY_SCRIPT := preload("res://scripts/simulation/rotation_legality.gd")

var checks: int = 0
var failures: int = 0


func _initialize() -> void:
	_test_court_coordinates()
	_test_rotation_legality()
	_test_serve_receive_overlap_bounds()
	_test_play_validation_and_serialization()
	_test_back_row_lane_restriction()
	_test_tactical_demand()
	_test_manager_playbook_and_serialization()
	_test_seeded_rally_resolution()
	_test_match_scoring_and_rotation()
	_test_defense_opponent_and_match_day_controls()
	_test_coverage_arrival_and_reception_ownership()
	_test_second_contact_ownership()
	_test_block_closing_and_touch_distribution()
	_test_physical_body_attributes()
	_test_tactical_playback_reset_on_lineup_change()
	_test_default_offense_without_saved_play()
	if failures == 0:
		print("PASS: %d volleyball foundation checks" % checks)
		quit(0)
	else:
		push_error("FAIL: %d of %d checks failed" % [failures, checks])
		quit(1)


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error("TEST FAILED: %s" % message)


func _test_court_coordinates() -> void:
	_check(
		is_equal_approx(
			CourtConstants.HOME_ATTACK_LINE_Y - CourtConstants.NET_Y,
			(CourtConstants.HOME_BASELINE_Y - CourtConstants.HOME_ATTACK_LINE_Y) / 2.0,
		),
		"front and back court depths preserve the regulation 1:2 ratio",
	)
	_check(18.0 / 9.0 == 2.0, "full court dimensions use a 9 by 18 metre ratio")
	for slot_number in range(1, 7):
		_check(
			CourtConstants.is_normalized(CourtConstants.slot_position(slot_number)),
			"rotation slot %d uses normalized coordinates" % slot_number,
		)
	for lane_name in CourtConstants.LANES:
		_check(
			CourtConstants.is_normalized(CourtConstants.lane_target(lane_name)),
			"%s target uses normalized coordinates" % lane_name,
		)


func _make_lineup() -> RotationLineup:
	var lineup := RotationLineup.new()
	lineup.rotation_number = 1
	lineup.setter_id = 1
	for slot_number in range(1, 7):
		lineup.assign_slot(slot_number, slot_number)
	return lineup


func _test_rotation_legality() -> void:
	var lineup := _make_lineup()
	_check(lineup.validate().is_empty(), "six unique players create a valid rotation")
	_check(lineup.front_row_player_ids() == [2, 3, 4], "front-row IDs follow slots 2–4")
	_check(
		lineup.assign_slot(2, 1) != "",
		"one player cannot occupy two rotation slots",
	)
	var restored := RotationLineup.from_dict(lineup.to_dict())
	_check(restored.player_at_slot(4) == 4, "rotation survives serialization")


func _test_serve_receive_overlap_bounds() -> void:
	var positions := {}
	for slot_number in range(1, 7):
		positions[slot_number] = CourtConstants.slot_position(slot_number)
	var middle_front_bounds: Rect2 = ROTATION_LEGALITY_SCRIPT.legal_bounds(3, positions)
	_check(
		middle_front_bounds.position.x > Vector2(positions[4]).x
			and middle_front_bounds.end.x < Vector2(positions[2]).x,
		"front-middle legality is bounded by both same-row neighbors",
	)
	_check(
		middle_front_bounds.end.y < Vector2(positions[6]).y,
		"front-middle must remain closer to the net than back-middle",
	)
	_check(
		ROTATION_LEGALITY_SCRIPT.is_position_legal(
			3, Vector2(0.50, 0.62), positions
		),
		"a correctly overlapped front-middle reception position is legal",
	)
	_check(
		not ROTATION_LEGALITY_SCRIPT.is_position_legal(
			3, Vector2(0.90, 0.62), positions
		),
		"crossing the right-front player is identified as an overlap fault",
	)


func _make_play() -> OffensivePlay:
	var play := OffensivePlay.new()
	play.play_name = "Quick Left"
	play.rotation_number = 1
	var left_pin := HitterAssignment.new()
	left_pin.player_id = 4
	left_pin.start_position = CourtConstants.slot_position(4)
	left_pin.lane = "Left Pin"
	left_pin.tempo = 2
	left_pin.priority = 1
	var quick := HitterAssignment.new()
	quick.player_id = 3
	quick.start_position = CourtConstants.slot_position(3)
	quick.lane = "Front Quick"
	quick.tempo = 0
	quick.priority = 2
	play.assignments.append(left_pin)
	play.assignments.append(quick)
	play.primary_hitter_id = 4
	play.secondary_hitter_id = 3
	return play


func _test_play_validation_and_serialization() -> void:
	var play := _make_play()
	_check(
		PlayValidator.validate(play, _make_lineup()).is_empty(),
		"a legal two-option play validates",
	)
	var restored := OffensivePlay.from_dict(play.to_dict())
	_check(restored.assignments.size() == 2, "play assignments survive serialization")
	_check(restored.assignment_for_player(3).tempo == 0, "set tempo survives serialization")
	restored.assignments[1].lane = "Unknown"
	_check(
		not PlayValidator.validate(restored, _make_lineup()).is_empty(),
		"unknown lanes are rejected",
	)


func _test_back_row_lane_restriction() -> void:
	var play := _make_play()
	var back_row := HitterAssignment.new()
	back_row.player_id = 5
	back_row.start_position = CourtConstants.slot_position(5)
	back_row.lane = "Right Pin"
	back_row.tempo = 2
	back_row.priority = 3
	play.assignments.append(back_row)
	_check(
		not PlayValidator.validate(play, _make_lineup()).is_empty(),
		"back-row hitters cannot use a front-row lane",
	)
	back_row.lane = "Pipe"
	_check(
		PlayValidator.validate(play, _make_lineup()).is_empty(),
		"back-row hitters can use the Pipe lane",
	)


func _test_tactical_demand() -> void:
	var hitter := VolleyballPlayer.new()
	hitter.id = 4
	hitter.approach_timing = 55
	hitter.transition_speed = 55
	var setter := VolleyballPlayer.new()
	setter.id = 1
	setter.set_accuracy = 58
	var assignment := HitterAssignment.new()
	assignment.player_id = hitter.id
	assignment.start_position = CourtConstants.slot_position(4)
	assignment.lane = "Right Pin"
	assignment.tempo = 0
	var demand := TacticalDemand.evaluate(hitter, assignment, setter)
	_check(demand["technical"] in ["Low", "Moderate", "High"], "technical demand is banded")
	_check(not str(demand["risk"]).is_empty(), "demand preview identifies a primary risk")


func _test_manager_playbook_and_serialization() -> void:
	var manager := GAME_MANAGER_SCRIPT.new()
	manager.seed_vertical_slice_data()
	var play := _make_play()
	var result := manager.save_offensive_play(play)
	_check(result.get("success", false), "manager saves a valid offensive play")
	var saved_play := result.get("play") as OffensivePlay
	_check(manager.call_play(saved_play.id).is_empty(), "saved play can be called")
	var restored_manager := GAME_MANAGER_SCRIPT.new()
	restored_manager.from_dict(manager.to_dict())
	_check(restored_manager.saved_plays.size() == 1, "manager playbook survives serialization")
	_check(restored_manager.called_play() != null, "called play survives serialization")


func _test_seeded_rally_resolution() -> void:
	var manager := GAME_MANAGER_SCRIPT.new()
	manager.seed_vertical_slice_data()
	var play := _make_play()
	var save_result := manager.save_offensive_play(play)
	var saved_play := save_result.get("play") as OffensivePlay
	manager.call_play(saved_play.id)
	var first: Resource = manager.resolve_active_rally(90210)
	var second: Resource = manager.resolve_active_rally(90210)
	_check(first.events.size() >= 2, "rally resolution produces discrete events")
	_check(
		first.events[0].event_type == RALLY_EVENT_SCRIPT.EventType.SERVE,
		"rally begins with serve resolution",
	)
	_check(
		first.events[-1].event_type == RALLY_EVENT_SCRIPT.EventType.POINT,
		"rally ends with a point event",
	)
	_check(
		first.terminal_outcome == second.terminal_outcome,
		"identical rally seeds produce identical outcomes",
	)
	_check(not first.explanation.is_empty(), "rally result includes an explanation")


func _test_match_scoring_and_rotation() -> void:
	var manager := GAME_MANAGER_SCRIPT.new()
	manager.seed_vertical_slice_data()
	var result: Resource = preload("res://scripts/models/rally_result.gd").new()
	result.home_team_won = true
	result.terminal_outcome = "kill"
	result.explanation = "Test point."
	var update: Dictionary = manager.record_rally(result)
	_check(manager.match_state.home_score == 1, "home rally increments match score")
	_check(bool(update.get("rotated", false)), "side-out rotates the home lineup")
	_check(manager.selected_rotation == 2, "manager selects the rotated lineup")
	var restored := GAME_MANAGER_SCRIPT.new()
	restored.from_dict(manager.to_dict())
	_check(restored.match_state.home_score == 1, "match score survives serialization")
	_check(restored.match_state.rally_history.size() == 1, "rally history survives serialization")


func _test_defense_opponent_and_match_day_controls() -> void:
	var manager := GAME_MANAGER_SCRIPT.new()
	manager.seed_vertical_slice_data()
	_check(manager.opponent_team.players.size() == 6, "opponent has an actual six-player profile")
	_check(
		not manager.opponent_team.scouting_summary().is_empty(),
		"opponent exposes a scouting summary",
	)
	manager.set_defender_position(6, Vector2(0.25, 0.82))
	_check(
		manager.current_defensive_plan().defender_position(6, Vector2.ZERO) \
			== Vector2(0.25, 0.82),
		"defensive positions are editable per rotation",
	)
	var assignment: Resource = manager.current_defensive_plan().assignment_for(6)
	_check(assignment != null, "every defender receives an explicit responsibility")
	_check(
		not str(assignment.short_ball_responsibility).is_empty(),
		"defensive responsibility includes short-ball coverage",
	)
	assignment.attack_coverage_responsibility = "Take second contact"
	assignment.second_contact_responsibility = "Primary emergency setter"
	manager.current_defensive_plan().set_assignment(6, assignment)
	manager.set_coverage_zone(
		6, DefensiveZone.ZoneType.SERVE_RECEIVE, 2.4, 3, false
	)
	manager.set_coverage_zone_center(
		6, DefensiveZone.ZoneType.SERVE_RECEIVE, Vector2(0.44, 0.78)
	)
	var observed_result: Resource = preload("res://scripts/models/rally_result.gd").new()
	var observed_attack: Resource = RALLY_EVENT_SCRIPT.new()
	observed_attack.event_type = RALLY_EVENT_SCRIPT.EventType.ATTACK
	observed_attack.metadata = {
		"side": "home", "lane": "Left Pin", "tempo": 2,
	}
	observed_result.events.append(observed_attack)
	manager.opponent_team.observe_rally(observed_result)
	_check(
		manager.opponent_team.anticipated_lane() == "Left Pin",
		"opponent adaptation learns the observed attack lane",
	)
	_check(
		manager.opponent_team.adaptation_strength > 0.0,
		"opponent adaptation rises at the exposed tuning rate",
	)
	_check(manager.call_timeout().is_empty(), "a match timeout can be called")
	_check(manager.match_state.home_timeouts_remaining == 1, "timeout inventory decreases")
	_check(
		manager.substitute_current_rotation(3, 8).is_empty(),
		"a reserve can replace an on-court player across rotation sheets",
	)
	_check(manager.current_lineup().slot_for_player(8) >= 0, "substitution changes the lineup")
	var outgoing_still_present := false
	for rotation_number in range(1, 7):
		if (manager.rotations[rotation_number] as RotationLineup).slot_for_player(3) >= 0:
			outgoing_still_present = true
	_check(not outgoing_still_present, "regular substitution updates every applicable rotation")
	_check(manager.undo_last_substitution().is_empty(), "the last substitution can be undone")
	_check(manager.current_lineup().slot_for_player(3) >= 0, "undo restores the lineup")
	var restored := GAME_MANAGER_SCRIPT.new()
	restored.from_dict(manager.to_dict())
	_check(
		restored.current_defensive_plan().defender_position(6, Vector2.ZERO) \
			== Vector2(0.25, 0.82),
		"defensive plan survives serialization",
	)
	_check(
		restored.current_defensive_plan().assignment_for(6) != null,
		"defensive responsibilities survive serialization",
	)
	_check(
		restored.opponent_team.anticipated_lane() == "Left Pin",
		"opponent adaptation survives serialization",
	)
	_check(
		restored.current_defensive_plan().floor_defense_zones.size() >= 6,
		"floor-defense zones survive serialization",
	)
	_check(
		restored.current_defensive_plan().reception_zones.size() >= 6,
		"serve-reception zones survive serialization",
	)
	var restored_zone: Resource = restored.current_defensive_plan().zone_for(
		6, DefensiveZone.ZoneType.SERVE_RECEIVE
	)
	_check(
		restored_zone != null and not bool(restored_zone.enabled)
			and int(restored_zone.priority) == 3
			and is_equal_approx(float(restored_zone.radius_meters), 2.4)
			and Vector2(restored_zone.center).is_equal_approx(Vector2(0.44, 0.78)),
		"editable reception radius, priority, visibility and center survive serialization",
	)
	_check(
		str(restored.current_defensive_plan().assignment_for(
			6
		).attack_coverage_responsibility) == "Take second contact",
		"attack-coverage responsibility survives serialization",
	)
	_check(
		str(restored.current_defensive_plan().assignment_for(
			6
		).second_contact_responsibility) == "Primary emergency setter",
		"second-contact responsibility survives serialization",
	)


func _test_coverage_arrival_and_reception_ownership() -> void:
	var player := VolleyballPlayer.new()
	player.id = 900
	player.lateral_speed = 75
	player.acceleration = 75
	player.anticipation = 75
	player.ball_control = 75
	player.reception = 75
	var zone := DefensiveZone.new()
	zone.player_id = player.id
	zone.center = Vector2(0.20, 0.84)
	zone.radius_meters = 3.0
	zone.priority = 2
	var reachable: Dictionary = CoverageCalculator.evaluate_arrival(
		player, zone, Vector2(0.35, 0.84), 1.0, "reception"
	)
	var unreachable: Dictionary = CoverageCalculator.evaluate_arrival(
		player, zone, Vector2(0.70, 0.84), 0.35, "reception"
	)
	_check(bool(reachable.get("reachable", false)), "adequate ball time permits a reachable contact")
	_check(not bool(unreachable.get("reachable", true)), "short ball time can make a zone unreachable")
	var manager := GAME_MANAGER_SCRIPT.new()
	manager.seed_vertical_slice_data()
	var non_libero_received := false
	var reception_has_arrival_data := false
	for seed_value in range(2000, 2025):
		var result: Resource = manager.resolve_active_rally(seed_value)
		for event_resource in result.events:
			var event: Resource = event_resource
			if event.event_type != RALLY_EVENT_SCRIPT.EventType.RECEPTION \
					or str(event.metadata.get("side", "")) != "home":
				continue
			if event.actor_id != 6:
				non_libero_received = true
			reception_has_arrival_data = event.metadata.has("arrival")
	_check(non_libero_received, "serve placement allows a non-libero passer to own reception")
	_check(reception_has_arrival_data, "reception events expose physical arrival data")
	var seam_partner := VolleyballPlayer.new()
	seam_partner.id = 901
	seam_partner.lateral_speed = 75
	seam_partner.acceleration = 75
	seam_partner.anticipation = 75
	seam_partner.ball_control = 75
	seam_partner.reception = 75
	var seam_zone := DefensiveZone.new()
	seam_zone.player_id = seam_partner.id
	seam_zone.center = zone.center
	seam_zone.radius_meters = zone.radius_meters
	seam_zone.priority = zone.priority
	var seam_players: Array[VolleyballPlayer] = [player, seam_partner]
	var seam_zones := {player.id: zone, seam_partner.id: seam_zone}
	var seam_claim: Dictionary = CoverageCalculator.choose_claimant(
		seam_players, seam_zones, Vector2(0.25, 0.84), 1.0, "reception"
	)
	_check(bool(seam_claim.seam_conflict), "equal-priority overlap creates a reception seam conflict")
	seam_zone.priority = 3
	var clear_claim: Dictionary = CoverageCalculator.choose_claimant(
		seam_players, seam_zones, Vector2(0.25, 0.84), 1.0, "reception"
	)
	_check(not bool(clear_claim.seam_conflict), "explicit claim priority resolves a reception seam")


func _test_second_contact_ownership() -> void:
	var manager := GAME_MANAGER_SCRIPT.new()
	manager.seed_vertical_slice_data()
	manager.match_state.serving_home = false
	var lineup := manager.current_lineup()
	var plan: Resource = manager.current_defensive_plan()
	var setter_id := int(lineup.setter_id)
	var emergency_setter_id := -1
	for slot_number in range(1, 7):
		var player_id := int(lineup.player_at_slot(slot_number))
		var zone: Resource = plan.zone_for(
			player_id, DefensiveZone.ZoneType.SERVE_RECEIVE
		)
		zone.enabled = player_id == setter_id
		if player_id == setter_id:
			zone.center = Vector2(0.50, 0.82)
			zone.radius_meters = 6.0
			zone.priority = 3
		else:
			var assignment: Resource = plan.assignment_for(player_id)
			assignment.second_contact_responsibility = "No second-contact duty"
			if emergency_setter_id < 0:
				emergency_setter_id = player_id
				assignment.second_contact_responsibility = "Primary emergency setter"
			plan.set_assignment(player_id, assignment)
	var emergency_assignment_observed := false
	for seed_value in range(8100, 8300):
		var result: Resource = manager.resolve_active_rally(seed_value)
		for event_resource in result.events:
			var event: Resource = event_resource
			if event.event_type == RALLY_EVENT_SCRIPT.EventType.SET \
					and bool(event.metadata.get("emergency_setter", false)):
				emergency_assignment_observed = event.actor_id == emergency_setter_id
				break
		if emergency_assignment_observed:
			break
	_check(
		emergency_assignment_observed,
		"the designated emergency setter takes second contact after the setter receives",
	)


func _test_block_closing_and_touch_distribution() -> void:
	var manager := GAME_MANAGER_SCRIPT.new()
	manager.seed_vertical_slice_data()
	manager.match_state.serving_home = true
	var home_block_events := 0
	var stuff_blocks := 0
	var touches_and_funnels := 0
	var non_middle_primary := false
	var block_deflection_observed := false
	var attack_coverage_observed := false
	for seed_value in range(5000, 5300):
		var result: Resource = manager.resolve_active_rally(seed_value)
		for event_resource in result.events:
			var event: Resource = event_resource
			if event.event_type == RALLY_EVENT_SCRIPT.EventType.DEFENSE \
					and str(event.metadata.get("coverage", "")) == "attack":
				attack_coverage_observed = true
			if event.event_type != RALLY_EVENT_SCRIPT.EventType.BLOCK \
					or str(event.metadata.get("side", "")) != "home":
				continue
			home_block_events += 1
			var outcome := str(event.metadata.get("outcome", "miss"))
			if outcome == "stuff":
				stuff_blocks += 1
			elif outcome in ["touch", "funnel"]:
				touches_and_funnels += 1
				block_deflection_observed = event.metadata.has("deflection_target")
			var blocker := manager.player_by_id(event.actor_id)
			if blocker != null and blocker.position_role != "Middle Blocker":
				non_middle_primary = true
	manager.match_state.serving_home = false
	for seed_value in range(5300, 5600):
		var result: Resource = manager.resolve_active_rally(seed_value)
		for event_resource in result.events:
			var event: Resource = event_resource
			if event.event_type == RALLY_EVENT_SCRIPT.EventType.DEFENSE \
					and str(event.metadata.get("coverage", "")) == "attack":
				attack_coverage_observed = true
	_check(home_block_events > 20, "block distribution test observes enough home contests")
	_check(non_middle_primary, "nearest pin players can lead blocks instead of the middle")
	_check(
		touches_and_funnels > stuff_blocks,
		"partial block outcomes occur more often than terminal stuff blocks",
	)
	_check(
		float(stuff_blocks) / maxf(float(home_block_events), 1.0) < 0.22,
		"home stuff-block rate remains below the prototype balance ceiling",
	)
	_check(block_deflection_observed, "partial home blocks expose a changed deflection target")
	_check(attack_coverage_observed, "opponent block touches can trigger explicit attack coverage")


func _test_physical_body_attributes() -> void:
	var player := VolleyballPlayer.new()
	player.position_role = "Middle Blocker"
	player.apply_role_physical_defaults()
	player.height_cm = 207.0
	player.mass_kg = 101.0
	player.wingspan_cm = 216.0
	player.explosiveness = 89
	player.reception_balance = 43
	player.reception_stability = 61
	var restored := VolleyballPlayer.from_dict(player.to_dict())
	_check(is_equal_approx(restored.height_cm, 207.0), "height survives player serialization")
	_check(is_equal_approx(restored.mass_kg, 101.0), "mass survives player serialization")
	_check(restored.explosiveness == 89, "explosiveness survives player serialization")
	_check(
		restored.reception_balance == 43 and restored.reception_stability == 61,
		"reception balance and stability survive player serialization",
	)
	var zone := DefensiveZone.new()
	zone.center = Vector2(0.20, 0.84)
	zone.radius_meters = 4.0
	var short_span := VolleyballPlayer.new()
	short_span.wingspan_cm = 165.0
	var long_span := VolleyballPlayer.new()
	long_span.wingspan_cm = 220.0
	var short_arrival: Dictionary = CoverageCalculator.evaluate_arrival(
		short_span, zone, Vector2(0.30, 0.84), 0.8, "reception"
	)
	var long_arrival: Dictionary = CoverageCalculator.evaluate_arrival(
		long_span, zone, Vector2(0.30, 0.84), 0.8, "reception"
	)
	_check(
		float(long_arrival.physical_reach_meters) > float(short_arrival.physical_reach_meters),
		"longer wingspan increases physical defensive reach",
	)
	var light_player := VolleyballPlayer.new()
	light_player.mass_kg = 60.0
	var heavy_player := VolleyballPlayer.new()
	heavy_player.mass_kg = 120.0
	var light_arrival: Dictionary = CoverageCalculator.evaluate_arrival(
		light_player, zone, Vector2(0.38, 0.84), 1.0, "reception"
	)
	var heavy_arrival: Dictionary = CoverageCalculator.evaluate_arrival(
		heavy_player, zone, Vector2(0.38, 0.84), 1.0, "reception"
	)
	_check(
		float(light_arrival.physical_reach_meters) > float(heavy_arrival.physical_reach_meters),
		"greater mass slightly reduces movement-derived coverage",
	)
	var unstable := VolleyballPlayer.new()
	unstable.reception_balance = 20
	unstable.reception_stability = 20
	var stable := VolleyballPlayer.new()
	stable.reception_balance = 90
	stable.reception_stability = 90
	var edge_arrival := {"edge_ratio": 0.92}
	_check(
		CoverageCalculator.reception_body_penalty(
			stable, edge_arrival, 0.90
		) < CoverageCalculator.reception_body_penalty(
			unstable, edge_arrival, 0.90
		),
		"balance and stability reduce edge-and-pace reception penalties",
	)


func _test_tactical_playback_reset_on_lineup_change() -> void:
	var manager := GAME_MANAGER_SCRIPT.new()
	manager.seed_vertical_slice_data()
	var court := TacticalCourt.new()
	court.set_lineup(manager.rotations[1], manager.players)
	court.live_player_positions[1] = Vector2(0.12, 0.62)
	court.movement_trails[1] = [Vector2(0.12, 0.62), Vector2(0.40, 0.70)]
	court.playback_event = RALLY_EVENT_SCRIPT.new()
	court.set_lineup(manager.rotations[2], manager.players)
	_check(court.live_player_positions.is_empty(), "lineup changes clear live marker positions")
	_check(court.movement_trails.is_empty(), "lineup changes clear rally movement trails")
	_check(court.playback_event == null, "lineup changes clear the previous rally event")
	court.free()


func _test_default_offense_without_saved_play() -> void:
	var manager := GAME_MANAGER_SCRIPT.new()
	manager.seed_vertical_slice_data()
	var result: Resource = manager.resolve_active_rally(4411)
	_check(result != null, "a rally resolves without a saved offensive play")
	_check(
		result.active_play_name == "Default T3 Outside",
		"no-play rallies use the named default outside offense",
	)
	for rotation_number in range(1, 7):
		var lineup := manager.rotations[rotation_number] as RotationLineup
		var libero_slot := lineup.slot_for_player(6)
		_check(
			libero_slot in [1, 5, 6],
			"rotation %d keeps the libero in the back row" % rotation_number,
		)
	var continuation_seen := false
	var safety_limit_respected := true
	for seed_value in range(1, 80):
		var seeded_result: Resource = manager.resolve_active_rally(seed_value)
		if seeded_result.events.size() > 32:
			safety_limit_respected = false
		if seeded_result.events.size() >= 12:
			continuation_seen = true
			break
	_check(safety_limit_respected, "bounded rally loop respects its event safety limit")
	_check(continuation_seen, "seeded simulation produces multi-exchange rallies")
