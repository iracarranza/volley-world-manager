extends SceneTree

const GAME_MANAGER_SCRIPT := preload("res://scripts/managers/game_manager.gd")
const RALLY_EVENT_SCRIPT := preload("res://scripts/models/rally_event.gd")
const ROTATION_LEGALITY_SCRIPT := preload("res://scripts/simulation/rotation_legality.gd")
const BALL_TRAJECTORY_SCRIPT := preload("res://scripts/models/ball_trajectory.gd")
const TACTICAL_COURT_SCRIPT := preload("res://scenes/components/tactical_court.gd")
const CAREER_MANAGER_SCRIPT := preload("res://scripts/managers/career_manager.gd")
const PLAYER_GENERATOR_SCRIPT := preload("res://scripts/systems/player_generator.gd")
const TRAINING_SYSTEM_SCRIPT := preload("res://scripts/systems/training_system.gd")
const CALENDAR_RULES_SCRIPT := preload("res://scripts/data/calendar_rules.gd")
const MATCH_FORMAT_SCRIPT := preload("res://scripts/models/match_format.gd")
const REGIONS_SCRIPT := preload("res://scripts/data/regions.gd")
const ATTRIBUTE_PROFILE_SCRIPT := preload("res://scripts/systems/attribute_profile_system.gd")
const FAMILIARITY_SCRIPT := preload("res://scripts/systems/familiarity_system.gd")
const RALLY_PLAYER_STATE_SCRIPT := preload("res://scripts/models/rally_player_state.gd")
const RALLY_MOMENT_SCRIPT := preload("res://scripts/models/rally_moment.gd")
const RALLY_STATE_BUILDER_SCRIPT := preload("res://scripts/simulation/rally_state_builder.gd")
const RALLY_SCHEDULER_SCRIPT := preload("res://scripts/simulation/rally_scheduler.gd")
const RALLY_MOVEMENT_SCRIPT := preload("res://scripts/simulation/rally_movement_system.gd")
const CONTACT_ENVELOPE_SCRIPT := preload(
	"res://scripts/simulation/contact_envelope_system.gd"
)
const SETTER_FAILURE_CLASSIFIER_SCRIPT := preload(
	"res://scripts/simulation/setter_failure_classifier.gd"
)
const RECEPTION_ROLLOUT_AUDIT_SCRIPT := preload(
	"res://scripts/simulation/reception_rollout_audit.gd"
)
const RALLY_ROLLOUT_POLICY_SCRIPT := preload(
	"res://scripts/simulation/rally_rollout_policy.gd"
)
const BALL_CONTACT_SIGNATURE_SCRIPT := preload("res://scripts/models/ball_contact_signature.gd")
const BALL_FLIGHT_SCRIPT := preload("res://scripts/models/ball_flight.gd")
const BALL_READ_SCRIPT := preload("res://scripts/simulation/ball_read_system.gd")
const RALLY_KINEMATICS_SCRIPT := preload("res://scripts/simulation/rally_kinematics.gd")
const RALLY_CALIBRATION_REPORT_SCRIPT := preload("res://scripts/simulation/rally_calibration_report.gd")
const SERVE_STYLE_CALIBRATION_SCRIPT := preload("res://scripts/simulation/serve_style_calibration.gd")
const RECEPTION_PROGRESSION_CALIBRATION_SCRIPT := preload("res://scripts/simulation/reception_progression_calibration.gd")
const ACTION_OPPORTUNITY_WINDOW_SCRIPT := preload("res://scripts/models/action_opportunity_window.gd")
const RALLY_OPPORTUNITY_SCRIPT := preload("res://scripts/simulation/rally_opportunity_system.gd")
const RALLY_DECISION_SCRIPT := preload("res://scripts/simulation/rally_decision_system.gd")
const RECEPTION_DECISION_PROGRESSION_SCRIPT := preload("res://scripts/simulation/reception_decision_progression_calibration.gd")
const RALLY_CONTACT_SCRIPT := preload("res://scripts/simulation/rally_contact_system.gd")
const SHADOW_SETTER_RESPONSE_SCRIPT := preload(
	"res://scripts/simulation/shadow_setter_response_system.gd"
)
const SETTER_HANDOFF_CALIBRATION_SCRIPT := preload(
	"res://scripts/simulation/setter_handoff_calibration.gd"
)
const SETTER_PROGRESSION_CALIBRATION_SCRIPT := preload(
	"res://scripts/simulation/setter_progression_calibration.gd"
)
const PLAYER_OBSERVATION_SCRIPT := preload(
	"res://scripts/models/player_observation.gd"
)
const SETTER_ROLLOUT_AUDIT_SCRIPT := preload(
	"res://scripts/simulation/setter_rollout_audit.gd"
)
const ATTACK_ROLLOUT_AUDIT_SCRIPT := preload(
	"res://scripts/simulation/attack_rollout_audit.gd"
)
const ATTACK_PROGRESSION_CALIBRATION_SCRIPT := preload(
	"res://scripts/simulation/attack_progression_calibration.gd"
)

var checks: int = 0
var failures: int = 0


func _initialize() -> void:
	_test_court_coordinates()
	_test_rotation_legality()
	_test_serve_receive_overlap_bounds()
	_test_ball_trajectory_geometry()
	_test_rally_state_foundations()
	_test_ball_read_foundations()
	_test_rally_kinematics()
	_test_contact_envelopes_and_vertical_setting()
	_test_setter_failure_taxonomy()
	_test_shadow_reception_trace()
	_test_gate_one_calibration_batch()
	_test_gate_two_serve_style_fixtures()
	_test_gate_three_derived_speed()
	_test_gate_four_reader_and_formation_matrix()
	_test_gate_six_repeated_reads()
	_test_gate_seven_projected_movement()
	_test_gate_eight_opportunity_windows()
	_test_gate_nine_shadow_decisions()
	_test_gate_ten_decision_progression()
	_test_gate_eleven_outgoing_reception_flight()
	_test_gate_twelve_shadow_setter_response()
	_test_gate_thirteen_shadow_playback_adapter()
	_test_gate_fourteen_serve_to_set_comparison()
	_test_gate_fifteen_disabled_rollout()
	_test_gate_twenty_eight_and_twenty_nine_rollout_boundary()
	_test_gate_thirty_development_live_reception()
	_test_gate_thirty_one_to_thirty_five_setter_boundary()
	_test_gate_thirty_six_development_live_setter()
	_test_gate_thirty_seven_to_forty_one_attack_boundary()
	_test_gate_forty_two_development_live_attack()
	_test_gate_twenty_one_setter_handoffs()
	_test_gate_twenty_two_setter_progression()
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
	_test_match_court_opponent_layer()
	_test_team_roster_statistics_and_opponent_rotation()
	_test_career_calendar_generation_training_and_saves()
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


func _test_contact_envelopes_and_vertical_setting() -> void:
	var setter := VolleyballPlayer.new()
	setter.id = 901
	setter.position_role = "Setter"
	setter.height_cm = 188.0
	setter.wingspan_cm = 191.0
	setter.jump_reach = 88
	setter.explosiveness = 90
	setter.set_balance = 82
	setter.set_stability = 84
	setter.set_accuracy = 80
	setter.hand_control = 80
	var actor := RALLY_PLAYER_STATE_SCRIPT.create(
		setter, &"home", 2, Vector2(0.50, 0.60)
	)
	var standing := RALLY_MOVEMENT_SCRIPT.evaluate_opportunity(
		actor, &"set", actor.position, 0.50, 0.0, 1.0, 2.20, true
	)
	var jumping := RALLY_MOVEMENT_SCRIPT.evaluate_opportunity(
		actor, &"set", actor.position, 0.50, 0.0, 1.0, 2.65, true
	)
	_check(
		standing.standing_reachable and standing.jump_reachable
			and not standing.requires_jump,
		"A prepared setter can choose standing or jump access below standing reach",
	)
	_check(
		jumping.jump_reachable and jumping.requires_jump
			and jumping.maximum_contact_height_meters > jumping.standing_reach_meters
			and jumping.takeoff_time_seconds > 0.0
			and jumping.recovery_time_seconds > 0.0,
		"Jump setting extends vertical access while reserving takeoff and recovery time",
	)
	var unstable_setter := setter.duplicate(true) as VolleyballPlayer
	unstable_setter.id = 905
	unstable_setter.set_balance = 20
	unstable_setter.set_stability = 20
	unstable_setter.hand_control = 20
	var unstable_actor := RALLY_PLAYER_STATE_SCRIPT.create(
		unstable_setter, &"home", 2, actor.position
	)
	var unstable_set := RALLY_MOVEMENT_SCRIPT.evaluate_opportunity(
		unstable_actor, &"set", actor.position, 0.50, 0.0, 1.0, 2.20, true
	)
	_check(
		standing.expected_quality.x > unstable_set.expected_quality.x
			and standing.arrival_balance > unstable_set.arrival_balance,
		"Set balance, stability, and hand control improve execution after access",
	)
	var near_reach_target := actor.position + Vector2(
		(standing.contact_reach_meters + 0.03) / 9.0, 0.0
	)
	var reaching_set := RALLY_MOVEMENT_SCRIPT.evaluate_opportunity(
		actor, &"set", near_reach_target, 0.0, 0.0, 1.0, 2.20, false
	)
	_check(
		reaching_set.used_reaching_extension and reaching_set.reachable,
		"Gate 27 lets an otherwise prepared setter finish a narrow hand-access gap",
	)

	var low_explosive := setter.duplicate(true) as VolleyballPlayer
	low_explosive.id = 902
	low_explosive.explosiveness = 10
	low_explosive.jump_reach = 10
	var low_actor := RALLY_PLAYER_STATE_SCRIPT.create(
		low_explosive, &"home", 2, actor.position
	)
	var low_jump := RALLY_MOVEMENT_SCRIPT.evaluate_opportunity(
		low_actor, &"set", low_actor.position, 0.20, 0.0, 1.0, 2.65, true
	)
	var quick_jump := RALLY_MOVEMENT_SCRIPT.evaluate_opportunity(
		actor, &"set", actor.position, 0.20, 0.0, 1.0, 2.65, true
	)
	_check(
		quick_jump.jump_reachable and not low_jump.jump_reachable,
		"Explosiveness and jump reach determine whether a setter can access a fast high ball",
	)

	var short_span := setter.duplicate(true) as VolleyballPlayer
	short_span.id = 903
	short_span.wingspan_cm = 160.0
	var long_span := setter.duplicate(true) as VolleyballPlayer
	long_span.id = 904
	long_span.wingspan_cm = 225.0
	var short_actor := RALLY_PLAYER_STATE_SCRIPT.create(
		short_span, &"home", 2, Vector2(0.50, 0.60)
	)
	var long_actor := RALLY_PLAYER_STATE_SCRIPT.create(
		long_span, &"home", 2, Vector2(0.50, 0.60)
	)
	var short_reach: Dictionary = CONTACT_ENVELOPE_SCRIPT.evaluate(
		short_actor, &"set", 2.10, 0.50, false
	)
	var long_reach: Dictionary = CONTACT_ENVELOPE_SCRIPT.evaluate(
		long_actor, &"set", 2.10, 0.50, false
	)
	_check(
		float(long_reach.get("horizontal_reach_meters", 0.0))
			> float(short_reach.get("horizontal_reach_meters", 0.0))
			and float(long_reach.get("standing_reach_meters", 0.0))
				> float(short_reach.get("standing_reach_meters", 0.0)),
		"Wingspan changes both lateral contact access and derived standing reach",
	)

	var signature := BALL_CONTACT_SIGNATURE_SCRIPT.create(
		&"safe_center_pass", 5.5, 0.0, 34.0, 0.5, 0.0, 0.8
	)
	var flight := BALL_FLIGHT_SCRIPT.create(
		Vector2(0.3, 0.8), Vector2(0.5, 0.6), 0.0, 0.7,
		signature, 2.42
	)
	var estimate := BALL_READ_SCRIPT.estimate(
		flight, setter, 0.5, 0.2, 991
	)
	_check(
		is_equal_approx(float(flight.to_dict().get(
			"contact_height_meters", 0.0
		)), 2.42)
			and is_equal_approx(estimate.true_contact_height_meters, 2.42)
			and estimate.perceived_contact_height_meters > 0.0,
		"BallFlight carries authoritative contact height while readers form estimates",
	)


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


