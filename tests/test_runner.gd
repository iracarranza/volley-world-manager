extends SceneTree

const GAME_MANAGER_SCRIPT := preload("res://scripts/managers/game_manager.gd")
const RALLY_EVENT_SCRIPT := preload("res://scripts/models/rally_event.gd")
const ROTATION_LEGALITY_SCRIPT := preload("res://scripts/simulation/rotation_legality.gd")
const BALL_TRAJECTORY_SCRIPT := preload("res://scripts/models/ball_trajectory.gd")

var checks: int = 0
var failures: int = 0


func _initialize() -> void:
	_test_court_coordinates()
	_test_rotation_legality()
	_test_serve_receive_overlap_bounds()
	_test_ball_trajectory_geometry()
	_test_play_validation_and_serialization()
	_test_back_row_lane_restriction()
	_test_tactical_demand()
	_test_manager_playbook_and_serialization()
	_test_seeded_rally_resolution()
	_test_match_scoring_and_rotation()
	_test_defense_opponent_and_match_day_controls()
	_test_coverage_arrival_and_reception_ownership()
	_test_second_contact_ownership()
	_test_spatial_timing_and_tactical_positions()
	_test_block_closing_and_touch_distribution()
	_test_physical_body_attributes()
	_test_tactical_playback_reset_on_lineup_change()
	_test_default_offense_without_saved_play()
	_test_defensive_presets_release_and_setting_systems()
	_test_spatial_opponent_and_replay_analysis()
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


func _test_spatial_opponent_and_replay_analysis() -> void:
	var manager := GAME_MANAGER_SCRIPT.new()
	manager.seed_vertical_slice_data()
	manager.match_state.serving_home = true
	var opponent_hitter_ids := {}
	var direction_observed := false
	var spatial_defense_observed := false
	var graded_set_observed := false
	var blocker_read_observed := false
	var analysis_observed := false
	for seed_value in range(7600, 7720):
		manager.match_state.serving_home = seed_value % 2 == 0
		var result: Resource = manager.resolve_active_rally(seed_value)
		analysis_observed = analysis_observed or (
			result.analysis.has("attack_types")
			and result.analysis.has("lowest_arrival_margin")
		)
		for event_resource in result.events:
			var event: Resource = event_resource
			if event.event_type == RALLY_EVENT_SCRIPT.EventType.SET \
					and str(event.metadata.get("side", "")) == "opponent":
				graded_set_observed = graded_set_observed or (
					event.metadata.has("set_distance_meters")
					and event.metadata.has("body_orientation_fit")
				)
			elif event.event_type == RALLY_EVENT_SCRIPT.EventType.ATTACK \
					and str(event.metadata.get("side", "")) == "opponent":
				opponent_hitter_ids[event.actor_id] = true
				direction_observed = direction_observed or event.metadata.has("attack_direction")
			elif event.event_type == RALLY_EVENT_SCRIPT.EventType.DEFENSE \
					and str(event.metadata.get("side", "")) == "opponent":
				spatial_defense_observed = spatial_defense_observed or (
					event.metadata.has("movement_start")
					and event.metadata.has("arrival_margin")
				)
			elif event.event_type == RALLY_EVENT_SCRIPT.EventType.BLOCK \
					and str(event.metadata.get("side", "")) == "home":
				blocker_read_observed = blocker_read_observed or event.metadata.has("read_quality")
	_check(opponent_hitter_ids.size() >= 2, "opponent transition uses multiple eligible hitters")
	_check(direction_observed, "attacks expose line, seam, cross-court, or short direction")
	_check(spatial_defense_observed, "opponent floor defense records travel and arrival")
	_check(graded_set_observed, "opponent setting exposes target-specific geometry")
	_check(blocker_read_observed, "home block records attribute-driven read quality")
	_check(analysis_observed, "completed rallies expose concise replay analysis")


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


