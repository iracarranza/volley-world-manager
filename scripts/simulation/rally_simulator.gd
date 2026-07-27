class_name RallySimulator
extends RefCounted

const RallyEventModel := preload("res://scripts/models/rally_event.gd")
const RallyResultModel := preload("res://scripts/models/rally_result.gd")
const ExplanationText := preload("res://scripts/data/rally_explanations.gd")
const CoverageModel := preload("res://scripts/simulation/coverage_calculator.gd")
const DefensiveZoneModel := preload("res://scripts/models/defensive_zone.gd")
const BallTrajectoryModel := preload("res://scripts/models/ball_trajectory.gd")
const AttributeProfiles := preload("res://scripts/systems/attribute_profile_system.gd")
const Familiarity := preload("res://scripts/systems/familiarity_system.gd")
const MAX_EXCHANGES: int = 4

const OPPONENT_SERVE: float = 0.63
const OPPONENT_BLOCK: float = 0.61
const OPPONENT_DEFENSE: float = 0.58

var rng := RandomNumberGenerator.new()
var rally_clock: float = 0.0
var live_positions: Dictionary = {}


func resolve(
	players: Array[VolleyballPlayer],
	lineup: RotationLineup,
	active_play: OffensivePlay,
	opponent_team: Resource,
	defensive_plan: Resource,
	home_serving: bool,
	seed_value: int,
) -> Resource:
	rng.seed = seed_value
	rally_clock = 0.0
	live_positions = _initial_home_positions(lineup, defensive_plan, not home_serving)
	var result: Resource = RallyResultModel.new()

	if "active_play_name" in result:
		result.set("active_play_name", active_play.play_name if active_play != null else "Default T3 Outside")

	if home_serving:
		return _resolve_home_serve(
			result, players, lineup, opponent_team, defensive_plan
		)
	var opponent_lineup: RotationLineup = opponent_team.current_lineup()
	var opponent_server := opponent_team.player_by_id(
		opponent_lineup.player_at_slot(1) if opponent_lineup != null else -1
	) as VolleyballPlayer
	if opponent_server == null:
		opponent_server = opponent_team.best_server() as VolleyballPlayer
	var server_name := opponent_server.display_name
	var setter := _player_by_id(players, lineup.active_setter_id())
	var serve_quality := clampf(
		_power_rating(opponent_server, "serve_power") * 0.28
		+ _rating(opponent_server, "serve_technique") * 0.13
		+ _rating(opponent_server, "serve_placement") * 0.07
		+ _rating(opponent_server, "serve_consistency") * 0.12
		+ _rating(opponent_server, "serve_aggression") * 0.04
		+ _serve_style_proficiency(opponent_server) * 0.08
		+ rng.randf_range(-0.18, 0.18), 0.05, 0.98
	)
	var opponent_risk := _rating(opponent_server, "serve_aggression")
	var serve_error_chance := clampf(0.025 + opponent_risk * 0.08 \
		- _rating(opponent_server, "serve_consistency") * 0.055 \
		- _serve_style_proficiency(opponent_server) * 0.02, 0.01, 0.15)
	var serve_error := rng.randf() < serve_error_chance
	var intended_target := str(opponent_team.tendencies.get("serve_target", "Zone 5"))
	var serve_landing := _serve_landing_point(
		intended_target, opponent_server, players, lineup, true
	)
	var serve_time := _serve_flight_time(opponent_server, serve_quality)
	var serve_trajectory := _ball_trajectory(
		"serve", Vector2(0.80, 0.08), serve_landing,
		serve_time, 2.8
	)
	_add_event(result, RallyEventModel.EventType.SERVE, opponent_server.id, server_name,
		Vector2(0.80, 0.08), serve_landing, not serve_error, serve_quality,
		"%s serve" % opponent_server.primary_serve_style if not serve_error else "Serve misses",
		"%d%% pressure toward the receiver." % roundi(serve_quality * 100.0) \
		if not serve_error else "The serve does not enter the court.", {
			"side": "opponent", "target": intended_target,
			"server_id": opponent_server.id, "server_slot": 1,
			"serve_style": opponent_server.primary_serve_style,
			"flight_time": serve_time,
			"event_time": 0.0, "contact_time": serve_time,
			"outgoing_trajectory": serve_trajectory,
		})
	rally_clock = serve_time

	if serve_error:
		return _finish_serve_error(result, server_name)

	var reception_claim: Dictionary = CoverageModel.choose_claimant(
		_lineup_players(players, lineup),
		defensive_plan.zones_for(DefensiveZoneModel.ZoneType.SERVE_RECEIVE),
		serve_landing, serve_time, "reception",
	)
	var receiver := reception_claim.get("player") as VolleyballPlayer
	var receiver_arrived := receiver != null
	if receiver == null:
		receiver = _nearest_reception_player(players, lineup, defensive_plan, serve_landing)
	var arrival: Dictionary = reception_claim.get("arrival", {})
	var arrival_bonus := clampf(
		float(arrival.get("arrival_margin", -1.0)) * 0.07, -0.16, 0.12
	)
	var support_count := int(reception_claim.get("support_count", 0))
	var support_bonus := minf(float(support_count) * 0.025, 0.075)
	var seam_conflict := bool(reception_claim.get("seam_conflict", false))
	var seam_penalty := 0.09 if seam_conflict else 0.0
	var reception_base := _rating(receiver, "reception") * 0.65 \
		+ _rating(receiver, "ball_control") * 0.20 \
		+ _rating(receiver, "composure") * 0.15

	var final_reception_quality = clampf(reception_base - serve_quality * 0.48 \
		- CoverageModel.reception_body_penalty(receiver, arrival, serve_quality) \
		+ arrival_bonus + support_bonus - seam_penalty \
		+ rng.randf_range(-0.14, 0.14) + 0.30,
		0.0, 1.0)

	if not receiver_arrived:
		final_reception_quality = minf(final_reception_quality, 0.12)

	if "reception_quality" in result:
		result.set("reception_quality", final_reception_quality)

	var reception_success: bool = receiver_arrived and final_reception_quality >= 0.18
	var receiver_start: Vector2 = live_positions.get(receiver.id, serve_landing)
	var receiver_move_time := _movement_time(
		receiver, receiver_start, serve_landing, "lateral"
	)
	live_positions[receiver.id] = serve_landing
	var preferred_release: Vector2 = defensive_plan.setter_release_target(lineup.active_setter_id()) \
		if defensive_plan != null else Vector2(0.50, 0.60)
	var desired_pass_target: Vector2 = _desired_pass_target(preferred_release, serve_landing)

	var reception_pass := _reception_pass_result(
		receiver, receiver_start, serve_landing,
		desired_pass_target,
		Vector2(0.80, 0.08), serve_quality, arrival,
		final_reception_quality
	)

	var pass_trajectory: Dictionary = reception_pass.trajectory
	_add_event(result, RallyEventModel.EventType.RECEPTION, receiver.id, receiver.display_name,
		serve_landing, reception_pass.destination, reception_success,
		final_reception_quality, "%s receives" % receiver.display_name,
		"%d%% reception quality. %s %s" % [
			roundi(final_reception_quality * 100.0),
			_quality_phrase(final_reception_quality),
			_arrival_phrase(arrival, receiver_arrived, support_count) \
			+ (" Equal-priority passers hesitated at the seam." if seam_conflict else ""),
		], {"side": "home", "landing": serve_landing,
			"flight_time": serve_time, "arrival": arrival,
			"support_count": support_count, "seam_conflict": seam_conflict,
			"claim_margin": float(reception_claim.get("claim_margin", 1.0)),
			"movement_start": receiver_start,
			"movement_duration": receiver_move_time,
			"event_time": rally_clock,
			"incoming_trajectory": serve_trajectory,
			"outgoing_trajectory": pass_trajectory,
			"body_alignment": reception_pass.body_alignment,
			"platform_feasibility": reception_pass.platform_feasibility,
			"contact_posture": reception_pass.contact_posture,
			"desired_pass_target": desired_pass_target,
			"setter_release_target": preferred_release,
			"actual_pass_target": reception_pass.destination})

	if seam_conflict and "key_factors" in result:
		var factors = result.get("key_factors")
		if factors is Array:
			factors.append(ExplanationText.factor("seam_conflict"))

	if not reception_success:
		return _finish(result, "ace", false, receiver.id, {
			"server": server_name,
		})
	setter = _second_contact_setter(
		players, lineup, defensive_plan, receiver.id
	)
	var set_contact: Vector2 = reception_pass.destination
	var second_contact_window := float(pass_trajectory.get("duration", 0.68))
	var setter_choice := _spatial_setter_choice(
		players, lineup, defensive_plan, receiver.id, setter,
		set_contact, second_contact_window
	)
	setter = setter_choice.player as VolleyballPlayer
	var setter_start: Vector2 = setter_choice.start
	var setter_move_time := float(setter_choice.travel_time)
	var setter_arrival_margin := second_contact_window - setter_move_time
	var emergency_setter := setter != null and setter.id != lineup.active_setter_id()

	var follow_threshold := 0.22 + _rating(setter, "decision_making") * 0.35 \
		+ _rating(setter, "tactical_discipline") * 0.18

	var play_followed = active_play != null \
		and final_reception_quality >= 0.42 \
		and rng.randf() < follow_threshold

	if "play_was_followed" in result:
		result.set("play_was_followed", play_followed)

	var assignment := _choose_assignment(active_play, play_followed, players, lineup)
	var hitter := _player_by_id(players, assignment.player_id) if assignment != null else null
	if hitter == null:
		hitter = _fallback_hitter(players, lineup)
		assignment = _fallback_assignment(hitter, lineup)

	if "key_factors" in result:
		var factors = result.get("key_factors")
		if factors is Array:
			if active_play == null:
				factors.append(ExplanationText.factor("default_offense"))
			else:
				factors.append(ExplanationText.factor("play_followed" if play_followed else "play_abandoned"))
			factors.append(ExplanationText.factor("good_pass" if final_reception_quality >= 0.58 else "poor_pass"))

	var active_play_name_str = result.get("active_play_name") if "active_play_name" in result else "Default T3 Outside"

	# FIX ARTIFACT 2: Pure decision metadata event - no fake movement trajectory outputted
	_add_event(result, RallyEventModel.EventType.SET_DECISION, setter.id, setter.display_name,
		set_contact, set_contact, true,
		final_reception_quality,
		"Emergency setter decision" if emergency_setter else "Setter decision",
		"Stays with %s." % active_play_name_str if play_followed \
		else ("Uses the default T3 ball to the nearest outside pin." \
		if active_play == null else "Moves to the safest available option."),
		{"side": "home", "emergency_setter": emergency_setter,
			"first_contact_id": receiver.id,
			"event_time": rally_clock, "deadline": rally_clock + second_contact_window,
			"incoming_trajectory": pass_trajectory})

	var tempo_demand := float(3 - assignment.tempo) * 0.055 \
		* lerpf(1.0, 0.65, _rating(setter, "tempo_control"))
	var set_target := CourtConstants.lane_target(assignment.lane)
	var set_geometry := _set_geometry(
		setter, setter_start, set_contact, set_target, preferred_release
	)
	var set_base: float = _rating(setter, "set_accuracy") * 0.42 \
		+ _rating(setter, "court_vision") * 0.20 \
		+ _rating(setter, "hand_control") * 0.10 \
		+ _rating(setter, "tempo_control") * 0.08 \
		+ _rating(setter, "composure") * 0.10 \
		+ final_reception_quality * 0.28 - tempo_demand \
		+ clampf(setter_arrival_margin * 0.18, -0.42, 0.08) \
		- float(set_geometry.difficulty) + (Familiarity.execution_modifier(setter) - 1.0) * 0.16

	var final_set_quality = clampf(set_base + rng.randf_range(-0.12, 0.12), 0.0, 1.0)
	if "set_quality" in result:
		result.set("set_quality", final_set_quality)

	var set_flight_time: float = float(
		[0.34, 0.48, 0.70, 1.02][clampi(assignment.tempo, 0, 3)]
	)

	# FIX ARTIFACT 3: Real world 3D trajectory height calculated dynamically
	var set_trajectory := _ball_trajectory(
		"set", set_contact, set_target, set_flight_time,
		lerpf(2.5, 3.6, final_set_quality), rally_clock + second_contact_window
	)
	_add_event(result, RallyEventModel.EventType.SET, setter.id, setter.display_name,
		set_contact, set_target, final_set_quality >= 0.24,
		final_set_quality, "Set to %s" % assignment.lane,
		("T%d set for %s · %d%% accuracy." % [
			assignment.tempo, hitter.display_name,
			roundi(final_set_quality * 100.0),
		]) + (" Emergency second-contact assignment activated." if emergency_setter else "")
		+ (" Arrived %.2fs before contact." % setter_arrival_margin
			if setter_arrival_margin >= 0.0 else
			" Arrived %.2fs late; set control was reduced." % absf(setter_arrival_margin)),
		{"side": "home", "emergency_setter": emergency_setter,
			"first_contact_id": receiver.id, "movement_start": setter_start,
			"movement_duration": setter_move_time,
			"arrival_margin": setter_arrival_margin,
			"deadline": rally_clock + second_contact_window,
			"event_time": rally_clock + second_contact_window,
			"incoming_trajectory": pass_trajectory,
			"outgoing_trajectory": set_trajectory,
			"set_distance_meters": set_geometry.distance_meters,
			"set_angle_degrees": set_geometry.angle_degrees,
			"release_distance_meters": set_geometry.release_distance_meters,
			"body_orientation_fit": set_geometry.body_orientation_fit,
			"set_balance": set_geometry.set_balance,
			"set_stability": set_geometry.set_stability})
	live_positions[setter.id] = set_contact
	rally_clock += second_contact_window
	if assignment.tempo <= 1 and "key_factors" in result:
		var factors = result.get("key_factors")
		if factors is Array: factors.append(ExplanationText.factor("fast_tempo"))

	var hitter_start: Vector2 = live_positions.get(
		hitter.id, CourtConstants.slot_position(lineup.slot_for_player(hitter.id))
	)
	var hitter_move_time := _movement_time(
		hitter, hitter_start, set_target, "transition"
	)
	var hitter_arrival_margin := float(set_flight_time) - hitter_move_time
	var approach_fit := _rating(hitter, "approach_timing") * 0.32 \
		+ _rating(hitter, "transition_speed") * 0.18
	var attack_base: float = _rating(hitter, "attack_accuracy") * 0.38 \
		+ _power_rating(hitter, "attack_power") * 0.24 \
		+ _rating(hitter, "decision_making") * 0.13 \
		+ approach_fit + final_set_quality * 0.25 - tempo_demand \
		+ clampf(hitter_arrival_margin * 0.22, -0.58, 0.08) \
		+ Familiarity.attack_geometry(hitter, assignment.lane) \
		+ (Familiarity.execution_modifier(hitter) - 1.0) * 0.14

	var final_attack_quality = clampf(attack_base + rng.randf_range(-0.16, 0.16), 0.0, 1.0)
	if "attack_quality" in result:
		result.set("attack_quality", final_attack_quality)

	var hit_type := _hit_type(assignment, hitter)
	var attack_choice := _choose_home_attack_target(
		hitter, assignment.lane, hit_type, opponent_team
	)
	var attack_target: Vector2 = attack_choice.target
	var attack_flight := _attack_flight_time(final_attack_quality, hit_type)
	var attack_trajectory := _ball_trajectory(
		"attack", set_target, attack_target, attack_flight, 2.9,
		rally_clock + set_flight_time
	)
	_add_event(result, RallyEventModel.EventType.ATTACK, hitter.id, hitter.display_name,
		set_target, attack_target, final_attack_quality >= 0.25,
		final_attack_quality, "%s: %s" % [hitter.display_name, hit_type],
		("%s from %s at T%d · %d%% contact quality." % [
			hit_type, assignment.lane, assignment.tempo,
			roundi(final_attack_quality * 100.0),
		]) + (" Arrived %.2fs before the ball." % hitter_arrival_margin
			if hitter_arrival_margin >= 0.0 else
			" Arrived %.2fs late and lost the approach window." % absf(hitter_arrival_margin)),
		{"side": "home", "lane": assignment.lane, "tempo": assignment.tempo,
			"attack_type": hit_type, "attack_direction": attack_choice.direction,
			"target_reason": attack_choice.reason, "movement_start": hitter_start,
			"movement_duration": hitter_move_time,
			"arrival_margin": hitter_arrival_margin,
			"deadline": rally_clock + float(set_flight_time),
			"event_time": rally_clock + float(set_flight_time),
			"set_flight_time": float(set_flight_time),
			"incoming_trajectory": set_trajectory,
			"outgoing_trajectory": attack_trajectory})
	live_positions[hitter.id] = set_target
	rally_clock += float(set_flight_time)
	if final_attack_quality < 0.29:
		return _finish(result, "attack_error", false, hitter.id, {
			"hitter": hitter.display_name,
		})