func _test_match_court_opponent_layer() -> void:
	var manager := GAME_MANAGER_SCRIPT.new()
	manager.seed_vertical_slice_data()
	var court := TACTICAL_COURT_SCRIPT.new()
	court.set_opponent_team(manager.opponent_team, true)
	_check(court.show_opponents, "Match Center court enables persistent opponent markers")
	_check(
		court.opponent_players_by_id.size() == 6,
		"opponent marker layer receives all six opponent players",
	)
	court.free()


func _test_team_roster_statistics_and_opponent_rotation() -> void:
	var manager := GAME_MANAGER_SCRIPT.new()
	manager.seed_vertical_slice_data()
	_check(manager.team.player_ids.size() == 8, "managed team owns its registered roster")
	_check(manager.team.captain_id == 1, "managed team stores a captain")
	_check(manager.team.libero_ids == [6], "managed team stores libero designations")
	_check(manager.match_roster_errors().is_empty(), "seeded lineup passes roster eligibility")
	_check(manager.set_team_captain(2).is_empty(), "captain can be changed through the manager")
	var reserve := VolleyballPlayer.new()
	reserve.id = 99
	reserve.display_name = "Test Reserve"
	_check(manager.register_player(reserve).is_empty(), "a new player can be registered")
	_check(manager.unregister_player(99).is_empty(), "an unused reserve can be unregistered")
	var unavailable_id := manager.current_lineup().player_at_slot(2)
	manager.player_by_id(unavailable_id).availability = "Injured"
	_check(not manager.match_roster_errors().is_empty(), "unavailable lineup players block match eligibility")
	manager.player_by_id(unavailable_id).availability = "Available"
	manager.match_state.serving_home = true
	var loss := RallyResult.new()
	loss.home_team_won = false
	loss.terminal_outcome = "opponent_kill"
	loss.explanation = "Test opponent point."
	var update: Dictionary = manager.record_rally(loss)
	_check(bool(update.get("opponent_rotated", false)), "opponent rotates on a side-out")
	_check(manager.opponent_team.current_rotation == 2, "opponent lineup follows match rotation")
	_check(int(manager.match_state.statistics.opponent.get("points", 0)) == 1,
		"match statistics record opponent points")
	var restored := GAME_MANAGER_SCRIPT.new()
	restored.from_dict(manager.to_dict())
	_check(restored.team.captain_id == 2, "team roles survive serialization")
	_check(restored.match_state.statistics.summary() == manager.match_state.statistics.summary(),
		"match statistics survive serialization")
	_check(restored.opponent_team.current_rotation == 2,
		"opponent rotation survives serialization")


func _test_career_calendar_generation_training_and_saves() -> void:
	var fictional_regions := REGIONS_SCRIPT.names()
	_check(fictional_regions.size() == 4 and "Landavol" in fictional_regions \
			and "Spëddigh" in fictional_regions and "Pāwa Hitō" in fictional_regions \
			and "Bloc du Larg" in fictional_regions,
		"career creation exposes only the four confirmed fictional regions")
	_check(REGIONS_SCRIPT.canonical_name("Europe") == "Landavol",
		"legacy real-world region saves migrate to a fictional setting")
	var second_year: Dictionary = CALENDAR_RULES_SCRIPT.state_for_week(49)
	_check(int(second_year.year) == 2 and int(second_year.week_of_year) == 1,
		"48-week calendar advances into a second career year")
	var club_roster: Array[VolleyballPlayer] = PLAYER_GENERATOR_SCRIPT.generate_roster(
		"Landavol", "Club", 4242
	)
	var repeated_roster: Array[VolleyballPlayer] = PLAYER_GENERATOR_SCRIPT.generate_roster(
		"Landavol", "Club", 4242
	)
	var academy_roster: Array[VolleyballPlayer] = PLAYER_GENERATOR_SCRIPT.generate_roster(
		"Landavol", "Academy", 4242
	)
	_check(club_roster.size() == 10 and academy_roster.size() == 12,
		"club and academy starts create distinct roster sizes")
	_check(PLAYER_GENERATOR_SCRIPT.generate_market("Landavol", 9898).size() == 120,
		"testing recruitment generates a 120-player variance pool")
	_check(club_roster[0].display_name == repeated_roster[0].display_name \
			and club_roster[0].set_accuracy == repeated_roster[0].set_accuracy,
		"regional roster generation is deterministic")
	_check(academy_roster[0].age <= 20 and academy_roster[0].potential >= 74,
		"academy generation produces young high-potential players")
	_check(not club_roster[0].current_ability_stars().is_empty() \
			and not club_roster[0].potential_ability_stars().is_empty(),
		"roster players expose current and potential star ratings")
	_check(club_roster[0].current_ability_score() >= 1 \
			and club_roster[0].current_ability_score() <= 100,
		"position-weighted current ability remains within the attribute scale")
	_check(club_roster[0].serve_style_proficiencies.size() == 5 \
			and club_roster[0].primary_serve_style in club_roster[0].serve_style_proficiencies,
		"generated players receive a five-style serving repertoire and primary style")
	_check(club_roster[0].dominant_hand in ["Right", "Left"] \
			and club_roster[0].natural_positions.has(club_roster[0].primary_position),
		"generated players receive handedness and natural-position identity")
	_check(club_roster[0].position_familiarity.size() == 5,
		"generated players track familiarity for every core position")
	var summary_profile: Dictionary = ATTRIBUTE_PROFILE_SCRIPT.summary_profile(club_roster[0])
	_check(summary_profile.size() == 6 and ATTRIBUTE_PROFILE_SCRIPT.grade(85.0) == "S" \
			and ATTRIBUTE_PROFILE_SCRIPT.grade(39.0) == "D",
		"player profile summarizes six graded categories from detailed wheels")
	_check(ATTRIBUTE_PROFILE_SCRIPT.detailed_profile(club_roster[0], "Mental & Tactical").size() == 6,
		"Mental and Tactical remains a six-point wheel with derived Reading and Adaptability")
	var conversion_player := academy_roster[6]
	conversion_player.wingspan_cm = 205.0
	conversion_player.jump_reach = 95
	conversion_player.explosiveness = 96
	var middle_suitability := FAMILIARITY_SCRIPT.suitability(conversion_player, "Middle Blocker")
	_check(middle_suitability >= 50,
		"unusual reach and explosiveness can make a short libero viable for middle training")
	conversion_player.position_training_target = "Middle Blocker"
	var familiarity_before := float(conversion_player.position_familiarity["Middle Blocker"])
	_check(FAMILIARITY_SCRIPT.train_position(conversion_player) > 0.0 \
			and float(conversion_player.position_familiarity["Middle Blocker"]) > familiarity_before,
		"adaptability-driven cross-training increases target-position familiarity")
	FAMILIARITY_SCRIPT.record_exposure(conversion_player, ["hand:left", "attack:cross"])
	_check(not conversion_player.situation_experience.is_empty(),
		"meaningful situations accumulate sparse player familiarity experience")
	var restored_server := VolleyballPlayer.from_dict(club_roster[0].to_dict())
	_check(restored_server.serve_technique == club_roster[0].serve_technique \
			and restored_server.primary_serve_style == club_roster[0].primary_serve_style \
			and restored_server.serve_style_proficiencies.size() == 5,
		"serve attributes and style proficiencies survive player serialization")
	var serve_manager := GAME_MANAGER_SCRIPT.new()
	serve_manager.seed_vertical_slice_data()
	serve_manager.match_state.serving_home = true
	var serve_result: Resource = serve_manager.resolve_active_rally(77531)
	var serve_event: Resource = serve_result.events[0]
	_check(serve_event.metadata.has("serve_style"),
		"rally serve events expose the mechanically selected serving style")
	var home_zone_one_correct := true
	for rotation_number in range(1, 7):
		serve_manager.select_rotation(rotation_number)
		serve_manager.match_state.serving_home = true
		var rotated_result: Resource = serve_manager.resolve_active_rally(77531 + rotation_number)
		var rotated_serve: Resource = rotated_result.events[0]
		home_zone_one_correct = home_zone_one_correct \
			and rotated_serve.actor_id == serve_manager.current_lineup().player_at_slot(1) \
			and int(rotated_serve.metadata.get("server_slot", -1)) == 1
	_check(home_zone_one_correct,
		"home serving ownership follows the player in zone 1 for every rotation")
	serve_manager.match_state.serving_home = false
	var opponent_zone_one_correct := true
	for rotation_number in range(1, 7):
		serve_manager.opponent_team.select_rotation(rotation_number)
		var opponent_result: Resource = serve_manager.resolve_active_rally(77600 + rotation_number)
		var opponent_serve: Resource = opponent_result.events[0]
		opponent_zone_one_correct = opponent_zone_one_correct \
			and opponent_serve.actor_id == serve_manager.opponent_team.current_lineup().player_at_slot(1) \
			and int(opponent_serve.metadata.get("server_slot", -1)) == 1
	_check(opponent_zone_one_correct,
		"opponent serving ownership follows the player in zone 1 for every rotation")
	serve_manager.free()
	var team := VolleyballTeam.new()
	team.tactical_familiarity = 0.30
	var prior_familiarity := team.tactical_familiarity
	var prior_discipline := club_roster[0].tactical_discipline
	var report: Dictionary = TRAINING_SYSTEM_SCRIPT.apply_week(
		"Team Practice", club_roster, team
	)
	_check(team.tactical_familiarity > prior_familiarity,
		"team practice raises tactical familiarity")
	_check(club_roster[0].tactical_discipline >= prior_discipline,
		"weekly training applies defined attribute development")
	_check(int(report.attribute_improvements) > 0,
		"training produces a report with concrete improvements")
	var format := MATCH_FORMAT_SCRIPT.new()
	format.best_of_sets = 3
	format.regular_set_target = 25
	format.deciding_set_target = 25
	_check(format.sets_to_win() == 2 and format.target_for_set(3) == 25,
		"career match format supports best-of-three with every set to 25")
	var career_manager := CAREER_MANAGER_SCRIPT.new()
	var game_autoload: Node = get_root().get_node("GameManager")
	career_manager.game_manager_override = game_autoload
	var test_save_id := "__automated_career_test__"
	var test_path := ProjectSettings.globalize_path("user://careers/%s.json" % test_save_id)
	if FileAccess.file_exists(test_path):
		DirAccess.remove_absolute(test_path)
	var create_error: String = career_manager.create_career(
		"__Automated Career Test__", "Test Volley Academy", "Landavol", "Academy", "Development"
	)
	_check(create_error.is_empty(), "career creation builds a playable deterministic career")
	_check(career_manager.career.organization_type == "Academy" \
			and game_autoload.players.size() == 12,
		"created career configures the managed academy roster")
	_check(career_manager.career.fixtures.size() == 3,
		"new careers receive a starter competition schedule")
	_check(career_manager.advance_week().is_empty(),
		"career can train and advance before its opening fixture")
	_check(career_manager.prepare_fixture(1).is_empty(),
		"due fixture prepares the configured Match Center state")
	_check(game_autoload.match_state.match_format.best_of_sets == 3,
		"fixture preparation passes career match format into MatchState")
	var candidate := career_manager.career.transfer_pool[0] as VolleyballPlayer
	var funds_before := int(career_manager.career.finances)
	_check(career_manager.sign_transfer(candidate.id).is_empty(),
		"regional transfer candidate can join an eligible roster")
	_check(int(career_manager.career.finances) == funds_before,
		"prototype roster additions are free for attribute testing")
	var prior_starter := int(game_autoload.team.starting_player_ids[0])
	_check(game_autoload.set_player_starting(prior_starter, false).is_empty() \
			and game_autoload.set_player_starting(candidate.id, true).is_empty(),
		"testing roster can move players directly between starter and bench status")
	var load_manager := CAREER_MANAGER_SCRIPT.new()
	load_manager.game_manager_override = game_autoload
	_check(load_manager.load_career(test_save_id).is_empty(),
		"career save reloads through save-slot persistence")
	_check(load_manager.career.organization_name == "Test Volley Academy",
		"career organization metadata survives loading")
	_check(career_manager.delete_save(test_save_id).is_empty() \
			and not FileAccess.file_exists(test_path), "selected career saves can be deleted")
	career_manager.free()
	load_manager.free()


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
	_check(
		Vector2(trajectory.position_at_time(2.0)).is_equal_approx(Vector2(0.1, 0.2))
			and Vector2(trajectory.position_at_time(2.8)).is_equal_approx(Vector2(0.9, 0.8))
			and is_equal_approx(float(trajectory.height_at_time(2.4)), 2.4),
		"ball trajectory supports deterministic absolute-time position and height queries",
	)