func _test_ball_trajectory_geometry() -> void:
	var trajectory: Resource = BALL_TRAJECTORY_SCRIPT.create(
		"test", Vector2(0.1, 0.2), Vector2(0.5, 0.1),
		Vector2(0.9, 0.8), 2.0, 0.8, 2.4
	)
	_check(
		Vector2(trajectory.position_at(0.0)).is_equal_approx(Vector2(0.1, 0.2))
			and Vector2(trajectory.position_at(1.0)).is_equal_approx(Vector2(0.9, 0.8)),
		"ball trajectory preserves exact contact endpoints",
	)
	_check(
		is_equal_approx(float(trajectory.duration()), 0.8)
			and is_equal_approx(float(trajectory.apex_height_meters), 2.4),
		"ball trajectory preserves timing and apex height",
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
	var reception_has_platform_data := false
	var setter_chased_actual_pass := false
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
			reception_has_platform_data = reception_has_platform_data or ( \
				event.metadata.has("body_alignment") \
				and event.metadata.has("platform_feasibility") \
				and event.metadata.has("outgoing_trajectory")
			)
			var actual_target: Vector2 = event.metadata.get(
				"actual_pass_target", Vector2.ZERO
			)
			for follow_event_resource in result.events:
				var follow_event: Resource = follow_event_resource
				if follow_event.event_type == RALLY_EVENT_SCRIPT.EventType.SET:
					setter_chased_actual_pass = setter_chased_actual_pass or Vector2(
						follow_event.start_position
					).is_equal_approx(actual_target)
					break
	_check(non_libero_received, "serve placement allows a non-libero passer to own reception")
	_check(reception_has_arrival_data, "reception events expose physical arrival data")
	_check(reception_has_platform_data, "reception exposes posture, platform and pass trajectory")
	_check(setter_chased_actual_pass, "setter contact follows the generated reception destination")
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


func _test_spatial_timing_and_tactical_positions() -> void:
	var baseline := GAME_MANAGER_SCRIPT.new()
	var displaced := GAME_MANAGER_SCRIPT.new()
	baseline.seed_vertical_slice_data()
	displaced.seed_vertical_slice_data()
	baseline.match_state.serving_home = false
	displaced.match_state.serving_home = false
	var play := OffensivePlay.new()
	play.play_name = "Spatial Right Pin"
	play.rotation_number = 1
	var outside := HitterAssignment.new()
	outside.player_id = 2
	outside.start_position = CourtConstants.slot_position(2)
	outside.lane = "Right Pin"
	outside.tempo = 2
	outside.priority = 1
	var middle := HitterAssignment.new()
	middle.player_id = 3
	middle.start_position = CourtConstants.slot_position(3)
	middle.lane = "Front Quick"
	middle.tempo = 1
	middle.priority = 2
	play.assignments = [outside, middle]
	play.primary_hitter_id = 2
	play.secondary_hitter_id = 3
	_check(bool(baseline.save_offensive_play(play).success), "baseline spatial play saves")
	_check(bool(displaced.save_offensive_play(play).success), "displaced spatial play saves")
	var displaced_plan: Resource = displaced.current_defensive_plan()
	var hitter_zone: Resource = displaced_plan.zone_for(
		2, DefensiveZone.ZoneType.SERVE_RECEIVE
	)
	hitter_zone.center = Vector2(0.08, 0.94)
	var setter_zone: Resource = displaced_plan.zone_for(
		1, DefensiveZone.ZoneType.SERVE_RECEIVE
	)
	setter_zone.center = Vector2(0.08, 0.94)
	setter_zone.enabled = false
	var baseline_setter_zone: Resource = baseline.current_defensive_plan().zone_for(
		1, DefensiveZone.ZoneType.SERVE_RECEIVE
	)
	baseline_setter_zone.enabled = false
	var position_effect_observed := false
	var speed_effect_observed := false
	var timeline_observed := false
	for seed_value in range(9100, 9500):
		var base_result: Resource = baseline.resolve_active_rally(seed_value)
		var moved_result: Resource = displaced.resolve_active_rally(seed_value)
		var base_attack: Resource
		var moved_attack: Resource
		for event_resource in base_result.events:
			var event: Resource = event_resource
			if event.event_type == RALLY_EVENT_SCRIPT.EventType.ATTACK \
					and event.actor_id == 2:
				base_attack = event
				break
		for event_resource in moved_result.events:
			var event: Resource = event_resource
			if event.event_type == RALLY_EVENT_SCRIPT.EventType.ATTACK \
					and event.actor_id == 2:
				moved_attack = event
				break
		if base_attack != null and moved_attack != null:
			position_effect_observed = (
				float(moved_attack.metadata.get("arrival_margin", 0.0))
				< float(base_attack.metadata.get("arrival_margin", 0.0)) - 0.60
				and float(moved_attack.quality) < float(base_attack.quality)
			)
			var original_speed := displaced.player_by_id(2).transition_speed
			displaced.player_by_id(2).transition_speed = 98
			var fast_result: Resource = displaced.resolve_active_rally(seed_value)
			displaced.player_by_id(2).transition_speed = original_speed
			for event_resource in fast_result.events:
				var fast_event: Resource = event_resource
				if fast_event.event_type == RALLY_EVENT_SCRIPT.EventType.ATTACK \
						and fast_event.actor_id == 2:
					speed_effect_observed = float(fast_event.metadata.get(
						"movement_duration", 99.0
					)) < float(moved_attack.metadata.get("movement_duration", 0.0))
					break
		var previous_time := -1.0
		timeline_observed = true
		for event_resource in base_result.events:
			var event: Resource = event_resource
			var event_time := float(event.metadata.get("event_time", -1.0))
			if event_time < previous_time or not event.metadata.has("event_duration"):
				timeline_observed = false
				break
			previous_time = event_time
		if position_effect_observed and speed_effect_observed and timeline_observed:
			break
	_check(position_effect_observed, "extreme hitter displacement reduces arrival and attack quality")
	_check(speed_effect_observed, "transition speed changes calculated marker travel time")
	_check(timeline_observed, "rally events expose a monotonic shared clock and duration")


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
	var block_segments_observed := false
	var opponent_setter_pull_observed := false
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
			opponent_setter_pull_observed = opponent_setter_pull_observed or (
				event.metadata.has("opponent_setter_position")
				and not Dictionary(event.metadata.get("setter_pull", {})).is_empty()
			)
			block_segments_observed = block_segments_observed or not Array(
				event.metadata.get("coverage_segments", [])
			).is_empty()
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
	_check(block_segments_observed, "block events expose spatial net-coverage segments")
	_check(
		opponent_setter_pull_observed,
		"opponent setter position creates discipline-weighted blocker pull metadata",
	)


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
	player.set_balance = 67
	player.set_stability = 73
	var restored := VolleyballPlayer.from_dict(player.to_dict())
	_check(is_equal_approx(restored.height_cm, 207.0), "height survives player serialization")
	_check(is_equal_approx(restored.mass_kg, 101.0), "mass survives player serialization")
	_check(restored.explosiveness == 89, "explosiveness survives player serialization")
	_check(
		restored.reception_balance == 43 and restored.reception_stability == 61,
		"reception balance and stability survive player serialization",
	)
	_check(
		restored.set_balance == 67 and restored.set_stability == 73,
		"setting balance and stability survive player serialization",
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


func _test_defensive_presets_release_and_setting_systems() -> void:
	var manager := GAME_MANAGER_SCRIPT.new()
	manager.seed_vertical_slice_data()
	var lineup := manager.current_lineup()
	_check(lineup.active_setter_id() == 1, "a 5-1 retains its single active setter")
	var setting_error := manager.configure_setting_system("6-2", 4)
	_check(setting_error.is_empty(), "opposite-row designated setters create a valid 6-2")
	lineup = manager.current_lineup()
	var active_setter := lineup.active_setter_id()
	_check(
		active_setter in [1, 4]
			and not CourtConstants.is_front_row_slot(lineup.slot_for_player(active_setter)),
		"the back-row designated setter owns second contact in a 6-2",
	)
	var front_setter := 4 if active_setter == 1 else 1
	_check(lineup.is_attack_eligible(front_setter), "the front-row 6-2 setter may attack")
	_check(not lineup.is_attack_eligible(active_setter), "the active setter may not attack")
	var plan: Resource = manager.current_defensive_plan()
	plan.apply_floor_preset("Middle-Up", lineup)
	var middle_back_id := lineup.player_at_slot(6)
	_check(
		float(plan.defender_position(middle_back_id, Vector2.ZERO).y) < 0.80,
		"Middle-Up applies a mechanically shallow middle-back position",
	)
	plan.set_setter_release_target(active_setter, Vector2(0.64, 0.59))
	var restored_plan := DefensivePlan.new()
	restored_plan.load_dict(plan.to_dict())
	_check(
		restored_plan.setter_release_target(active_setter).is_equal_approx(Vector2(0.64, 0.59)),
		"setter release targets survive serialization",
	)
	var geometry_seen := false
	for seed_value in range(200, 240):
		var result: Resource = manager.resolve_active_rally(seed_value)
		for event_resource in result.events:
			var event: Resource = event_resource
			if int(event.event_type) == RallyEvent.EventType.SET \
					and str(event.metadata.get("side", "")) == "home":
				geometry_seen = event.metadata.has("set_distance_meters") \
					and event.metadata.has("set_angle_degrees") \
					and event.metadata.has("body_orientation_fit")
				break
		if geometry_seen:
			break
	_check(geometry_seen, "home sets expose distance, angle and body-orientation geometry")