# Determine opponent blocker based on attack lane/position (spatial mirroring)
	var opponent_block_info := _choose_opponent_blockers(
		opponent_team, set_target.x, assignment.tempo, assignment.lane
	)
	var opponent_blocker := opponent_block_info.primary as VolleyballPlayer
	var assisting_blocker := opponent_block_info.assist as VolleyballPlayer

	if opponent_blocker == null and opponent_team != null and opponent_team.has_method("best_blocker"):
		opponent_blocker = opponent_team.call("best_blocker") as VolleyballPlayer

	var primary_rating: float = 0.5
	if opponent_blocker != null:
		primary_rating = _rating(opponent_blocker, "block_timing") * 0.48 \
			+ _available_jump_rating(opponent_blocker) * 0.22 \
			+ _body_reach_rating(opponent_blocker) * 0.10

	var assist_rating: float = 0.0
	if assisting_blocker != null:
		assist_rating = (_rating(assisting_blocker, "block_timing") * 0.35 \
			+ _available_jump_rating(assisting_blocker) * 0.15) * float(opponent_block_info.assist_close)

	var block_strength: float = clampf(
		primary_rating + assist_rating \
		+ rng.randf_range(-0.12, 0.12) \
		- float(3 - assignment.tempo) * 0.04,
		0.12, 0.95
	)

	var adaptation_bonus := _opponent_block_adaptation_bonus(
		opponent_team, assignment.lane, assignment.tempo
	)
	block_strength = clampf(block_strength + adaptation_bonus, 0.12, 0.96)
	if adaptation_bonus >= 0.035 and "key_factors" in result:
		var factors = result.get("key_factors")
		if factors is Array: factors.append(ExplanationText.factor("opponent_adapted"))

	var block_margin: float = block_strength - final_attack_quality \
		+ rng.randf_range(-0.15, 0.15)
	var block_outcome := "stuff" if block_margin > 0.12 else (
		"recycle" if block_margin > -0.10 else "miss"
	)
	var blocked := block_outcome == "stuff"
	var recycled := block_outcome == "recycle"
	var recycle_target := _attack_coverage_target(set_target, block_strength) \
		if recycled else Vector2(set_target.x, 0.50)
	var net_contact := Vector2(set_target.x, 0.50)

	# Try to safely update the previous attack event's outgoing trajectory
	var res_events = result.get("events") if "events" in result else []
	if res_events.size() > 0:
		var attack_event = res_events[-1]
		if attack_event != null and "metadata" in attack_event:
			var emeta = attack_event.get("metadata")
			if emeta is Dictionary:
				emeta["outgoing_trajectory"] = _ball_trajectory(
					"attack_to_block", set_target, net_contact, 0.22, 2.5,
					float(emeta.get("event_time", rally_clock))
				)

	var post_block_target := recycle_target if recycled else attack_target
	if blocked:
		post_block_target = Vector2(set_target.x, 0.57)
	var opponent_block_trajectory := _ball_trajectory(
		"block_deflection", net_contact, post_block_target,
		0.24 if recycled else 0.18, 2.2, rally_clock
	)
	var opponent_block_segments: Array[Dictionary] = [
		_block_coverage_segment(
			set_target.x, opponent_blocker, block_strength, block_strength
		)
	]

	var incoming_traj = {}
	if res_events.size() > 0 and "metadata" in res_events[-1] and res_events[-1].get("metadata") is Dictionary:
		incoming_traj = res_events[-1].get("metadata").get("outgoing_trajectory", {})

	_add_event(result, RallyEventModel.EventType.BLOCK, opponent_blocker.id,
		opponent_blocker.display_name,
		Vector2(set_target.x, 0.47), recycle_target, block_outcome != "miss",
		block_strength, "Block forms at %s" % assignment.lane,
		"%d%% close speed; the blockers seal the chosen lane.%s" % [
			roundi(block_strength * 100.0),
			" Scouting anticipated this pattern." if adaptation_bonus >= 0.035 else "",
		], {"side": "opponent", "lane": assignment.lane,
			"adaptation_bonus": adaptation_bonus, "outcome": block_outcome,
			"deflection_target": recycle_target,
			"coverage_segments": opponent_block_segments,
			"event_time": rally_clock,
			"incoming_trajectory": incoming_traj,
			"outgoing_trajectory": opponent_block_trajectory})
	if blocked:
		return _finish(result, "blocked", false, hitter.id, {
			"hitter": hitter.display_name,
		}, "strong_block")
	if recycled:
		var coverage_result := _resolve_attack_coverage(
			players, lineup, defensive_plan, hitter, recycle_target, block_strength
		)
		var coverer := coverage_result.get("player") as VolleyballPlayer
		var coverage_success := bool(coverage_result.get("success", false))
		var coverage_quality := float(coverage_result.get("quality", 0.0))
		var coverer_start: Vector2 = live_positions.get(
			coverer.id, recycle_target
		) if coverer != null else recycle_target
		var coverer_move_time := _movement_time(
			coverer, coverer_start, recycle_target, "lateral"
		) if coverer != null else 4.0
		if coverer != null:
			live_positions[coverer.id] = recycle_target
		_add_event(result, RallyEventModel.EventType.DEFENSE,
			coverer.id if coverer != null else -1,
			coverer.display_name if coverer != null else "Attack coverage",
			recycle_target, recycle_target + Vector2(0.04, -0.05),
			coverage_success, coverage_quality,
			"%s covers the block touch" % (
				coverer.display_name if coverer != null else "Nobody"
			),
			"%d%% recycle control from the assigned attack-coverage shape." % roundi(
				coverage_quality * 100.0
			), {"side": "home", "coverage": "attack",
				"blocked_hitter_id": hitter.id,
				"movement_start": coverer_start,
				"movement_duration": coverer_move_time})
		if not coverage_success:
			return _finish(result, "blocked", false, hitter.id, {
				"hitter": hitter.display_name,
			})
		if "key_factors" in result:
			var factors = result.get("key_factors")
			if factors is Array: factors.append(ExplanationText.factor("attack_recycled"))
		return _resolve_home_continuation(
			result, players, lineup, coverer, recycle_target,
			opponent_team, defensive_plan, 1,
		)

	var opponent_defense := _choose_opponent_defender(
		opponent_team, attack_target, attack_flight
	)
	var opponent_defender := opponent_defense.player as VolleyballPlayer
	var read_tags: Array[String] = ["hand:%s" % hitter.dominant_hand.to_lower(),
		"attack:%s" % str(attack_choice.direction).to_lower().replace("-", "_")]
	var read_modifier := Familiarity.read_modifier(
		opponent_defender, read_tags, float(opponent_team.scouting_confidence)
	)
	var floor_defense_bonus := _opponent_floor_defense_adaptation_bonus(
		opponent_team, assignment.lane
	)
	var defense_strength := clampf(
		_rating(opponent_defender, "reception") * 0.46
		+ _rating(opponent_defender, "anticipation") * 0.38
		+ clampf(float(opponent_defense.arrival_margin) * 0.08, -0.18, 0.10)
		+ read_modifier + floor_defense_bonus + rng.randf_range(-0.16, 0.16), 0.1, 0.9
	)
	Familiarity.record_exposure(opponent_defender, read_tags)
	var dug: bool = defense_strength > final_attack_quality \
		+ rng.randf_range(-0.20, 0.12)
	_add_event(result, RallyEventModel.EventType.DEFENSE, opponent_defender.id if opponent_defender != null else -1,
		opponent_defender.display_name if opponent_defender != null else "Defense",
		attack_target, attack_target + Vector2(0.04, -0.03), dug,
		defense_strength, "Defensive contact",
		"%s %s the %s attack after moving %.1fm.%s" % [
			opponent_defender.display_name if opponent_defender != null else "Nobody",
			"controls" if dug else "cannot reach",
			str(attack_choice.direction), float(opponent_defense.distance_meters),
			" Scouting anticipated this lane." if floor_defense_bonus >= 0.035 else "",
		], {"side": "opponent", "movement_start": opponent_defense.start,
			"movement_duration": opponent_defense.travel_time,
			"arrival_margin": opponent_defense.arrival_margin,
			"attack_direction": attack_choice.direction,
			"adaptation_bonus": floor_defense_bonus})
	if dug:
		if "key_factors" in result:
			var factors = result.get("key_factors")
			if factors is Array: factors.append(ExplanationText.factor("strong_defense"))
		return _resolve_opponent_transition(
			result, players, lineup, hitter, attack_target,
			opponent_team, defensive_plan, 1,
		)

	var kill_key := "kill_default" if active_play == null else (
		"kill_called" if play_followed else "kill_improvised"
	)
	return _finish(result, "kill", true, hitter.id, {
		"setter": setter.display_name,
		"hitter": hitter.display_name,
		"play": active_play_name_str,
	}, kill_key)