func _test_rally_state_foundations() -> void:
	var manager := GAME_MANAGER_SCRIPT.new()
	manager.seed_vertical_slice_data()
	var state = RALLY_STATE_BUILDER_SCRIPT.build(
		manager.players,
		manager.current_lineup(),
		manager.current_defensive_plan(),
		manager.opponent_team,
		null,
		false,
		1234,
	)
	_check(
		state.home_players.size() == 6 and state.opponent_players.size() == 6,
		"rally state builds persistent on-court state for both teams",
	)
	var home_player_id := manager.current_lineup().player_at_slot(5)
	var actor = state.player_state(&"home", home_player_id)
	var tactical_home: Vector2 = actor.tactical_home
	actor.apply_position(Vector2(0.72, 0.91), Vector2(1.2, 0.0))
	_check(
		actor.position.is_equal_approx(Vector2(0.72, 0.91))
			and actor.tactical_home.is_equal_approx(tactical_home),
		"actual rally position persists independently from tactical home",
	)

	var serve = BALL_TRAJECTORY_SCRIPT.create(
		"serve", Vector2(0.80, 0.08), Vector2(0.55, 0.48),
		Vector2(0.22, 0.84), 0.0, 1.1, 2.8, 2.3, 0.45,
	)
	state.ball.launch(serve, &"opponent", 1001, 1)
	state.advance_to(0.55)
	_check(
		state.ball.status == RallyBallState.Status.IN_FLIGHT
			and state.ball.position.distance_to(serve.start_position) > 0.01,
		"persistent ball state follows the shared trajectory as simulation time advances",
	)

	var scheduler = RALLY_SCHEDULER_SCRIPT.new()
	scheduler.schedule(RALLY_MOMENT_SCRIPT.create(
		1.0, RallyMoment.Kind.BALL_CONTACT
	))
	scheduler.schedule(RALLY_MOMENT_SCRIPT.create(
		0.4, RallyMoment.Kind.PERCEPTION
	))
	_check(
		is_equal_approx(float(scheduler.next().time), 0.4)
			and is_equal_approx(float(scheduler.next().time), 1.0),
		"rally scheduler advances through deterministic meaningful moments",
	)

	var fast_player := VolleyballPlayer.new()
	fast_player.id = 9901
	fast_player.acceleration = 90
	fast_player.lateral_speed = 90
	fast_player.transition_speed = 90
	fast_player.reception = 75
	fast_player.composure = 75
	var slow_player := VolleyballPlayer.new()
	slow_player.id = 9902
	slow_player.acceleration = 25
	slow_player.lateral_speed = 25
	slow_player.transition_speed = 25
	slow_player.reception = 75
	slow_player.composure = 75
	var fast_actor = RALLY_PLAYER_STATE_SCRIPT.create(
		fast_player, &"home", 5, Vector2(0.20, 0.84)
	)
	var slow_actor = RALLY_PLAYER_STATE_SCRIPT.create(
		slow_player, &"home", 5, Vector2(0.20, 0.84)
	)
	var fast_option = RALLY_MOVEMENT_SCRIPT.evaluate_opportunity(
		fast_actor, &"receive", Vector2(0.52, 0.84), 1.2, 0.0, 1.0
	)
	var slow_option = RALLY_MOVEMENT_SCRIPT.evaluate_opportunity(
		slow_actor, &"receive", Vector2(0.52, 0.84), 1.2, 0.0, 1.0
	)
	_check(
		fast_option.travel_time < slow_option.travel_time
			and fast_option.physical_feasibility > slow_option.physical_feasibility,
		"movement opportunities derive available actions from persistent position and speed",
	)
	var reception_options: Array = RALLY_MOVEMENT_SCRIPT.generate_reception_opportunities(state)
	_check(
		not reception_options.is_empty(),
		"ball flight and tactical zones generate reception opportunities without choosing an action",
	)
	var snapshot := state.snapshot()
	var snapshot_actor := snapshot.player_state(&"home", home_player_id)
	snapshot_actor.apply_position(Vector2(0.10, 0.70), Vector2.ZERO)
	_check(
		not snapshot_actor.position.is_equal_approx(actor.position)
			and actor.position.is_equal_approx(Vector2(0.72, 0.91)),
		"rally-state snapshots isolate scheduled shadow movement from source state",
	)
	var sample_window = ACTION_OPPORTUNITY_WINDOW_SCRIPT.create(
		&"receive", &"home", home_player_id, 0.30, 1.10,
		&"test_reachable",
	)
	sample_window.record_sample({"arrival_margin": 0.12})
	sample_window.close(0.85, &"test_late")
	_check(
		is_equal_approx(sample_window.duration(), 0.55)
			and is_equal_approx(sample_window.best_arrival_margin, 0.12)
			and str(sample_window.to_dict().get("close_reason", "")) == "test_late",
		"opportunity windows preserve opening, evidence, and closing contracts",
	)


func _test_ball_read_foundations() -> void:
	var common_signature = BALL_CONTACT_SIGNATURE_SCRIPT.create(
		&"topspin_serve", 16.0, 4.0, -12.0, 4.0, 1.0, 0.94,
	)
	var unusual_signature = BALL_CONTACT_SIGNATURE_SCRIPT.create(
		&"topspin_serve", 30.0, -48.0, -42.0, 17.0, -12.0, 0.42,
	)
	var float_signature = BALL_CONTACT_SIGNATURE_SCRIPT.create(
		&"float_serve", 18.0, -6.0, -8.0, 0.2, -0.3, 0.30,
	)
	_check(
		unusual_signature.topspin_rps > 0.0
			and unusual_signature.sidespin_rps < 0.0,
		"ball contact signatures preserve signed topspin and sidespin",
	)
	_check(
		float_signature.is_float_contact()
			and float_signature.flight_stability < common_signature.flight_stability,
		"float contacts use near-zero spin and explicitly lower flight stability",
	)
	_check(
		unusual_signature.baseline_novelty() > common_signature.baseline_novelty(),
		"normalized speed, angle, spin, and stability contribute to signature novelty",
	)

	var flight = BALL_FLIGHT_SCRIPT.create(
		Vector2(0.80, 0.08), Vector2(0.22, 0.84),
		2.0, 1.1, unusual_signature,
	)
	_check(
		flight.origin.is_equal_approx(Vector2(0.80, 0.08))
			and flight.destination.is_equal_approx(Vector2(0.22, 0.84))
			and is_equal_approx(flight.arrival_time, 3.1),
		"authoritative ball flights preserve calculated endpoints and arrival time",
	)

	var developing_reader := VolleyballPlayer.new()
	developing_reader.id = 8801
	developing_reader.anticipation = 30
	developing_reader.court_vision = 30
	developing_reader.decision_making = 30
	developing_reader.composure = 30
	var expert_reader := VolleyballPlayer.new()
	expert_reader.id = 8802
	expert_reader.anticipation = 90
	expert_reader.court_vision = 90
	expert_reader.decision_making = 90
	expert_reader.composure = 90
	var developing_estimate = BALL_READ_SCRIPT.estimate(
		flight, developing_reader, 0.10, 2.25, 44001,
	)
	var repeated_estimate = BALL_READ_SCRIPT.estimate(
		flight, developing_reader, 0.10, 2.25, 44001,
	)
	var expert_estimate = BALL_READ_SCRIPT.estimate(
		flight, expert_reader, 0.10, 2.25, 44001,
	)
	_check(
		developing_estimate.perceived_destination.is_equal_approx(
			repeated_estimate.perceived_destination
		)
			and is_equal_approx(
				developing_estimate.perceived_arrival_time,
				repeated_estimate.perceived_arrival_time,
			),
		"ball reading is reproducible for identical inputs and seed",
	)
	_check(
		expert_estimate.recognition_time < developing_estimate.recognition_time
			and expert_estimate.destination_error_meters()
				< developing_estimate.destination_error_meters(),
		"better anticipation and reading attributes improve recognition and spatial estimates",
	)
	var familiar_estimate = BALL_READ_SCRIPT.estimate(
		flight, developing_reader, 0.95, 2.25, 44001,
	)
	_check(
		familiar_estimate.novelty < developing_estimate.novelty
			and familiar_estimate.recognition_time < developing_estimate.recognition_time
			and familiar_estimate.destination_error_meters()
				< developing_estimate.destination_error_meters(),
		"temporary familiarity reduces novelty, recognition delay, and prediction error",
	)
	_check(
		CourtConstants.is_normalized(developing_estimate.perceived_destination)
			and developing_estimate.perceived_arrival_time >= developing_estimate.observed_at,
		"perceived flights remain inside bounded court and timing contracts",
	)
	var read_sequence: Array[BallFlightEstimate] = BALL_READ_SCRIPT.estimate_sequence(
		flight, developing_reader, 0.10, [0.12, 0.32, 0.52], 44001,
	)
	_check(
		read_sequence.size() == 3
			and read_sequence[0].observed_at < read_sequence[1].observed_at
			and read_sequence[1].observed_at < read_sequence[2].observed_at,
		"repeated reads produce three deterministic observations in flight order",
	)
	_check(
		read_sequence[-1].destination_error_meters()
			< read_sequence[0].destination_error_meters()
			and read_sequence[-1].confidence > read_sequence[0].confidence,
		"later observations improve destination accuracy and confidence",
	)

	var reading_actor = RALLY_PLAYER_STATE_SCRIPT.create(
		developing_reader, &"home", 5, Vector2(0.20, 0.86),
	)
	developing_reader.acceleration = 70
	developing_reader.lateral_speed = 70
	developing_reader.reception = 70
	var perceived_option = RALLY_MOVEMENT_SCRIPT.evaluate_opportunity(
		reading_actor,
		&"receive",
		developing_estimate.perceived_destination,
		developing_estimate.perceived_arrival_time,
		developing_estimate.recognition_time,
		1.0,
	)
	_check(
		perceived_option.player_id == developing_reader.id
			and perceived_option.contact_position.is_equal_approx(
				developing_estimate.perceived_destination
			),
		"perceived destination and recognition time can drive shadow reception movement",
	)
	var original_position: Vector2 = reading_actor.position
	var projected: Dictionary = RALLY_MOVEMENT_SCRIPT.project_toward(
		reading_actor,
		developing_estimate.perceived_destination,
		0.30,
		RallyPlayerState.MovementMode.LATERAL,
	)
	var projected_actor := projected.get("actor") as RallyPlayerState
	_check(
		projected_actor != null
			and projected_actor.position != original_position
			and reading_actor.position == original_position,
		"movement projection advances a temporary snapshot without mutating live state",
	)
	_check(
		float(projected.get("distance_meters", 0.0)) > 0.0
			and projected_actor.velocity.length() > 0.0,
		"projected movement carries measured distance and velocity into the next read",
	)


func _test_shadow_reception_trace() -> void:
	var manager := GAME_MANAGER_SCRIPT.new()
	manager.seed_vertical_slice_data()
	manager.match_state.serving_home = false
	var result: Resource = manager.resolve_active_rally(1001)
	var trace: Dictionary = result.analysis.get("shadow_reception", {})
	var summary: Dictionary = trace.get("summary", {})
	var entries: Array = trace.get("entries", [])
	var timing: Dictionary = summary.get("timing_diagnostics", {})
	var timing_candidates: Dictionary = summary.get("timing_candidates", {})
	var speed_candidates: Dictionary = summary.get("speed_candidates", {})
	var perception_candidates: Dictionary = summary.get("perception_candidates", {})
	var shadow_decision: Dictionary = summary.get("shadow_decision", {})
	_check(
		bool(summary.get("available", false)) and not entries.is_empty(),
		"opponent serves attach a developer-only shadow reception trace",
	)
	_check(
		float(timing.get("distance_meters", 0.0)) > 0.0
			and float(timing.get("signature_speed_mps", 0.0)) > 0.0
			and float(timing.get("recorded_duration_seconds", 0.0)) > 0.0
			and float(timing.get("implied_duration_seconds", 0.0)) > 0.0,
		"shadow reception exposes complete speed-distance-duration diagnostics",
	)
	_check(
		Dictionary(timing_candidates.get("legacy_duration", {})).has(
			"selected_arrival_margin"
		)
			and Dictionary(timing_candidates.get("signature_duration", {})).has(
				"selected_arrival_margin"
			)
			and timing_candidates.has("claimant_changed"),
		"shadow reception compares action availability under both timing candidates",
	)
	var derived_speed: Dictionary = speed_candidates.get("derived_speed", {})
	var calculated_speed: Dictionary = speed_candidates.get("independent_speed", {})
	_check(
		is_equal_approx(
			float(derived_speed.get("speed_mps", -1.0)),
			float(timing.get("effective_recorded_speed_mps", 0.0))
		)
			and derived_speed.has("selected_destination_error_meters")
			and speed_candidates.has("claimant_changed"),
		"derived-speed shadow evidence uses legacy distance and duration consistently",
	)
	_check(
		str(summary.get("canonical_signature_source", ""))
			== "calculated_speed_derived_duration"
			and int(summary.get("shadow_claimant_id", -1))
				== int(calculated_speed.get("shadow_claimant_id", -2))
			and bool(Dictionary(summary.get(
				"canonical_timing_diagnostics", {}
			)).get("within_tolerance", false)),
		"calculated serve speed and its derived duration are canonical in shadow reception",
	)
	_check(
		Array(perception_candidates.get("observation_progresses", [])).size() == 3
			and Dictionary(perception_candidates.get("repeated_read", {})).has(
				"total_correction_distance_meters"
			),
		"shadow reception compares a three-observation read against the single read",
	)
	var decision_options: Array = shadow_decision.get("options", [])
	var selected_decision_id := int(shadow_decision.get("selected_player_id", -1))
	var shadow_contact: Dictionary = shadow_decision.get("contact_result", {})
	_check(
		int(shadow_decision.get("option_count", -1)) == decision_options.size()
			and (selected_decision_id < 0 or bool(shadow_contact.get(
				"attempted", false
			))),
		"shadow decisions expose open receiver options and a graded contact attempt",
	)
	var official_receiver_id := -1
	for event_resource in result.events:
		var event: Resource = event_resource
		if int(event.event_type) == RALLY_EVENT_SCRIPT.EventType.RECEPTION \
				and str(event.metadata.get("side", "")) == "home":
			official_receiver_id = int(event.actor_id)
			break
	_check(
		official_receiver_id == int(summary.get("legacy_claimant_id", -2)),
		"shadow diagnostics preserve the legacy reception claimant as official",
	)
	_check(
		selected_decision_id != official_receiver_id
			or int(shadow_contact.get("actor_id", -1)) == official_receiver_id,
		"shadow contact evidence never changes which receiver owns the official event",
	)
	var shadow_selected_count := 0
	var legacy_selected_count := 0
	var bounded_trace := true
	var repeated_trace_valid := true
	var projected_movement_seen := false
	var scheduled_windows_valid := true
	for raw_entry in entries:
		var entry: Dictionary = raw_entry
		shadow_selected_count += 1 if bool(entry.get("shadow_selected", false)) else 0
		legacy_selected_count += 1 if bool(entry.get("legacy_selected", false)) else 0
		bounded_trace = bounded_trace \
			and CourtConstants.is_normalized(Vector2(entry.perceived_destination)) \
			and float(entry.recognition_time) <= float(entry.perceived_arrival_time)
		var repeated: Dictionary = entry.get("repeated_read_candidate", {})
		var moments: Array = repeated.get("moments", [])
		repeated_trace_valid = repeated_trace_valid and moments.size() == 3
		if moments.size() == 3:
			repeated_trace_valid = repeated_trace_valid \
				and float(Dictionary(moments[0]).get("observed_at", 0.0)) \
					< float(Dictionary(moments[1]).get("observed_at", 0.0)) \
				and float(Dictionary(moments[1]).get("observed_at", 0.0)) \
					< float(Dictionary(moments[2]).get("observed_at", 0.0)) \
				and float(Dictionary(moments[2]).get(
					"destination_error_meters", 99.0
				)) < float(Dictionary(moments[0]).get(
					"destination_error_meters", 0.0
				))
			projected_movement_seen = projected_movement_seen or float(
				repeated.get("projected_distance_meters", 0.0)
			) > 0.0
		var opportunity_timeline: Dictionary = repeated.get(
			"opportunity_timeline", {}
		)
		var scheduled_timeline: Array = opportunity_timeline.get("timeline", [])
		scheduled_windows_valid = scheduled_windows_valid \
			and bool(opportunity_timeline.get("available", false)) \
			and bool(opportunity_timeline.get("source_state_unchanged", false)) \
			and scheduled_timeline.size() == 4
		var previous_scheduled_time := -INF
		for raw_scheduled in scheduled_timeline:
			var scheduled: Dictionary = raw_scheduled
			scheduled_windows_valid = scheduled_windows_valid \
				and float(scheduled.get("time", -INF)) >= previous_scheduled_time
			previous_scheduled_time = float(scheduled.get("time", -INF))
	_check(
		shadow_selected_count == 1 and legacy_selected_count == 1 and bounded_trace,
		"shadow trace identifies both claimants and keeps estimates bounded",
	)
	_check(
		repeated_trace_valid,
		"every shadow candidate records ordered, improving repeated-read evidence",
	)
	_check(
		projected_movement_seen
			and str(Dictionary(perception_candidates.get(
				"repeated_read", {}
			)).get("projection_model", "")) == "read_only_persistent_movement",
		"repeated reads carry a projected receiver position between observations",
	)
	_check(
		scheduled_windows_valid,
		"scheduled shadow reads produce chronological windows without mutating source state",
	)
	var repeated_manager := GAME_MANAGER_SCRIPT.new()
	repeated_manager.seed_vertical_slice_data()
	repeated_manager.match_state.serving_home = false
	var repeated_result: Resource = repeated_manager.resolve_active_rally(1001)
	var repeated_trace: Dictionary = repeated_result.analysis.get("shadow_reception", {})
	_check(
		trace == repeated_trace,
		"shadow reception traces are deterministic for identical match inputs and seed",
	)
	var court := TACTICAL_COURT_SCRIPT.new()
	court.set_shadow_reception_trace(trace)
	_check(
		court.shadow_reception_trace == trace,
		"2D tactical courts accept the same trace used by the developer inspector",
	)
	court.clear_shadow_reception_trace()
	_check(
		court.shadow_reception_trace.is_empty(),
		"2D shadow reception overlays can be cleared between rallies",
	)
	court.free()


func _test_rally_kinematics() -> void:
	var full_court_distance := RALLY_KINEMATICS_SCRIPT.court_distance_meters(
		Vector2.ZERO, Vector2.ONE
	)
	_check(
		is_equal_approx(full_court_distance, sqrt(9.0 * 9.0 + 18.0 * 18.0)),
		"shared rally kinematics converts normalized court coordinates to meters",
	)
	var duration := RALLY_KINEMATICS_SCRIPT.flight_duration(18.0, 18.0)
	var speed := RALLY_KINEMATICS_SCRIPT.effective_speed(18.0, duration)
	_check(
		is_equal_approx(duration, 1.0) and is_equal_approx(speed, 18.0),
		"shared flight duration and effective speed are reversible",
	)
	var diagnostics: Dictionary = RALLY_KINEMATICS_SCRIPT.timing_diagnostics(
		Vector2(0.5, 0.0), Vector2(0.5, 1.0), 18.0, 1.0
	)
	_check(
		bool(diagnostics.get("within_tolerance", false))
			and is_equal_approx(
				float(diagnostics.get("relative_duration_error", 1.0)), 0.0
			),
		"timing diagnostics identify a self-consistent speed-distance-duration set",
	)


func _test_gate_one_calibration_batch() -> void:
	var manager := GAME_MANAGER_SCRIPT.new()
	manager.seed_vertical_slice_data()
	var report := RALLY_CALIBRATION_REPORT_SCRIPT.new()
	for seed_value in range(12000, 12048):
		manager.match_state.serving_home = false
		var result: Resource = manager.resolve_active_rally(seed_value)
		report.add_shadow_trace(result.analysis.get("shadow_reception", {}))
	var summary: Dictionary = report.build_summary()
	var distributions: Dictionary = summary.get("distributions", {})
	var timing_distribution: Dictionary = distributions.get(
		"relative_duration_error", {}
	)
	_check(
		int(summary.get("requested_samples", 0)) == 48
			and int(summary.get("available_samples", 0))
				+ int(summary.get("skipped_samples", 0)) == 48
			and int(summary.get("invalid_samples", 1)) == 0,
		"Gate 1 batch calibration accounts for eligible receptions and serve-error skips",
	)
	_check(
		int(timing_distribution.get("count", 0))
			== int(summary.get("available_samples", 0))
			and is_finite(float(timing_distribution.get("mean", NAN)))
			and float(timing_distribution.get("minimum", -1.0)) >= 0.0,
		"Gate 1 timing distributions are complete, finite, and non-negative",
	)
	_check(
		bool(summary.get("shadow_only", false))
			and summary.has("claimant_agreement_rate")
			and summary.has("shadow_reachable_rate")
			and summary.has("by_serve_style"),
		"Gate 1 reports behavior evidence without activating shadow decisions",
	)


func _test_gate_two_serve_style_fixtures() -> void:
	var summary: Dictionary = SERVE_STYLE_CALIBRATION_SCRIPT.run(4, 13000)
	var styles: Dictionary = summary.get("by_serve_style", {})
	var accounted := int(summary.get("available_samples", 0)) \
		+ int(summary.get("skipped_samples", 0)) \
		+ int(summary.get("invalid_samples", 0))
	_check(
		bool(summary.get("style_coverage_complete", false))
			and styles.size() == SERVE_STYLE_CALIBRATION_SCRIPT.SERVE_STYLES.size(),
		"Gate 2 controlled fixtures cover every supported primary serve style",
	)
	_check(
		int(summary.get("requested_samples", 0)) == 20
			and accounted == 20
			and int(summary.get("invalid_samples", 1)) == 0,
		"Gate 2 accounts for every paired fixture without malformed evidence",
	)
	_check(
		summary.has("signature_duration_reachable_rate")
			and summary.has("timing_candidate_claimant_change_rate")
			and Dictionary(summary.get("distributions", {})).has(
				"candidate_arrival_margin_delta_seconds"
			),
		"Gate 2 reports how timing candidates change available reception actions",
	)


func _test_gate_three_derived_speed() -> void:
	var summary: Dictionary = SERVE_STYLE_CALIBRATION_SCRIPT.run(
		3, 14000, "derived_speed_calibration_gate_3"
	)
	var distributions: Dictionary = summary.get("distributions", {})
	var speed_distribution: Dictionary = distributions.get("derived_speed_mps", {})
	var error_delta: Dictionary = distributions.get(
		"derived_speed_destination_error_delta_meters", {}
	)
	_check(
		int(speed_distribution.get("count", 0))
			== int(summary.get("available_samples", 0))
			and float(speed_distribution.get("minimum", 0.0)) > 0.0,
		"Gate 3 derives one finite positive speed for every eligible serve",
	)
	_check(
		summary.has("derived_speed_reachable_rate")
			and summary.has("derived_speed_claimant_change_rate")
			and int(error_delta.get("count", 0))
				== int(summary.get("available_samples", 0)),
		"Gate 3 measures derived-speed effects on perception and action selection",
	)
	_check(
		is_equal_approx(
			float(summary.get("canonical_calculated_speed_rate", 0.0)), 1.0
		),
		"calibration confirms every eligible trace uses canonical calculated speed",
	)
	_check(
		bool(summary.get("shadow_only", false))
			and str(summary.get("gate", "")) == "derived_speed_calibration_gate_3"
			and int(summary.get("invalid_samples", 1)) == 0,
		"Gate 3 remains shadow-only and produces no malformed fixture evidence",
	)


func _test_gate_four_reader_and_formation_matrix() -> void:
	var summary: Dictionary = RECEPTION_PROGRESSION_CALIBRATION_SCRIPT.run(
		2, 15000
	)
	var overall: Dictionary = summary.get("overall", {})
	var progression: Dictionary = summary.get("reader_progression", {})
	var tiers: Dictionary = summary.get("by_reader_tier", {})
	_check(
		bool(summary.get("fixture_valid", false))
			and bool(summary.get("style_coverage_complete", false))
			and int(overall.get("requested", 0)) == 90
			and int(overall.get("invalid", 1)) == 0,
		"Gate 4 covers every reader-tier, formation, style, and paired-seed fixture",
	)
	_check(
		bool(progression.get("destination_error_monotonic", false))
			and bool(progression.get("recognition_delay_monotonic", false)),
		"Gate 4 confirms stronger readers receive monotonically better information",
	)
	_check(
		float(Dictionary(tiers.get("elite", {})).get(
			"confidence_mean", 0.0
		)) > float(Dictionary(tiers.get("weak", {})).get(
			"confidence_mean", 1.0
		))
			and float(summary.get("formation_reachability_spread", 0.0)) > 0.0,
		"Gate 4 exposes both player-development and formation effects",
	)