func _resolve_home_serve(
	result: Resource,
	players: Array[VolleyballPlayer],
	lineup: RotationLineup,
	opponent_team: Resource,
	defensive_plan: Resource,
) -> Resource:
	var server := _best_home_server(players, lineup)
	var serve_risk := 0.5
	if defensive_plan != null:
		serve_risk = float(defensive_plan.serve_risk)
	var serve_quality := clampf(
		_power_rating(server, "serve_power") * 0.25
		+ _rating(server, "serve_technique") * 0.20
		+ _rating(server, "serve_placement") * 0.13
		+ _rating(server, "serve_consistency") * 0.14
		+ _serve_style_proficiency(server) * 0.13
		+ serve_risk * 0.15 + rng.randf_range(-0.14, 0.14), 0.05, 0.98
	)
	var error_chance := clampf(
		0.025 + serve_risk * 0.07 + _rating(server, "serve_aggression") * 0.025 \
		- _rating(server, "serve_consistency") * 0.065 \
		- _serve_style_proficiency(server) * 0.02,
		0.01, 0.14,
	)
	var serve_error := rng.randf() < error_chance
	var target_name := str(
		defensive_plan.serve_target if defensive_plan != null else "Zone 5"
	)
	var opponent_landing := _serve_landing_point(
		target_name, server, [], null, false
	)
	var serve_time := _serve_flight_time(server, serve_quality)
	_add_event(result, RallyEventModel.EventType.SERVE, server.id, server.display_name,
		Vector2(0.82, 0.92), opponent_landing, not serve_error,
		serve_quality, "%s serves" % server.display_name,
		"%s · %d%% pressure at %d%% selected risk." % [server.primary_serve_style,
			roundi(serve_quality * 100.0), roundi(serve_risk * 100.0),
		], {"side": "home", "target": target_name, "flight_time": serve_time,
			"server_id": server.id, "server_slot": 1,
			"serve_style": server.primary_serve_style})
	if serve_error:
		return _finish(result, "serve_error", false, server.id, {
			"server": server.display_name,
		})
	var opponent_coverage := _opponent_reception_coverage(opponent_team)
	var opponent_claim: Dictionary = CoverageModel.choose_claimant(
		opponent_coverage.players, opponent_coverage.zones,
		opponent_landing, serve_time, "reception",
	)
	var receiver := opponent_claim.get("player") as VolleyballPlayer
	var receiver_arrived := receiver != null
	if receiver == null:
		receiver = opponent_team.best_defender() as VolleyballPlayer
	var opponent_arrival: Dictionary = opponent_claim.get("arrival", {})
	var support_count := int(opponent_claim.get("support_count", 0))
	var serve_receive_bonus := _opponent_serve_receive_adaptation_bonus(
		opponent_team, target_name
	)
	var reception_quality := clampf(
		_rating(receiver, "reception") * 0.58
		+ _rating(receiver, "ball_control") * 0.24
		- serve_quality * 0.44 + 0.27
		- CoverageModel.reception_body_penalty(receiver, opponent_arrival, serve_quality)
		+ clampf(float(opponent_arrival.get("arrival_margin", -1.0)) * 0.07, -0.16, 0.12)
		+ minf(float(support_count) * 0.025, 0.075)
		+ serve_receive_bonus + rng.randf_range(-0.12, 0.12),
		0.0, 1.0,
	)
	if not receiver_arrived:
		reception_quality = minf(reception_quality, 0.12)

	if "reception_quality" in result:
		result.set("reception_quality", reception_quality)

	var reception_success := receiver_arrived and reception_quality >= 0.18
	_add_event(result, RallyEventModel.EventType.RECEPTION, receiver.id if receiver != null else -1,
		receiver.display_name if receiver != null else "Receiver",
		opponent_landing, Vector2(0.50, 0.34), reception_success,
		reception_quality, "%s receives" % (receiver.display_name if receiver != null else "Nobody"),
		"Opponent reception quality: %d%%. %s%s" % [
			roundi(reception_quality * 100.0),
			_arrival_phrase(opponent_arrival, receiver_arrived, support_count),
			" Scouting anticipated this target." if serve_receive_bonus >= 0.035 else "",
		], {"side": "opponent", "landing": opponent_landing,
			"flight_time": serve_time, "arrival": opponent_arrival,
			"support_count": support_count, "adaptation_bonus": serve_receive_bonus})
	if not reception_success:
		return _finish(result, "ace", true, server.id, {"server": server.display_name})
	return _resolve_opponent_transition(
		result, players, lineup, server, Vector2(0.50, 0.34),
		opponent_team, defensive_plan, 1,
	)