func _test_gate_six_repeated_reads() -> void:
	var summary: Dictionary = SERVE_STYLE_CALIBRATION_SCRIPT.run(
		3, 16000, "repeated_read_calibration_gate_6"
	)
	var distributions: Dictionary = summary.get("distributions", {})
	var error_delta: Dictionary = distributions.get(
		"repeated_read_destination_error_delta_meters", {}
	)
	var confidence_delta: Dictionary = distributions.get(
		"repeated_read_confidence_delta", {}
	)
	_check(
		int(summary.get("invalid_samples", 1)) == 0
			and int(error_delta.get("count", 0))
				== int(summary.get("available_samples", 0))
			and int(confidence_delta.get("count", 0))
				== int(summary.get("available_samples", 0)),
		"Gate 6 accounts for repeated-read error and confidence on every eligible serve",
	)
	_check(
		float(error_delta.get("maximum", 1.0)) < 0.0
			and float(confidence_delta.get("minimum", -1.0)) > 0.0,
		"Gate 6 repeated observations consistently improve information quality",
	)
	_check(
		bool(summary.get("shadow_only", false))
			and summary.has("repeated_read_reachable_rate")
			and summary.has("repeated_read_claimant_change_rate"),
		"Gate 6 remains shadow-only while measuring changed action availability",
	)


func _test_gate_seven_projected_movement() -> void:
	var summary: Dictionary = SERVE_STYLE_CALIBRATION_SCRIPT.run(
		3, 17000, "projected_movement_calibration_gate_7"
	)
	var distributions: Dictionary = summary.get("distributions", {})
	var movement: Dictionary = distributions.get(
		"repeated_read_projected_distance_meters", {}
	)
	var margin_gain: Dictionary = distributions.get(
		"repeated_read_arrival_margin_gain_vs_stationary_seconds", {}
	)
	_check(
		int(summary.get("invalid_samples", 1)) == 0
			and int(movement.get("count", 0))
				== int(summary.get("available_samples", 0))
			and float(movement.get("minimum", -1.0)) >= 0.0,
		"Gate 7 records bounded projected movement for every eligible serve",
	)
	_check(
		float(margin_gain.get("mean", 0.0)) > 0.0
			and float(summary.get("repeated_read_reachable_rate", 0.0))
				>= float(summary.get(
					"stationary_repeated_read_reachable_rate", 1.0
				)),
		"Gate 7 projected movement restores time and actions lost by stationary reads",
	)
	_check(
		bool(summary.get("shadow_only", false))
			and str(summary.get("gate", ""))
				== "projected_movement_calibration_gate_7",
		"Gate 7 movement remains a read-only shadow candidate",
	)


func _test_gate_eight_opportunity_windows() -> void:
	var summary: Dictionary = SERVE_STYLE_CALIBRATION_SCRIPT.run(
		3, 18000, "opportunity_window_calibration_gate_8"
	)
	var distributions: Dictionary = summary.get("distributions", {})
	var window_count: Dictionary = distributions.get("opportunity_window_count", {})
	var open_duration: Dictionary = distributions.get(
		"opportunity_open_duration_seconds", {}
	)
	var intent_changes: Dictionary = distributions.get(
		"scheduled_intent_change_count", {}
	)
	_check(
		int(summary.get("invalid_samples", 1)) == 0
			and int(window_count.get("count", 0))
				== int(summary.get("available_samples", 0))
			and int(open_duration.get("count", 0))
				== int(summary.get("available_samples", 0)),
		"Gate 8 records opportunity-window evidence for every eligible serve",
	)
	_check(
		float(summary.get("scheduled_opportunity_rate", 0.0)) > 0.0
			and float(open_duration.get("mean", 0.0)) > 0.0
			and float(intent_changes.get("mean", 0.0)) >= 1.0,
		"Gate 8 exposes options opening over time and corrected movement intents",
	)
	_check(
		bool(summary.get("shadow_only", false))
			and str(summary.get("gate", ""))
				== "opportunity_window_calibration_gate_8",
		"Gate 8 scheduled decisions remain shadow-only",
	)


func _test_gate_nine_shadow_decisions() -> void:
	var summary: Dictionary = SERVE_STYLE_CALIBRATION_SCRIPT.run(
		3, 19000, "shadow_decision_calibration_gate_9"
	)
	var distributions: Dictionary = summary.get("distributions", {})
	var option_count: Dictionary = distributions.get(
		"shadow_decision_option_count", {}
	)
	var contact_quality: Dictionary = distributions.get(
		"shadow_contact_quality", {}
	)
	_check(
		int(summary.get("invalid_samples", 1)) == 0
			and int(option_count.get("count", 0))
				== int(summary.get("available_samples", 0))
			and int(contact_quality.get("count", 0))
				== int(summary.get("available_samples", 0)),
		"Gate 9 grades options and contacts for every eligible serve",
	)
	_check(
		float(summary.get("shadow_decision_rate", 0.0)) > 0.0
			and float(summary.get("shadow_contact_success_rate", 0.0)) >= 0.0
			and summary.has("shadow_decision_conflict_rate"),
		"Gate 9 reports selection, teammate conflict, and true-ball contact outcomes",
	)
	_check(
		bool(summary.get("shadow_only", false))
			and str(summary.get("gate", ""))
				== "shadow_decision_calibration_gate_9",
		"Gate 9 decisions remain evidence rather than official rally events",
	)


func _test_gate_ten_decision_progression() -> void:
	var summary: Dictionary = RECEPTION_DECISION_PROGRESSION_SCRIPT.run(
		4, 100000
	)
	var overall: Dictionary = summary.get("overall", {})
	var progression: Dictionary = summary.get("progression", {})
	var tiers: Dictionary = summary.get("by_player_tier", {})
	var developing: Dictionary = tiers.get("developing", {})
	var established: Dictionary = tiers.get("established", {})
	var elite: Dictionary = tiers.get("elite", {})
	_check(
		bool(summary.get("fixture_valid", false))
			and bool(summary.get("style_coverage_complete", false))
			and int(overall.get("requested", 0)) == 180
			and int(overall.get("invalid", 1)) == 0,
		"Gate 10 covers paired tiers, formations, serve styles, and seeds",
	)
	_check(
		bool(progression.get("decision_rate_monotonic", false))
			and bool(progression.get("contact_success_monotonic", false))
			and bool(progression.get("window_duration_monotonic", false))
			and bool(progression.get("contact_choices_monotonic", false)),
		"Gate 10 converts player development into monotonically stronger choices",
	)
	_check(
		float(elite.get("contact_choices_mean", 0.0))
			> float(established.get("contact_choices_mean", 0.0))
			and float(established.get("contact_choices_mean", 0.0))
				> float(developing.get("contact_choices_mean", 0.0))
			and float(elite.get("quick_release_available_rate", 0.0))
				> float(developing.get("quick_release_available_rate", 0.0)),
		"Gate 10 verifies elite receivers gain options unavailable to developing players",
	)


func _test_gate_eleven_outgoing_reception_flight() -> void:
	var contact := {
		"attempted": true, "success": true, "quality": 0.72,
		"action": "safe_center_pass",
		"contact_position": Vector2(0.22, 0.84),
		"contact_time": 1.14,
		"outgoing_target": Vector2(0.50, 0.67),
	}
	var candidate: Dictionary = RALLY_CONTACT_SCRIPT.resolve_shadow_reception(contact)
	var flight: Dictionary = candidate.get("flight", {})
	var signature: Dictionary = flight.get("signature", {})
	var continuity: Dictionary = candidate.get("continuity", {})
	_check(
		bool(candidate.get("available", false))
			and Vector2(flight.get("origin", Vector2.ZERO)) == contact.contact_position
			and Vector2(flight.get("destination", Vector2.ZERO)) == contact.outgoing_target
			and is_equal_approx(float(flight.get("start_time", 0.0)), contact.contact_time),
		"Gate 11 outgoing flight begins exactly at the resolved contact",
	)
	_check(
		bool(continuity.get("valid", false))
			and float(flight.get("duration", 0.0)) > 0.0
			and float(signature.get("speed_mps", 0.0)) > 0.0
			and float(signature.get("flight_stability", -1.0)) >= 0.0
			and float(signature.get("flight_stability", 2.0)) <= 1.0,
		"Gate 11 creates a bounded signature with consistent speed and duration",
	)
	var failed := contact.duplicate(true)
	failed["success"] = false
	_check(
		not bool(RALLY_CONTACT_SCRIPT.resolve_shadow_reception(failed).get(
			"available", true
		)),
		"Gate 11 never launches an outgoing flight after a failed contact",
	)
	var summary: Dictionary = SERVE_STYLE_CALIBRATION_SCRIPT.run(
		3, 110000, "outgoing_flight_calibration_gate_11"
	)
	_check(
		int(summary.get("invalid_samples", 1)) == 0
			and float(summary.get("outgoing_flight_candidate_rate", 0.0)) > 0.0
			and is_equal_approx(
				float(summary.get("outgoing_continuity_valid_rate", 0.0)), 1.0
			),
		"Gate 11 batch produces only contact-continuous outgoing candidates",
	)


func _test_gate_twelve_shadow_setter_response() -> void:
	var manager := GAME_MANAGER_SCRIPT.new()
	manager.seed_vertical_slice_data()
	manager.match_state.serving_home = false
	var response: Dictionary = {}
	var outgoing: Dictionary = {}
	var decision: Dictionary = {}
	var expected_intent: Dictionary = {}
	for offset in range(40):
		var result: Resource = manager.resolve_active_rally(120000 + offset)
		var trace: Dictionary = result.analysis.get("shadow_reception", {})
		var summary: Dictionary = trace.get("summary", {})
		response = summary.get("shadow_setter_response", {})
		outgoing = summary.get("outgoing_flight_candidate", {})
		decision = summary.get("shadow_decision", {})
		expected_intent = summary.get("expected_second_contact_intent", {})
		if bool(response.get("available", false)):
			break
	_check(
		bool(outgoing.get("available", false))
			and bool(response.get("available", false))
			and int(response.get("candidate_count", 0)) > 0,
		"Gate 12 gives eligible second-contact players the outgoing pass to read",
	)
	var candidates: Array = response.get("candidates", [])
	var moments_valid := true
	for raw_candidate in candidates:
		var candidate: Dictionary = raw_candidate
		moments_valid = moments_valid \
			and Array(candidate.get("moments", [])).size() == 3 \
			and candidate.has("true_arrival_margin") \
			and candidate.has("set_options")
	_check(
		moments_valid and bool(response.get("source_state_unchanged", false)),
		"Gate 12 projects three setter reads without mutating source positions",
	)
	_check(
		response.has("selected_final_target_distance_meters")
			and response.has("selected_final_movement_capacity_meters")
			and response.has("selected_final_center_distance_deficit_meters")
			and float(response.get("selected_contact_reach_meters", 0.0)) > 0.0
			and response.has("selected_actions"),
		"Reach diagnostics use the setter's physical contact envelope",
	)
	_check(
		response.has("selected_perceived_actions")
			and response.has("selected_physically_executable_actions"),
		"Setter evidence separates perceived choices from executable choices",
	)
	_check(
		response.has("ownership_changed")
			and not str(response.get("handoff_reason", "")).is_empty()
			and not str(response.get("expected_setter_name", "")).is_empty()
			and not str(response.get("selected_setter_name", "")).is_empty(),
		"Gate 17 explains intended-versus-actual second-contact ownership",
	)
	var contact: Dictionary = decision.get("contact_result", {})
	var expected_setter_id := int(expected_intent.get("player_id", -1))
	var expected_target := Vector2(expected_intent.get("target", Vector2.ZERO))
	var plan: Resource = manager.current_defensive_plan()
	var expected_candidate: Dictionary = {}
	for raw_candidate in candidates:
		var candidate: Dictionary = raw_candidate
		if int(candidate.get("player_id", -1)) == expected_setter_id:
			expected_candidate = candidate
			break
	_check(
		expected_setter_id >= 0
			and expected_setter_id != int(contact.get("actor_id", -1))
			and expected_target.is_equal_approx(
				plan.setter_release_target(expected_setter_id)
			)
			and Vector2(expected_candidate.get(
				"preparation_target", Vector2.ZERO
			)).is_equal_approx(expected_target),
		"Gate 12 aims reception at the expected second-contact owner's tactical release",
	)
	var lateral_release := Vector2(0.64, 0.59)
	_check(
		RALLY_DECISION_SCRIPT.pass_target_for_action(
			lateral_release, &"safe_center_pass"
		).is_equal_approx(Vector2(0.64, 0.67))
			and RALLY_DECISION_SCRIPT.pass_target_for_action(
				lateral_release, &"emergency_keep_alive"
			).is_equal_approx(Vector2(0.64, 0.78)),
		"Gate 12 safety passes preserve the tactical path's lateral destination",
	)
	var lineup := manager.current_lineup()
	var active_setter_id := lineup.active_setter_id()
	var emergency_setter_id := lineup.player_at_slot(2)
	for slot_number in range(1, 7):
		var player_id := lineup.player_at_slot(slot_number)
		if player_id == active_setter_id:
			continue
		var assignment: Resource = plan.assignment_for(player_id)
		assignment.second_contact_responsibility = \
			"Primary emergency setter" if player_id == emergency_setter_id \
			else "No second-contact duty"
	var emergency_target := Vector2(0.62, 0.64)
	plan.set_setter_release_target(emergency_setter_id, emergency_target)
	var emergency_state := RALLY_STATE_BUILDER_SCRIPT.build(
		manager.players, lineup, plan, manager.opponent_team,
		null, false, 120999,
	)
	var emergency_intent: Dictionary = \
		SHADOW_SETTER_RESPONSE_SCRIPT.expected_second_contact_intent(
			emergency_state, active_setter_id
		)
	_check(
		int(emergency_intent.get("player_id", -1)) == emergency_setter_id
			and Vector2(emergency_intent.get(
				"target", Vector2.ZERO
			)).is_equal_approx(emergency_target),
		"Gate 12 redirects a setter's first contact to the assigned emergency setter",
	)
	var default_layers := TacticalCourt.SHADOW_LAYER_DEFAULT
	_check(
		bool(default_layers & TacticalCourt.SHADOW_LAYER_CORE)
			and bool(default_layers & TacticalCourt.SHADOW_LAYER_INTENT)
			and bool(default_layers & TacticalCourt.SHADOW_LAYER_LABELS)
			and bool(default_layers & TacticalCourt.SHADOW_LAYER_ENVELOPES)
			and not bool(default_layers & TacticalCourt.SHADOW_LAYER_READS)
			and not bool(default_layers & TacticalCourt.SHADOW_LAYER_OPPORTUNITIES),
		"Gate 18 defaults to readable ball and setter intent layers",
	)
	var overlay_court := TACTICAL_COURT_SCRIPT.new()
	overlay_court.set_shadow_overlay_layers(TacticalCourt.SHADOW_LAYER_ALL)
	_check(
		overlay_court.shadow_overlay_layers == TacticalCourt.SHADOW_LAYER_ALL,
		"Gate 19 overlay layers can be independently enabled for verification",
	)
	_check(
		bool(TacticalCourt.SHADOW_LAYER_ALL & TacticalCourt.SHADOW_LAYER_ENVELOPES),
		"Gate 25 includes physical contact envelopes in full diagnostics",
	)
	overlay_court.free()
	var batch: Dictionary = SERVE_STYLE_CALIBRATION_SCRIPT.run(
		8, 120000, "setter_response_calibration_gate_12"
	)
	_check(
		int(batch.get("invalid_samples", 1)) == 0
			and float(batch.get("setter_response_rate", 0.0)) > 0.0
			and batch.has("setter_reachable_given_response_rate"),
		"Gate 12 reports setter response and second-contact reachability",
	)
	var counterfactuals: Dictionary = batch.get("reach_counterfactuals", {})
	var receiver_reach_rates: Dictionary = counterfactuals.get(
		"receiver_contact_reach_rates", {}
	)
	var setter_time_rates: Dictionary = counterfactuals.get(
		"setter_time_buffer_rates", {}
	)
	_check(
		float(receiver_reach_rates.get("0.60", 0.0))
			>= float(receiver_reach_rates.get("0.00", 0.0))
			and float(setter_time_rates.get("0.15", 0.0))
				>= float(setter_time_rates.get("0.00", 0.0)),
		"Reach diagnostics compare contact radius and time buffers without mutation",
	)


func _test_gate_thirteen_shadow_playback_adapter() -> void:
	var manager := GAME_MANAGER_SCRIPT.new()
	manager.seed_vertical_slice_data()
	manager.match_state.serving_home = false
	var playback: Dictionary = {}
	var official_result: Resource = null
	for offset in range(250):
		official_result = manager.resolve_active_rally(130000 + offset)
		var trace: Dictionary = official_result.analysis.get("shadow_reception", {})
		playback = Dictionary(trace.get("summary", {})).get(
			"shadow_playback_candidate", {}
		)
		if bool(playback.get("available", false)):
			break
	var events: Array = playback.get("events", [])
	var reception: Dictionary = events[0] if not events.is_empty() else {}
	var trajectory: Dictionary = Dictionary(reception.get(
		"metadata", {}
	)).get("outgoing_trajectory", {})
	_check(
		bool(playback.get("available", false))
			and bool(playback.get("trajectory_contract_valid", false))
			and events.size() >= 1,
		"Gate 13 adapts successful shadow evidence into playback events",
	)
	_check(
		int(reception.get("event_type", -1)) == RALLY_EVENT_SCRIPT.EventType.RECEPTION
			and trajectory.has("start_position")
			and trajectory.has("end_position")
			and trajectory.has("apex_height_meters")
			and trajectory.has("duration"),
		"Gate 13 emits the exact outgoing_trajectory playback keys",
	)
	var official_unchanged := official_result != null
	for event_resource in official_result.events:
		official_unchanged = official_unchanged \
			and not bool(event_resource.metadata.get("shadow_only", false))
	_check(
		official_unchanged and not bool(playback.get("official_events_mutated", true)),
		"Gate 13 keeps adapted events outside the official rally result",
	)
	var batch: Dictionary = SERVE_STYLE_CALIBRATION_SCRIPT.run(
		3, 130000, "playback_adapter_calibration_gate_13"
	)
	_check(
		int(batch.get("invalid_samples", 1)) == 0
			and float(batch.get("shadow_playback_candidate_rate", 0.0)) > 0.0
			and is_equal_approx(float(batch.get(
				"shadow_playback_contract_valid_rate", 0.0
			)), 1.0),
		"Gate 13 batch keeps every adapted trajectory contract-valid",
	)


func _test_gate_fourteen_serve_to_set_comparison() -> void:
	var manager := GAME_MANAGER_SCRIPT.new()
	manager.seed_vertical_slice_data()
	manager.match_state.serving_home = false
	var comparison: Dictionary = {}
	for offset in range(50):
		var result: Resource = manager.resolve_active_rally(140000 + offset)
		var trace: Dictionary = result.analysis.get("shadow_reception", {})
		comparison = Dictionary(trace.get("summary", {})).get(
			"serve_to_set_comparison", {}
		)
		if bool(comparison.get("available", false)):
			break
	_check(
		bool(comparison.get("available", false))
			and comparison.has("receiver_agreement")
			and comparison.has("setter_agreement")
			and comparison.has("official_path_complete"),
		"Gate 14 compares actor ownership across the complete first-contact path",
	)
	_check(
		float(comparison.get("pass_destination_delta_meters", -1.0)) >= 0.0
			and comparison.has("pass_duration_delta_seconds")
			and not bool(comparison.get("official_events_mutated", true)),
		"Gate 14 measures pass spatial and timing differences without mutation",
	)
	var batch: Dictionary = SERVE_STYLE_CALIBRATION_SCRIPT.run(
		3, 140000, "serve_to_set_comparison_gate_14"
	)
	_check(
		int(batch.get("invalid_samples", 1)) == 0
			and float(batch.get("serve_to_set_comparison_rate", 0.0)) > 0.0
			and batch.has("serve_to_set_receiver_agreement_rate")
			and batch.has("serve_to_set_setter_agreement_rate"),
		"Gate 14 batch reports full-path agreement and divergence",
	)


func _test_gate_fifteen_disabled_rollout() -> void:
	var manager := GAME_MANAGER_SCRIPT.new()
	manager.seed_vertical_slice_data()
	manager.match_state.serving_home = false
	var result: Resource = manager.resolve_active_rally(150000)
	var trace: Dictionary = result.analysis.get("shadow_reception", {})
	var rollout: Dictionary = Dictionary(trace.get("summary", {})).get(
		"reception_rollout", {}
	)
	_check(
		not bool(rollout.get("flag_enabled", true))
			and str(rollout.get("selected_source", "")) == "official"
			and bool(rollout.get("activation_implemented", false)),
		"Gate 29 retains Gate 15's disabled default around an implemented branch",
	)
	_check(
		bool(rollout.get("official_identity_preserved", false))
			and int(rollout.get("selected_event_count", -1)) == result.events.size(),
		"Gate 15 preserves the complete official event identity and count",
	)
	var batch: Dictionary = SERVE_STYLE_CALIBRATION_SCRIPT.run(
		3, 150000, "disabled_rollout_gate_15"
	)
	_check(
		int(batch.get("invalid_samples", 1)) == 0
			and is_equal_approx(float(batch.get(
				"rollout_official_source_rate", 0.0
			)), 1.0)
			and is_zero_approx(float(batch.get(
				"rollout_flag_enabled_rate", 1.0
			)))
			and is_equal_approx(float(batch.get(
				"rollout_official_identity_preserved_rate", 0.0
			)), 1.0),
		"Gate 15 batch always selects untouched official events",
	)


func _test_gate_twenty_eight_and_twenty_nine_rollout_boundary() -> void:
	var manager := GAME_MANAGER_SCRIPT.new()
	manager.seed_vertical_slice_data()
	manager.match_state.serving_home = false
	var result: Resource = null
	var summary: Dictionary = {}
	var audit: Dictionary = {}
	for offset in range(120):
		result = manager.resolve_active_rally(280000 + offset)
		var trace: Dictionary = result.analysis.get("shadow_reception", {})
		summary = trace.get("summary", {})
		audit = RECEPTION_ROLLOUT_AUDIT_SCRIPT.evaluate(
			summary, manager.current_lineup()
		)
		if bool(audit.get("eligible", false)):
			break
	_check(
		bool(audit.get("eligible", false))
			and not str(audit.get("fingerprint", "")).is_empty()
			and not bool(audit.get("official_events_mutated", true))
			and bool(audit.get("source_state_unchanged", false)),
		"Gate 28 certifies a legal, continuous, state-safe reception candidate",
	)
	var invalid_summary := summary.duplicate(true)
	var invalid_playback: Dictionary = invalid_summary.get(
		"shadow_playback_candidate", {}
	)
	var invalid_events: Array = invalid_playback.get("events", [])
	if not invalid_events.is_empty():
		var invalid_reception: Dictionary = invalid_events[0]
		invalid_reception["actor_id"] = 999999
		invalid_events[0] = invalid_reception
		invalid_playback["events"] = invalid_events
		invalid_summary["shadow_playback_candidate"] = invalid_playback
	var invalid_audit := RECEPTION_ROLLOUT_AUDIT_SCRIPT.evaluate(
		invalid_summary, manager.current_lineup()
	)
	_check(
		not bool(invalid_audit.get("eligible", true))
			and "receiver_not_in_lineup" in Array(invalid_audit.get(
				"failure_reasons", []
			)),
		"Gate 28 rejects an otherwise valid candidate with illegal ownership",
	)
	var disabled := RALLY_ROLLOUT_POLICY_SCRIPT.select_reception_source(
		result.events, summary, manager.current_lineup(), false
	)
	var enabled := RALLY_ROLLOUT_POLICY_SCRIPT.select_reception_source(
		result.events, summary, manager.current_lineup(), true
	)
	_check(
		str(disabled.get("selected_source", "")) == "official"
			and str(enabled.get("selected_source", "")) \
				== "continuous_reception"
			and not Dictionary(enabled.get("selected_reception", {})).is_empty(),
		"Gate 29 promotes only an audited candidate when explicitly enabled",
	)