func _resolve_opponent_transition(
	result: Resource,
	players: Array[VolleyballPlayer],
	lineup: RotationLineup,
	original_hitter: VolleyballPlayer,
	dig_position: Vector2,
	opponent_team: Resource,
	defensive_plan: Resource,
	exchange_number: int,
) -> Resource:
	var opponent_setter := opponent_team.setter() as VolleyballPlayer
	var transition_penalty := float(exchange_number - 1) * 0.035
	var opponent_setter_position := Vector2(
		clampf(lerpf(dig_position.x, 0.50, 0.66), 0.24, 0.76),
		0.48,
	)
	var setter_start: Vector2 = opponent_team.court_position(opponent_setter.id, "transition")
	var set_geometry := _set_geometry(
		opponent_setter, setter_start, opponent_setter_position,
		Vector2(0.50, 0.48), Vector2(0.50, 0.48)
	)
	var opponent_set_quality := clampf(
		_rating(opponent_setter, "set_accuracy") * 0.48
		+ _rating(opponent_setter, "court_vision") * 0.22
		+ _rating(opponent_setter, "decision_making") * 0.16
		+ 0.18 - float(set_geometry.difficulty) - transition_penalty
		+ rng.randf_range(-0.12, 0.12), 0.08, 0.94,
	)
	var attack_choice := _choose_opponent_attack(
		opponent_team, opponent_setter, opponent_set_quality, _home_target_hint(defensive_plan)
	)
	var opponent_hitter := attack_choice.player as VolleyballPlayer
	var opponent_contact: Vector2 = attack_choice.contact
	var home_target: Vector2 = attack_choice.target
	set_geometry = _set_geometry(
		opponent_setter, setter_start, opponent_setter_position,
		opponent_contact, Vector2(0.50, 0.48)
	)
	opponent_set_quality = clampf(
		_rating(opponent_setter, "set_accuracy") * 0.48
		+ _rating(opponent_setter, "court_vision") * 0.22
		+ _rating(opponent_setter, "decision_making") * 0.16
		+ 0.18 - float(set_geometry.difficulty) - transition_penalty
		+ rng.randf_range(-0.12, 0.12), 0.08, 0.94,
	)
	_add_event(result, RallyEventModel.EventType.SET, opponent_setter.id if opponent_setter != null else -1,
		opponent_setter.display_name if opponent_setter != null else "Opponent Setter",
		dig_position, opponent_contact, true, opponent_set_quality,
		"Opponent transition set · exchange %d" % exchange_number,
		"Contact 2 of 3 · %d%% set quality." % roundi(opponent_set_quality * 100.0),
		{"side": "opponent", "setter_position": opponent_setter_position,
			"movement_start": setter_start, "set_distance_meters": set_geometry.distance_meters,
			"set_angle_degrees": set_geometry.angle_degrees,
			"body_orientation_fit": set_geometry.body_orientation_fit})
	var opponent_attack := clampf(
		_power_rating(opponent_hitter, "attack_power") * 0.62 \
		+ opponent_set_quality * 0.20 + 0.08 \
		+ rng.randf_range(-0.16, 0.16), 0.2, 0.96)
	var opponent_net_contact := Vector2(opponent_contact.x, 0.50)
	var opponent_attack_trajectory := _ball_trajectory(
		"attack_to_block", opponent_contact, opponent_net_contact, 0.23, 2.8, rally_clock
	)
	_add_event(result, RallyEventModel.EventType.ATTACK, opponent_hitter.id if opponent_hitter != null else -1,
		opponent_hitter.display_name if opponent_hitter != null else "Opponent Hitter", opponent_contact, home_target,
		true, opponent_attack, "Opponent transition swing · exchange %d" % exchange_number,
		"Contact 3 of 3 · %s toward %s at %d%% quality." % [
			str(attack_choice.attack_type), str(attack_choice.direction),
			roundi(opponent_attack * 100.0),
		], {"side": "opponent", "lane_x": opponent_contact.x,
			"attack_type": attack_choice.attack_type,
			"attack_direction": attack_choice.direction,
			"hitter_start": attack_choice.start,
			"hitter_travel_time": attack_choice.travel_time,
			"outgoing_trajectory": opponent_attack_trajectory})
	var opponent_tempo := int(opponent_team.tendencies.get("tempo", 2))
	var block_result := _resolve_home_block(
		players, lineup, defensive_plan, opponent_contact.x,
		opponent_tempo, opponent_set_quality, opponent_attack,
		opponent_setter_position.x,
	)
	var blocker := block_result.primary as VolleyballPlayer
	var assisting_blocker := block_result.assist as VolleyballPlayer
	var home_block := float(block_result.quality)
	var block_outcome := str(block_result.outcome)
	if blocker != null:
		live_positions[blocker.id] = Vector2(opponent_contact.x, 0.54)
	if assisting_blocker != null:
		live_positions[assisting_blocker.id] = Vector2(opponent_contact.x, 0.54)
	var deflection_target := home_target
	if block_outcome in ["touch", "funnel"]:
		deflection_target = _home_block_deflection_target(
			home_target, opponent_contact.x, home_block, block_outcome,
			str(defensive_plan.block_defense_relationship) if defensive_plan != null else "Balanced"
		)
	var home_block_target := Vector2(opponent_contact.x, 0.43) \
		if block_outcome == "stuff" else deflection_target
	var home_block_trajectory := _ball_trajectory(
		"block_deflection", opponent_net_contact, home_block_target,
		0.30 if block_outcome == "touch" else 0.22, 2.2, rally_clock
	)
	var assist_text := ""
	if assisting_blocker != null:
		assist_text = " %s assisted at %d%% close." % [
			assisting_blocker.display_name,
			roundi(float(block_result.assist_close) * 100.0),
		]
	var blocker_id := blocker.id if blocker != null else -1
	var blocker_name := blocker.display_name if blocker != null else "No assigned blocker"
	_add_event(result, RallyEventModel.EventType.BLOCK, blocker_id, blocker_name,
		Vector2(opponent_contact.x, 0.53), Vector2(opponent_contact.x, 0.50),
		block_outcome != "miss", home_block, "%s · %s" % [blocker_name, block_outcome.capitalize()],
		"Primary close %d%%; block quality %d%%.%s" % [
			roundi(float(block_result.primary_close) * 100.0),
			roundi(home_block * 100.0), assist_text,
		], {"side": "home", "outcome": block_outcome,
			"primary_close": block_result.primary_close,
			"assist_close": block_result.assist_close,
			"assist_id": assisting_blocker.id if assisting_blocker != null else -1,
			"deflection_target": deflection_target,
			"coverage_segments": block_result.coverage_segments,
			"setter_pull": block_result.setter_pull,
			"read_quality": block_result.read_quality,
			"opponent_setter_position": opponent_setter_position,
			"event_time": rally_clock,
			"incoming_trajectory": opponent_attack_trajectory,
			"outgoing_trajectory": home_block_trajectory})
	if block_outcome == "stuff":
		return _finish(result, "counter_block", true, blocker_id, {
			"hitter": original_hitter.display_name if original_hitter != null else "Hitter",
			"blocker": blocker_name,
		})
	return _finish(result, "attack_control", true, original_hitter.id if original_hitter != null else -1, {})