func _test_gate_thirty_development_live_reception() -> void:
	var manager := GAME_MANAGER_SCRIPT.new()
	manager.seed_vertical_slice_data()
	manager.match_state.serving_home = false
	var live_result: Resource = null
	var selected_seed := -1
	var live_summary: Dictionary = {}
	for offset in range(120):
		selected_seed = 300000 + offset
		live_result = manager.resolve_active_rally(selected_seed, true)
		var trace: Dictionary = live_result.analysis.get("shadow_reception", {})
		live_summary = trace.get("summary", {})
		if str(Dictionary(live_summary.get(
			"reception_rollout", {}
		)).get("selected_source", "")) == "continuous_reception":
			break
	var integration: Dictionary = live_summary.get(
		"live_reception_integration", {}
	)
	var live_reception: RallyEvent = null
	var later_home_set_seen := false
	for raw_event in live_result.events:
		var event := raw_event as RallyEvent
		if event == null:
			continue
		if event.event_type == RALLY_EVENT_SCRIPT.EventType.RECEPTION \
				and str(event.metadata.get("side", "")) == "home":
			live_reception = event
		elif event.event_type == RALLY_EVENT_SCRIPT.EventType.SET \
				and str(event.metadata.get("side", "")) == "home":
			later_home_set_seen = true
	_check(
		live_reception != null
			and bool(live_reception.metadata.get("continuous_reception", false))
			and bool(integration.get("applied", false))
			and str(integration.get("ball_status", "")) == "IN_FLIGHT"
			and float(integration.get("receiver_recovery_until", 0.0)) \
				> float(integration.get("simulation_time", 0.0)),
		"Gate 30 applies receiver, clock, recovery, and outgoing ball state",
	)
	_check(
		later_home_set_seen,
		"Gate 30 leaves setter and later contacts on legacy continuation",
	)
	var live_serve := live_result.events[0] as RallyEvent
	_check(
		live_serve != null
			and bool(live_serve.metadata.get(
				"continuous_reception_timing", false
			))
			and is_equal_approx(
				float(live_serve.metadata.get("contact_time", -1.0)),
				float(integration.get("simulation_time", -2.0))
			),
		"Gate 30 promotes canonical serve timing with the live reception clock",
	)
	var repeat_manager := GAME_MANAGER_SCRIPT.new()
	repeat_manager.seed_vertical_slice_data()
	repeat_manager.match_state.serving_home = false
	var repeat_result: Resource = repeat_manager.resolve_active_rally(
		selected_seed, true
	)
	var repeat_reception: RallyEvent = null
	for raw_event in repeat_result.events:
		var event := raw_event as RallyEvent
		if event != null \
				and event.event_type == RALLY_EVENT_SCRIPT.EventType.RECEPTION \
				and str(event.metadata.get("side", "")) == "home":
			repeat_reception = event
			break
	_check(
		live_reception != null and repeat_reception != null
			and live_reception.actor_id == repeat_reception.actor_id
			and is_equal_approx(live_reception.quality, repeat_reception.quality)
			and Dictionary(live_reception.metadata.get(
				"outgoing_trajectory", {}
			)) == Dictionary(repeat_reception.metadata.get(
				"outgoing_trajectory", {}
			)),
		"Gate 30 development rollout is deterministic for an equal seed",
	)
	var official_manager := GAME_MANAGER_SCRIPT.new()
	official_manager.seed_vertical_slice_data()
	official_manager.match_state.serving_home = false
	var official_result: Resource = official_manager.resolve_active_rally(selected_seed)
	var official_trace: Dictionary = official_result.analysis.get(
		"shadow_reception", {}
	)
	var official_summary: Dictionary = official_trace.get("summary", {})
	_check(
		str(Dictionary(official_summary.get(
			"reception_rollout", {}
		)).get("selected_source", "")) == "official",
		"Gate 30 keeps ordinary match resolution on the production-off path",
	)


func _test_gate_thirty_one_to_thirty_five_setter_boundary() -> void:
	var selected_summary: Dictionary = {}
	var selected_audit: Dictionary = {}
	var selected_lineup: RotationLineup = null
	for seed_value in range(300000, 300180):
		var manager := GAME_MANAGER_SCRIPT.new()
		manager.seed_vertical_slice_data()
		manager.match_state.serving_home = false
		var result: Resource = manager.resolve_active_rally(seed_value)
		var trace: Dictionary = result.analysis.get("shadow_reception", {})
		var summary: Dictionary = trace.get("summary", {})
		var response: Dictionary = summary.get("shadow_setter_response", {})
		if not bool(response.get("available", false)):
			continue
		var audit := SETTER_ROLLOUT_AUDIT_SCRIPT.evaluate(
			summary, manager.current_lineup()
		)
		if bool(audit.get("eligible", false)):
			selected_summary = summary
			selected_audit = audit
			selected_lineup = manager.current_lineup()
			break
	_check(
		not selected_summary.is_empty() and bool(selected_audit.get(
			"observation_boundary_valid", false
		)),
		"Gates 31 and 34 find an auditable setter candidate with a clean observation boundary",
	)
	var response: Dictionary = selected_summary.get("shadow_setter_response", {})
	var selected_id := int(response.get("selected_setter_id", -1))
	var selected_candidate: Dictionary = {}
	for raw_candidate in response.get("candidates", []):
		var candidate: Dictionary = raw_candidate
		if int(candidate.get("player_id", -1)) == selected_id:
			selected_candidate = candidate
			break
	var observation: Dictionary = selected_candidate.get("observation", {})
	var decision_score := PLAYER_OBSERVATION_SCRIPT.score_from_dict(observation)
	var changed_truth := selected_candidate.duplicate(true)
	changed_truth["true_arrival_margin"] = 999.0
	changed_truth["true_reachable"] = not bool(changed_truth.get(
		"true_reachable", false
	))
	_check(
		not observation.is_empty()
			and is_equal_approx(decision_score, float(selected_candidate.get(
				"selection_score", -1.0
			)))
			and is_equal_approx(
				PLAYER_OBSERVATION_SCRIPT.score_from_dict(observation),
				decision_score
			),
		"Gate 31 keeps setter selection invariant when hidden truth changes outside the observation",
	)
	_check(
		bool(response.get("selection_observation_only", false))
			and not str(response.get(
				"selected_observation_fingerprint", ""
			)).is_empty(),
		"Gate 32 records an observation-only setter decision fingerprint",
	)
	var disabled_rollout := RALLY_ROLLOUT_POLICY_SCRIPT.select_setter_source(
		selected_summary, selected_lineup, false
	)
	_check(
		str(disabled_rollout.get("selected_source", "")) == "official"
			and bool(disabled_rollout.get("candidate_available", false))
			and bool(disabled_rollout.get("official_identity_preserved", false)),
		"Gate 35 keeps an eligible setter candidate behind the disabled production boundary",
	)


func _test_gate_thirty_six_development_live_setter() -> void:
	var selected_seed := -1
	var live_result: Resource = null
	var live_summary: Dictionary = {}
	for seed_value in range(300000, 300240):
		var manager := GAME_MANAGER_SCRIPT.new()
		manager.seed_vertical_slice_data()
		manager.match_state.serving_home = false
		var candidate_result: Resource = manager.resolve_active_rally(seed_value, true)
		var trace: Dictionary = candidate_result.analysis.get(
			"shadow_reception", {}
		)
		var summary: Dictionary = trace.get("summary", {})
		if str(Dictionary(summary.get("setter_rollout", {})).get(
			"selected_source", "official"
		)) == "continuous_setter":
			selected_seed = seed_value
			live_result = candidate_result
			live_summary = summary
			break
	var integration: Dictionary = live_summary.get(
		"live_setter_integration", {}
	)
	var live_set: RallyEvent = null
	var later_attack_seen := false
	if live_result != null:
		for raw_event in live_result.events:
			var event := raw_event as RallyEvent
			if event == null:
				continue
			if event.event_type == RALLY_EVENT_SCRIPT.EventType.SET \
					and str(event.metadata.get("side", "")) == "home" \
					and bool(event.metadata.get("continuous_setter", false)):
				live_set = event
			elif event.event_type == RALLY_EVENT_SCRIPT.EventType.ATTACK \
					and str(event.metadata.get("side", "")) == "home":
				later_attack_seen = true
	_check(
		selected_seed >= 0 and live_set != null
			and bool(integration.get("applied", false))
			and int(integration.get("contact_number", 0)) == 2
			and bool(Dictionary(integration.get(
				"outgoing_set_state", {}
			)).get("applied", false)),
		"Gate 36 promotes one audited setter contact into persistent state",
	)
	_check(
		later_attack_seen,
		"Gate 36 leaves attack and later contacts on the legacy continuation",
	)
	var repeat_manager := GAME_MANAGER_SCRIPT.new()
	repeat_manager.seed_vertical_slice_data()
	repeat_manager.match_state.serving_home = false
	var repeat_result: Resource = repeat_manager.resolve_active_rally(
		selected_seed, true
	)
	var repeat_set: RallyEvent = null
	for raw_event in repeat_result.events:
		var event := raw_event as RallyEvent
		if event != null and event.event_type == RALLY_EVENT_SCRIPT.EventType.SET \
				and bool(event.metadata.get("continuous_setter", false)):
			repeat_set = event
			break
	_check(
		live_set != null and repeat_set != null
			and live_set.actor_id == repeat_set.actor_id
			and live_set.start_position.is_equal_approx(repeat_set.start_position)
			and is_equal_approx(
				float(live_set.metadata.get("event_time", -1.0)),
				float(repeat_set.metadata.get("event_time", -2.0))
			),
		"Gate 36 live setter ownership and contact are deterministic",
	)
	var official_manager := GAME_MANAGER_SCRIPT.new()
	official_manager.seed_vertical_slice_data()
	official_manager.match_state.serving_home = false
	var official_result: Resource = official_manager.resolve_active_rally(selected_seed)
	var official_continuous_set_seen := false
	for raw_event in official_result.events:
		var event := raw_event as RallyEvent
		if event != null and bool(event.metadata.get("continuous_setter", false)):
			official_continuous_set_seen = true
			break
	_check(
		not official_continuous_set_seen,
		"Gate 36 keeps ordinary match resolution on the production-off setter path",
	)


func _test_gate_thirty_seven_to_forty_one_attack_boundary() -> void:
	var selected_summary: Dictionary = {}
	var selected_audit: Dictionary = {}
	var selected_lineup: RotationLineup = null
	for seed_value in range(300000, 300360):
		var manager := GAME_MANAGER_SCRIPT.new()
		manager.seed_vertical_slice_data()
		manager.match_state.serving_home = false
		var result: Resource = manager.resolve_active_rally(seed_value)
		var trace: Dictionary = result.analysis.get("shadow_reception", {})
		var summary: Dictionary = trace.get("summary", {})
		var audit := ATTACK_ROLLOUT_AUDIT_SCRIPT.evaluate(
			summary, manager.current_lineup()
		)
		if bool(audit.get("eligible", false)):
			selected_summary = summary
			selected_audit = audit
			selected_lineup = manager.current_lineup()
			break
	_check(
		not selected_summary.is_empty()
			and bool(selected_audit.get("observation_boundary_valid", false)),
		"Gates 37 and 40 produce an auditable attack opportunity from perceived information",
	)
	var shadow: Dictionary = selected_summary.get("shadow_attack", {})
	var selected_assignment: Dictionary = shadow.get("selected_assignment", {})
	var setter_observation: Dictionary = shadow.get("setter_observation", {})
	var hitter_response: Dictionary = shadow.get("hitter_response", {})
	var hitter_observation: Dictionary = hitter_response.get("observation", {})
	var observed_opponents: Array = hitter_observation.get("perceived_opponents", [])
	var observations_are_perceived := not observed_opponents.is_empty()
	for raw_opponent in observed_opponents:
		var opponent: Dictionary = raw_opponent
		observations_are_perceived = observations_are_perceived \
			and opponent.has("perceived_position") \
			and not opponent.has("true_position") \
			and not opponent.has("authoritative_position")
	_check(
		not selected_assignment.is_empty()
			and not bool(selected_assignment.get(
				"decision_uses_authoritative_truth", true
			))
			and not bool(setter_observation.get(
				"decision_uses_authoritative_truth", true
			)),
		"Gate 38 ranks setter attack options without authoritative hitter geometry",
	)
	_check(
		observations_are_perceived
			and str(hitter_response.get("target_reason", "")) \
				== "largest perceived gap"
			and not bool(hitter_response.get(
				"decision_uses_authoritative_truth", true
			)),
		"Gate 38 removes exact opponent coordinates from hitter shot selection",
	)
	var progression := ATTACK_PROGRESSION_CALIBRATION_SCRIPT.run(12, 420000)
	var progression_checks: Dictionary = progression.get("progression", {})
	_check(
		bool(progression.get("fixture_valid", false))
			and bool(progression_checks.get("confidence_monotonic", false))
			and bool(progression_checks.get("perceived_reach_monotonic", false))
			and bool(progression_checks.get("true_reach_monotonic", false))
			and bool(progression_checks.get("action_count_monotonic", false))
			and bool(progression_checks.get("executable_action_monotonic", false)),
		"Gate 39 preserves monotonic hitter perception, access, and action progression",
	)
	var disabled_rollout := RALLY_ROLLOUT_POLICY_SCRIPT.select_attack_source(
		selected_summary, selected_lineup, false
	)
	_check(
		str(disabled_rollout.get("selected_source", "")) == "official"
			and bool(disabled_rollout.get("candidate_available", false))
			and bool(disabled_rollout.get("official_identity_preserved", false)),
		"Gate 41 keeps eligible attacks behind the disabled production boundary",
	)