func _resolve_home_continuation(
	result: Resource,
	players: Array[VolleyballPlayer],
	lineup: RotationLineup,
	coverer: VolleyballPlayer,
	cover_pos: Vector2,
	opponent_team: Resource,
	defensive_plan: Resource,
	exchange_number: int,
) -> Resource:
	if exchange_number > MAX_EXCHANGES:
		return _finish(result, "attack_control", true, coverer.id if coverer != null else -1, {})

	var setter := _second_contact_setter(
		players, lineup, defensive_plan, coverer.id if coverer != null else -1
	)
	var set_contact := cover_pos + Vector2(0.04, -0.05)
	var set_target := CourtConstants.lane_target("Pipe")
	var set_flight_time := 0.65
	var set_trajectory := _ball_trajectory(
		"set", set_contact, set_target, set_flight_time, 3.2, rally_clock
	)
	_add_event(result, RallyEventModel.EventType.SET, setter.id if setter != null else -1,
		setter.display_name if setter != null else "Secondary set",
		set_contact, set_target, true, 0.55,
		"Recycle transition set · exchange %d" % exchange_number,
		"Emergency set back to the pipe option.",
		{"side": "home", "outgoing_trajectory": set_trajectory})

	var hitter := _player_by_id(players, lineup.player_at_slot(6))
	if hitter == null:
		hitter = _fallback_hitter(players, lineup)

	var attack_target := Vector2(0.35, 0.25)
	var attack_flight := 0.50
	var attack_trajectory := _ball_trajectory(
		"attack", set_target, attack_target, attack_flight, 2.9, rally_clock
	)
	_add_event(result, RallyEventModel.EventType.ATTACK, hitter.id, hitter.display_name,
		set_target, attack_target, true, 0.60,
		"%s: Pipe Swing" % hitter.display_name,
		"Counter attack after successful recycle.",
		{"side": "home", "outgoing_trajectory": attack_trajectory})

	return _finish(result, "kill", true, hitter.id, {
		"hitter": hitter.display_name,
		"play": "Recycle Continuation"
	})


# HELPER FUNCTIONS & TRAJECTORY BUILDERS

func _ball_trajectory(
	type_name: String,
	start_pos: Vector2,
	end_pos: Vector2,
	flight_time: float,
	raw_apex: float = 1.0,
	start_time: float = 0.0
) -> Dictionary:
	var apex_meters: float = raw_apex

	# Ensure minimum 3D world clearance heights based on play context
	match type_name:
		"serve":
			apex_meters = maxf(raw_apex, 2.8)
		"reception_pass", "freeball_pass":
			apex_meters = clampf(raw_apex, 2.2, 4.0)
		"set":
			apex_meters = clampf(raw_apex, 2.5, 3.6) # Always clears 2.43m net
		"attack", "spike":
			apex_meters = maxf(raw_apex, 2.7)
		"attack_to_block", "block_deflection":
			apex_meters = maxf(raw_apex, 2.1)

	return {
		"trajectory_type": type_name,
		"start_position": start_pos,
		"end_position": end_pos,
		"duration": maxf(flight_time, 0.05),
		"apex_height_meters": apex_meters,
		"start_time": start_time
	}


func _add_event(
	result: Resource,
	event_type: int,
	actor_id: int,
	actor_name: String,
	start_pos: Vector2,
	end_pos: Vector2,
	success: bool,
	quality: float,
	headline: String,
	explanation: String,
	metadata: Dictionary = {}
) -> void:
	var event := RallyEventModel.new()

	if "event_type" in event: event.set("event_type", event_type)
	if "actor_id" in event: event.set("actor_id", actor_id)
	if "actor_name" in event: event.set("actor_name", actor_name)
	if "start_position" in event: event.set("start_position", start_pos)
	if "end_position" in event: event.set("end_position", end_pos)
	if "success" in event: event.set("success", success)
	if "quality" in event: event.set("quality", quality)
	if "headline" in event: event.set("headline", headline)

	if "explanation" in event:
		event.set("explanation", explanation)
	elif "description" in event:
		event.set("description", explanation)
	else:
		metadata["explanation"] = explanation

	if "metadata" in event:
		var existing_meta: Dictionary = event.get("metadata") if event.get("metadata") != null else {}
		existing_meta.merge(metadata, true)
		event.set("metadata", existing_meta)

	var typed_result := result as RallyResultModel
	if typed_result != null:
		typed_result.events.append(event)
	else:
		var evs = result.get("events")
		if evs != null:
			evs.append(event)