func _test_gate_forty_two_development_live_attack() -> void:
	const LIVE_ATTACK_SEED := 300469
	var manager := GAME_MANAGER_SCRIPT.new()
	manager.seed_vertical_slice_data()
	manager.match_state.serving_home = false
	var result: Resource = manager.resolve_active_rally(LIVE_ATTACK_SEED, true)
	var trace: Dictionary = result.analysis.get("shadow_reception", {})
	var summary: Dictionary = trace.get("summary", {})
	var rollout: Dictionary = summary.get("attack_rollout", {})
	var integration: Dictionary = summary.get("live_attack_integration", {})
	var live_attack: RallyEvent = null
	var legacy_block_seen := false
	for raw_event in result.events:
		var event := raw_event as RallyEvent
		if event == null:
			continue
		if event.event_type == RALLY_EVENT_SCRIPT.EventType.ATTACK \
				and bool(event.metadata.get("continuous_attack", false)):
			live_attack = event
		elif event.event_type == RALLY_EVENT_SCRIPT.EventType.BLOCK \
				and str(event.metadata.get("side", "")) == "opponent":
			legacy_block_seen = true
	_check(
		str(rollout.get("selected_source", "")) == "continuous_attack"
			and live_attack != null
			and bool(integration.get("applied", false))
			and int(integration.get("contact_number", 0)) == 3
			and str(integration.get("ball_status", "")) == "IN_FLIGHT",
		"Gate 42 promotes one audited hitter contact and outgoing attack flight",
	)
	_check(
		legacy_block_seen,
		"Gate 42 leaves blocking and later contacts on the legacy continuation",
	)
	var repeat_manager := GAME_MANAGER_SCRIPT.new()
	repeat_manager.seed_vertical_slice_data()
	repeat_manager.match_state.serving_home = false
	var repeat_result: Resource = repeat_manager.resolve_active_rally(
		LIVE_ATTACK_SEED, true
	)
	var repeat_attack: RallyEvent = null
	for raw_event in repeat_result.events:
		var event := raw_event as RallyEvent
		if event != null and event.event_type == RALLY_EVENT_SCRIPT.EventType.ATTACK \
				and bool(event.metadata.get("continuous_attack", false)):
			repeat_attack = event
			break
	_check(
		live_attack != null and repeat_attack != null
			and live_attack.actor_id == repeat_attack.actor_id
			and live_attack.start_position.is_equal_approx(repeat_attack.start_position)
			and live_attack.end_position.is_equal_approx(repeat_attack.end_position)
			and is_equal_approx(
				float(live_attack.metadata.get("event_time", -1.0)),
				float(repeat_attack.metadata.get("event_time", -2.0))
			),
		"Gate 42 live hitter ownership, timing, and target are deterministic",
	)
	var official_manager := GAME_MANAGER_SCRIPT.new()
	official_manager.seed_vertical_slice_data()
	official_manager.match_state.serving_home = false
	var official_result: Resource = official_manager.resolve_active_rally(
		LIVE_ATTACK_SEED
	)
	var official_continuous_attack_seen := false
	for raw_event in official_result.events:
		var event := raw_event as RallyEvent
		if event != null and bool(event.metadata.get("continuous_attack", false)):
			official_continuous_attack_seen = true
			break
	_check(
		not official_continuous_attack_seen,
		"Gate 42 keeps ordinary match resolution on the production-off attack path",
	)


func _test_gate_twenty_one_setter_handoffs() -> void:
	var report: Dictionary = SETTER_HANDOFF_CALIBRATION_SCRIPT.run(6, 210000)
	var fixtures: Dictionary = report.get("by_fixture", {})
	var natural: Dictionary = fixtures.get("natural", {})
	var forced: Dictionary = fixtures.get("forced_setter_first_contact", {})
	var forced_late: Dictionary = fixtures.get("forced_late_intended_setter", {})
	_check(
		bool(report.get("fixture_valid", false))
			and int(natural.get("available", 0)) > 0
			and int(forced.get("available", 0)) > 0
			and int(forced_late.get("available", 0)) > 0,
		"Gate 21 audits natural and forced second-contact ownership",
	)
	_check(
		is_equal_approx(float(report.get("forced_emergency_intent_rate", 0.0)), 1.0)
			and not Dictionary(forced.get("handoff_reasons", {})).is_empty(),
		"Gate 21 proves setter first contact transfers tactical intent",
	)
	_check(
		float(report.get("forced_late_handoff_rate", 0.0)) > 0.0
			and is_equal_approx(float(report.get(
				"forced_late_handoff_valid_rate", 0.0
			)), 1.0)
			and int(Dictionary(report.get("overall", {})).get("invalid", 1)) == 0,
		"Gate 21 validates every selected owner against the action candidates",
	)


func _test_gate_twenty_two_setter_progression() -> void:
	var report: Dictionary = SETTER_PROGRESSION_CALIBRATION_SCRIPT.run(8, 220000)
	var tiers: Dictionary = report.get("by_setter_tier", {})
	var developing: Dictionary = tiers.get("developing", {})
	var elite: Dictionary = tiers.get("elite", {})
	var progression: Dictionary = report.get("progression", {})
	_check(
		bool(report.get("fixture_valid", false))
			and int(developing.get("available", 0)) > 0
			and int(elite.get("available", 0)) > 0,
		"Gate 22 compares setter tiers over identical serves and passes",
	)
	_check(
		bool(progression.get("confidence_monotonic", false))
			and bool(progression.get("action_count_monotonic", false))
			and bool(progression.get("controlled_set_rate_monotonic", false))
			and bool(progression.get("quick_tempo_rate_monotonic", false))
			and bool(progression.get("jump_set_rate_monotonic", false)),
		"Gate 22 makes setter development preserve or expand usable options",
	)
	_check(
		bool(progression.get("elite_has_more_options_than_developing", false))
			and float(elite.get("confidence_mean", 0.0))
				> float(developing.get("confidence_mean", 0.0)),
		"Gate 22 proves elite setters read better and own more actions",
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
	_check(manager.opponent_team.players.size() == 7, "opponent has a rotation-ready seven-player profile")
	_check(manager.opponent_team.on_court_players().size() == 6, "opponent fields six players")
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
				and not (event.metadata.get("setter_pull", {}) as Dictionary).is_empty()
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
	player.tempo_control = 81
	player.set_disguise = 76
	player.hand_control = 84
	player.arm_speed = 88
	player.tooling = 72
	player.feinting = 69
	player.finesse = 79
	player.shot_variety = 83
	player.dig_control = 64
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
	_check(restored.tempo_control == 81 and restored.set_disguise == 76 \
			and restored.hand_control == 84,
		"setting control attributes survive player serialization")
	_check(restored.tooling == 72 and restored.feinting == 69 and restored.finesse == 79 \
			and restored.shot_variety == 83 and restored.dig_control == 64,
		"attack-solution and dig-control attributes survive player serialization")
	var low_power := VolleyballPlayer.new()
	low_power.mass_kg = 65.0
	low_power.attack_power = 55
	low_power.explosiveness = 40
	low_power.transition_speed = 42
	low_power.arm_speed = 38
	low_power.approach_timing = 45
	var usable_power := VolleyballPlayer.new()
	usable_power.mass_kg = 100.0
	usable_power.attack_power = 55
	usable_power.explosiveness = 82
	usable_power.transition_speed = 76
	usable_power.arm_speed = 88
	usable_power.approach_timing = 84
	_check(usable_power.usable_attack_power() > low_power.usable_attack_power(),
		"usable hitting power derives from body and approach qualities, not strength alone")
	var limited_range := VolleyballPlayer.new()
	limited_range.acceleration = 35
	limited_range.lateral_speed = 35
	limited_range.anticipation = 35
	var broad_range := VolleyballPlayer.new()
	broad_range.acceleration = 85
	broad_range.lateral_speed = 85
	broad_range.anticipation = 85
	_check(broad_range.baseline_defensive_range() > limited_range.baseline_defensive_range(),
		"displayed defensive range is derived from movement, anticipation, and reach")
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
	var generated_a := PLAYER_GENERATOR_SCRIPT.generate_roster(
		"North America", "Club", 73001
	)
	var generated_b := PLAYER_GENERATOR_SCRIPT.generate_roster(
		"North America", "Club", 73001
	)
	var distinct_bodies := {}
	var deterministic_bodies := generated_a.size() == generated_b.size()
	for index in range(generated_a.size()):
		var first := generated_a[index]
		var second := generated_b[index]
		distinct_bodies["%.1f:%.1f:%.1f" % [
			first.height_cm, first.mass_kg, first.wingspan_cm,
		]] = true
		deterministic_bodies = deterministic_bodies \
			and is_equal_approx(first.height_cm, second.height_cm) \
			and is_equal_approx(first.mass_kg, second.mass_kg) \
			and is_equal_approx(first.wingspan_cm, second.wingspan_cm)
	_check(
		deterministic_bodies and distinct_bodies.size() > 5,
		"seeded roster generation creates reproducible individual body dimensions",
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


func _test_setter_failure_taxonomy() -> void:
	var recognition := SETTER_FAILURE_CLASSIFIER_SCRIPT.classify({
		"true_reachable": false,
		"perceived_reachable": false,
		"vertical_margin_meters": 0.20,
		"contact_height_meters": 2.10,
		"standing_reach_meters": 2.30,
		"required_takeoff_time_seconds": 0.20,
		"final_available_time_seconds": 0.18,
		"first_decision_delay_seconds": 0.35,
		"time_remaining_after_first_decision_seconds": 0.30,
		"final_center_distance_deficit_meters": 0.48,
		"contact_reach_meters": 0.42,
		"final_readiness": 1.0,
		"final_balance": 1.0,
	})
	_check(
		str(recognition.get("primary_cause", "")) == "recognition_delay"
			and "insufficient_movement_time" in Array(recognition.get(
				"contributing_causes", []
			)),
		"Gate 26 separates recognition delay from its movement consequence",
	)
	var vertical := SETTER_FAILURE_CLASSIFIER_SCRIPT.classify({
		"true_reachable": false,
		"perceived_reachable": false,
		"vertical_margin_meters": -0.12,
		"contact_height_meters": 2.70,
		"standing_reach_meters": 2.30,
		"required_takeoff_time_seconds": 0.18,
		"final_available_time_seconds": 0.40,
		"first_decision_delay_seconds": 0.08,
		"time_remaining_after_first_decision_seconds": 0.50,
		"final_center_distance_deficit_meters": 0.0,
		"contact_reach_meters": 0.45,
		"final_readiness": 1.0,
		"final_balance": 1.0,
	})
	_check(
		str(vertical.get("primary_cause", "")) == "vertical_access",
		"Gate 26 identifies a vertical envelope failure independently",
	)


func _test_tactical_playback_reset_on_lineup_change() -> void:
	var manager := GAME_MANAGER_SCRIPT.new()
	manager.seed_vertical_slice_data()
	var court := TacticalCourt.new()
	get_root().add_child(court)
	court.set_lineup(manager.rotations[1], manager.players)
	court.set_coverage_zones_visible(false)
	_check(not court.coverage_zones_visible,
		"match playback can suppress editable coverage-zone overlays")
	var attack_event := RALLY_EVENT_SCRIPT.new()
	attack_event.event_type = RALLY_EVENT_SCRIPT.EventType.ATTACK
	attack_event.actor_id = 2
	attack_event.start_position = Vector2(0.2, 0.65)
	attack_event.end_position = Vector2(0.2, 0.48)
	var block_event := RALLY_EVENT_SCRIPT.new()
	block_event.event_type = RALLY_EVENT_SCRIPT.EventType.BLOCK
	block_event.actor_id = 3
	block_event.start_position = Vector2(0.2, 0.52)
	block_event.end_position = Vector2(0.2, 0.50)
	court.animate_spatial_transition(attack_event, block_event, 0.01)
	_check(court.contact_overlay_event == block_event,
		"attack playback exposes block coverage during the same contact window")
	court.clear_rally_playback()
	_check(court.contact_overlay_event == null,
		"resetting rally playback clears the simultaneous block overlay")
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