func _reception_pass_result(
	receiver: VolleyballPlayer,
	receiver_start: Vector2,
	landing_pos: Vector2,
	desired_target: Vector2,
	server_pos: Vector2,
	serve_quality: float,
	arrival: Dictionary,
	reception_quality: float
) -> Dictionary:
	# Poor passes drift away from the ideal setter position
	var actual_target := desired_target
	if reception_quality < 0.55:
		var error_dist := (1.0 - reception_quality) * 0.30
		actual_target += Vector2(
			rng.randf_range(-error_dist, error_dist),
			rng.randf_range(0.05, error_dist)
		)
		actual_target = actual_target.clamp(Vector2(0.1, 0.52), Vector2(0.9, 0.88))

	# Dynamic pass height & flight time: High quality = high arc (3.8m), Low quality = low/flat shank (2.2m)
	var apex_m := lerpf(2.2, 3.8, reception_quality)
	var pass_duration := lerpf(0.65, 1.05, reception_quality)

	var pass_trajectory := _ball_trajectory(
		"reception_pass", landing_pos, actual_target, pass_duration, apex_m, rally_clock
	)

	return {
		"destination": actual_target,
		"trajectory": pass_trajectory,
		"body_alignment": clampf(0.5 + reception_quality * 0.5, 0.0, 1.0),
		"platform_feasibility": clampf(0.4 + reception_quality * 0.6, 0.0, 1.0),
		"contact_posture": "knees_bent" if reception_quality > 0.5 else "reaching"
	}

func _finish(
	result: Resource,
	ending_reason: String,
	home_won: bool,
	key_player_id: int,
	data: Dictionary = {},
	kill_factor_key: String = ""
) -> Resource:
	# Use set() so Godot handles dynamically typed Resource properties safely
	result.set("ending_reason", StringName(ending_reason))
	result.set("home_won", home_won)
	result.set("key_player_id", key_player_id)

	if kill_factor_key != "" and "key_factors" in result:
		var factors = result.get("key_factors")
		if factors is Array:
			factors.append(ExplanationText.factor(kill_factor_key))

	return result


func _finish_serve_error(result: Resource, server_name: String) -> Resource:
	result.set("ending_reason", StringName("serve_error"))
	result.set("home_won", true)
	return result


func _player_by_id(players: Array[VolleyballPlayer], player_id: int) -> VolleyballPlayer:
	for p in players:
		if p.id == player_id:
			return p
	return null


func _lineup_players(players: Array[VolleyballPlayer], lineup: RotationLineup) -> Array[VolleyballPlayer]:
	var active: Array[VolleyballPlayer] = []
	if lineup == null:
		return players
	for slot in range(1, 7):
		var pid := lineup.player_at_slot(slot)
		var p := _player_by_id(players, pid)
		if p != null:
			active.append(p)
	return active


func _initial_home_positions(lineup: RotationLineup, defensive_plan: Resource, receiving: bool) -> Dictionary:
	var positions := {}
	if lineup == null:
		return positions
	for slot in range(1, 7):
		var pid := lineup.player_at_slot(slot)
		if pid != -1:
			positions[pid] = CourtConstants.slot_position(slot)
	return positions


func _serve_landing_point(target_name: String, server: VolleyballPlayer, players: Array, lineup: Resource, to_home: bool) -> Vector2:
	var base_target := Vector2(0.50, 0.80) if to_home else Vector2(0.50, 0.20)
	match target_name:
		"Zone 1": base_target = Vector2(0.80, 0.82) if to_home else Vector2(0.20, 0.18)
		"Zone 5": base_target = Vector2(0.20, 0.82) if to_home else Vector2(0.80, 0.18)
		"Zone 6": base_target = Vector2(0.50, 0.85) if to_home else Vector2(0.50, 0.15)
	return base_target


func _serve_flight_time(server: VolleyballPlayer, quality: float) -> float:
	return lerpf(1.2, 0.8, quality)


func _nearest_reception_player(players: Array[VolleyballPlayer], lineup: RotationLineup, defensive_plan: Resource, landing: Vector2) -> VolleyballPlayer:
	var active := _lineup_players(players, lineup)
	return active[0] if not active.is_empty() else null


func _desired_pass_target(preferred: Vector2, landing: Vector2) -> Vector2:
	return preferred


func _second_contact_setter(players: Array[VolleyballPlayer], lineup: RotationLineup, defensive_plan: Resource, exclude_id: int) -> VolleyballPlayer:
	var active_setter_id := lineup.active_setter_id() if lineup != null else -1
	if active_setter_id != exclude_id:
		var s := _player_by_id(players, active_setter_id)
		if s != null: return s
	for p in players:
		if p.id != exclude_id:
			return p
	return null


func _spatial_setter_choice(players: Array[VolleyballPlayer], lineup: RotationLineup, defensive_plan: Resource, exclude_id: int, primary_setter: VolleyballPlayer, contact: Vector2, window: float) -> Dictionary:
	var start_pos := Vector2(0.50, 0.60)
	if primary_setter != null and live_positions.has(primary_setter.id):
		start_pos = live_positions[primary_setter.id]
	return {
		"player": primary_setter,
		"start": start_pos,
		"travel_time": minf(window * 0.8, 0.5)
	}


func _choose_assignment(active_play: OffensivePlay, play_followed: bool, players: Array[VolleyballPlayer], lineup: RotationLineup) -> Dictionary:
	var lane := "Outside"
	var tempo := 3
	var pid := lineup.player_at_slot(4) if lineup != null else -1
	return {"lane": lane, "tempo": tempo, "player_id": pid}


func _fallback_hitter(players: Array[VolleyballPlayer], lineup: RotationLineup) -> VolleyballPlayer:
	return players[0] if not players.is_empty() else null


func _fallback_assignment(hitter: VolleyballPlayer, lineup: RotationLineup) -> Dictionary:
	return {"lane": "Outside", "tempo": 3, "player_id": hitter.id if hitter != null else -1}


func _set_geometry(setter: VolleyballPlayer, start_pos: Vector2, contact: Vector2, target: Vector2, preferred: Vector2) -> Dictionary:
	return {
		"difficulty": 0.1,
		"distance_meters": start_pos.distance_to(contact) * 18.0,
		"angle_degrees": 15.0,
		"release_distance_meters": contact.distance_to(target) * 18.0,
		"body_orientation_fit": 0.9,
		"set_balance": 0.85,
		"set_stability": 0.88
	}


func _hit_type(assignment: Dictionary, hitter: VolleyballPlayer) -> String:
	return "Hard Spike"


func _choose_home_attack_target(hitter: VolleyballPlayer, lane: String, hit_type: String, opponent_team: Resource) -> Dictionary:
	return {"target": Vector2(0.30, 0.20), "direction": "Cross-court", "reason": "Open seam"}


func _attack_flight_time(quality: float, hit_type: String) -> float:
	return lerpf(0.55, 0.35, quality)


func _opponent_block_adaptation_bonus(opponent_team: Resource, lane: String, tempo: int) -> float:
	return 0.02


func _attack_coverage_target(set_target: Vector2, block_strength: float) -> Vector2:
	return Vector2(set_target.x, 0.65)


func _block_coverage_segment(x_pos: float, blocker: VolleyballPlayer, primary: float, assist: float) -> Dictionary:
	return {"x": x_pos, "width": 0.15, "quality": primary}


func _resolve_attack_coverage(players: Array[VolleyballPlayer], lineup: RotationLineup, defensive_plan: Resource, hitter: VolleyballPlayer, target: Vector2, block_strength: float) -> Dictionary:
	var coverer := _player_by_id(players, lineup.player_at_slot(6)) if lineup != null else (players[0] if not players.is_empty() else null)
	return {"player": coverer, "success": true, "quality": 0.65}


func _choose_opponent_defender(opponent_team: Resource, target: Vector2, flight_time: float) -> Dictionary:
	var defender: VolleyballPlayer = null
	if opponent_team != null and opponent_team.has_method("best_defender"):
		defender = opponent_team.best_defender() as VolleyballPlayer

	return {
		"player": defender,
		"start": Vector2(target.x, 0.15),
		"travel_time": flight_time * 0.8,
		"arrival_margin": 0.1,
		"distance_meters": 1.5
	}


func _opponent_floor_defense_adaptation_bonus(opponent_team: Resource, lane: String) -> float:
	return 0.01


func _best_home_server(players: Array[VolleyballPlayer], lineup: RotationLineup) -> VolleyballPlayer:
	return players[0] if not players.is_empty() else null


func _opponent_reception_coverage(opponent_team: Resource) -> Dictionary:
	return {"players": [], "zones": []}


func _opponent_serve_receive_adaptation_bonus(opponent_team: Resource, target_name: String) -> float:
	return 0.01


func _home_target_hint(defensive_plan: Resource) -> Vector2:
	return Vector2(0.50, 0.75)


func _choose_opponent_attack(opponent_team: Resource, setter: VolleyballPlayer, set_quality: float, hint: Vector2) -> Dictionary:
	var hitter: VolleyballPlayer = null
	if opponent_team != null and opponent_team.has_method("best_hitter"):
		hitter = opponent_team.best_hitter() as VolleyballPlayer

	return {
		"player": hitter,
		"contact": Vector2(0.20, 0.48),
		"target": Vector2(0.70, 0.80),
		"attack_type": "Spike",
		"direction": "Cross-court",
		"start": Vector2(0.20, 0.35),
		"travel_time": 0.4
	}


func _resolve_home_block(players: Array[VolleyballPlayer], lineup: RotationLineup, defensive_plan: Resource, attack_x: float, tempo: int, set_quality: float, attack_power: float, setter_x: float) -> Dictionary:
	var primary := _player_by_id(players, lineup.player_at_slot(3)) if lineup != null else (players[0] if not players.is_empty() else null)
	return {
		"primary": primary,
		"assist": null,
		"quality": 0.60,
		"outcome": "touch",
		"primary_close": 0.8,
		"assist_close": 0.0,
		"coverage_segments": [],
		"setter_pull": 0.0,
		"read_quality": 0.7
	}


func _home_block_deflection_target(home_target: Vector2, net_x: float, block_quality: float, outcome: String, strategy: String) -> Vector2:
	return Vector2(net_x, 0.75)


func _serve_style_proficiency(player: VolleyballPlayer) -> float:
	return _rating(player, "serve_technique")


func _movement_time(player: VolleyballPlayer, start_pos: Vector2, end_pos: Vector2, move_type: String) -> float:
	var dist := start_pos.distance_to(end_pos) * 18.0
	return maxf(dist / 6.0, 0.1)


func _rating(player: VolleyballPlayer, property_name: String) -> float:
	if player == null:
		return 0.5
	var raw_rating := float(player.get(property_name)) / 100.0
	return clampf(
		raw_rating * (1.0 - player.fatigue * 0.18) + player.current_form * 0.06,
		0.05, 1.0,
	)


func _power_rating(player: VolleyballPlayer, property_name: String) -> float:
	if player == null:
		return 0.5

	if property_name == "attack_power":
		var raw_power: float = 50.0
		if player.has_method("usable_attack_power"):
			raw_power = float(str(player.call("usable_attack_power")))
		elif "usable_attack_power" in player:
			var p_val = player.get("usable_attack_power")
			if p_val != null:
				raw_power = float(str(p_val))
		else:
			raw_power = _rating(player, "attack_power") * 100.0

		return clampf(
			(raw_power / 100.0) * (1.0 - player.fatigue * 0.18) + player.current_form * 0.06,
			0.05,
			1.0
		)

	var base := _rating(player, property_name)
	var mass_bonus := clampf((player.mass_kg - 82.0) / 48.0, -0.50, 1.0) * 0.07
	return clampf(base + mass_bonus, 0.05, 1.0)


func _available_jump_rating(player: VolleyballPlayer) -> float:
	var maximum_jump := _rating(player, "jump_reach")
	var jump_access := lerpf(0.62, 1.0, _rating(player, "explosiveness"))
	return clampf(maximum_jump * jump_access, 0.05, 1.0)


func _body_reach_rating(player: VolleyballPlayer) -> float:
	if player == null:
		return 0.5

	var reach: float = 240.0
	if "standing_reach_cm" in player:
		var raw_val = player.get("standing_reach_cm")
		if raw_val != null:
			reach = float(str(raw_val))

	return clampf(reach / 280.0, 0.1, 1.0)


func _quality_phrase(q: float) -> String:
	if q >= 0.8: return "In-system pass."
	if q >= 0.5: return "Playable pass."
	return "Out-of-system pass."


func _arrival_phrase(arrival: Dictionary, arrived: bool, support: int) -> String:
	if not arrived: return "Passer missed target window."
	return "Passer set early."

func _choose_opponent_blockers(
	opponent_team: Resource,
	attack_x: float,
	tempo: int,
	lane: String
) -> Dictionary:
	var primary: VolleyballPlayer = null
	var assist: VolleyballPlayer = null
	var assist_close: float = 0.0

	# From home team's perspective (0.0 = Left/Zone 4, 1.0 = Right/Zone 2):
	# Opponent front-row slots facing home are:
	# Slot 2 (Opponent Right) -> faces Home Zone 4 (attack_x ~ 0.0 to 0.38)
	# Slot 3 (Opponent Middle) -> faces Home Middle (attack_x ~ 0.38 to 0.62)
	# Slot 4 (Opponent Left)  -> faces Home Zone 2 (attack_x ~ 0.62 to 1.0)

	if opponent_team != null and opponent_team.has_method("player_at_slot"):
		var slot_2 = opponent_team.call("player_at_slot", 2) as VolleyballPlayer
		var slot_3 = opponent_team.call("player_at_slot", 3) as VolleyballPlayer
		var slot_4 = opponent_team.call("player_at_slot", 4) as VolleyballPlayer

		if attack_x < 0.38:
			primary = slot_2 if slot_2 != null else slot_3
			assist = slot_3 if slot_2 != null else null
		elif attack_x > 0.62:
			primary = slot_4 if slot_4 != null else slot_3
			assist = slot_3 if slot_4 != null else null
		else:
			primary = slot_3
			assist = slot_2 if rng.randf() < 0.5 else slot_4

		if assist != null:
			assist_close = clampf(1.0 - float(3 - tempo) * 0.30, 0.0, 1.0)
	else:
		if opponent_team != null and opponent_team.has_method("best_blocker"):
			primary = opponent_team.call("best_blocker") as VolleyballPlayer

	return {
		"primary": primary,
		"assist": assist,
		"assist_close": assist_close
	}
