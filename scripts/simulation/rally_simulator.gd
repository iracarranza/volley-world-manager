class_name RallySimulator
extends RefCounted

const RallyEventModel := preload("res://scripts/models/rally_event.gd")
const RallyResultModel := preload("res://scripts/models/rally_result.gd")
const ExplanationText := preload("res://scripts/data/rally_explanations.gd")
const CoverageModel := preload("res://scripts/simulation/coverage_calculator.gd")
const DefensiveZoneModel := preload("res://scripts/models/defensive_zone.gd")
const MAX_EXCHANGES: int = 4

const OPPONENT_SERVE: float = 0.63
const OPPONENT_BLOCK: float = 0.61
const OPPONENT_DEFENSE: float = 0.58

var rng := RandomNumberGenerator.new()


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
	var result: Resource = RallyResultModel.new()
	result.active_play_name = active_play.play_name \
		if active_play != null else "Default T3 Outside"
	if home_serving:
		return _resolve_home_serve(
			result, players, lineup, opponent_team, defensive_plan
		)
	var opponent_server := opponent_team.best_server() as VolleyballPlayer
	var server_name := opponent_server.display_name
	var setter := _player_by_id(players, lineup.setter_id)
	var serve_quality := clampf(
		_power_rating(opponent_server, "serve_power") * 0.56
		+ _rating(opponent_server, "serve_accuracy") * 0.34
		+ rng.randf_range(-0.18, 0.18), 0.05, 0.98
	)
	var serve_error := rng.randf() < 0.055
	var intended_target := str(opponent_team.tendencies.get("serve_target", "Zone 5"))
	var serve_landing := _serve_landing_point(
		intended_target, opponent_server, players, lineup, true
	)
	var serve_time := _serve_flight_time(opponent_server, serve_quality)
	_add_event(result, RallyEventModel.EventType.SERVE, -1, server_name,
		Vector2(0.80, 0.08), serve_landing, not serve_error, serve_quality,
		"Pressure serve" if not serve_error else "Serve misses",
		"%d%% pressure toward the receiver." % roundi(serve_quality * 100.0) \
		if not serve_error else "The serve does not enter the court.", {
			"side": "opponent", "target": intended_target,
			"flight_time": serve_time,
		})

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
	result.reception_quality = clampf(reception_base - serve_quality * 0.48 \
		- CoverageModel.reception_body_penalty(receiver, arrival, serve_quality) \
		+ arrival_bonus + support_bonus - seam_penalty \
		+ rng.randf_range(-0.14, 0.14) + 0.30,
		0.0, 1.0)
	if not receiver_arrived:
		result.reception_quality = minf(result.reception_quality, 0.12)
	var reception_success: bool = receiver_arrived \
		and float(result.reception_quality) >= 0.18
	_add_event(result, RallyEventModel.EventType.RECEPTION, receiver.id, receiver.display_name,
		serve_landing, Vector2(0.50, 0.67), reception_success,
		result.reception_quality, "%s receives" % receiver.display_name,
		"%d%% reception quality. %s %s" % [
			roundi(float(result.reception_quality) * 100.0),
			_quality_phrase(float(result.reception_quality)),
			_arrival_phrase(arrival, receiver_arrived, support_count) \
			+ (" Equal-priority passers hesitated at the seam." if seam_conflict else ""),
		], {"side": "home", "landing": serve_landing,
			"flight_time": serve_time, "arrival": arrival,
			"support_count": support_count, "seam_conflict": seam_conflict,
			"claim_margin": float(reception_claim.get("claim_margin", 1.0))})
	if seam_conflict:
		result.key_factors.append(ExplanationText.factor("seam_conflict"))
	if not reception_success:
		return _finish(result, "ace", false, receiver.id, {
			"server": server_name,
		})
	setter = _second_contact_setter(
		players, lineup, defensive_plan, receiver.id
	)
	var emergency_setter := setter != null and setter.id != lineup.setter_id

	var follow_threshold := 0.22 + _rating(setter, "decision_making") * 0.35 \
		+ _rating(setter, "tactical_discipline") * 0.18
	result.play_was_followed = active_play != null \
		and result.reception_quality >= 0.42 \
		and rng.randf() < follow_threshold
	var assignment := _choose_assignment(active_play, result.play_was_followed, players, lineup)
	var hitter := _player_by_id(players, assignment.player_id) if assignment != null else null
	if hitter == null:
		hitter = _fallback_hitter(players, lineup)
		assignment = _fallback_assignment(hitter, lineup)
	if active_play == null:
		result.key_factors.append(ExplanationText.factor("default_offense"))
	else:
		result.key_factors.append(ExplanationText.factor(
			"play_followed" if result.play_was_followed else "play_abandoned"
		))
	result.key_factors.append(ExplanationText.factor(
		"good_pass" if result.reception_quality >= 0.58 else "poor_pass"
	))
	_add_event(result, RallyEventModel.EventType.SET_DECISION, setter.id, setter.display_name,
		Vector2(0.50, 0.67), Vector2(0.50, 0.60), true,
		result.reception_quality,
		"Emergency setter decision" if emergency_setter else "Setter decision",
		"Stays with %s." % result.active_play_name if result.play_was_followed \
		else ("Uses the default T3 ball to the nearest outside pin." \
		if active_play == null else "Moves to the safest available option."),
		{"side": "home", "emergency_setter": emergency_setter,
			"first_contact_id": receiver.id})

	var tempo_demand := float(3 - assignment.tempo) * 0.055
	var set_base: float = _rating(setter, "set_accuracy") * 0.52 \
		+ _rating(setter, "court_vision") * 0.25 \
		+ _rating(setter, "composure") * 0.13 \
		+ result.reception_quality * 0.28 - tempo_demand
	result.set_quality = clampf(set_base + rng.randf_range(-0.12, 0.12), 0.0, 1.0)
	var set_target := CourtConstants.lane_target(assignment.lane)
	_add_event(result, RallyEventModel.EventType.SET, setter.id, setter.display_name,
		Vector2(0.50, 0.67), set_target, result.set_quality >= 0.24,
		result.set_quality, "Set to %s" % assignment.lane,
		("T%d set for %s · %d%% accuracy." % [
			assignment.tempo, hitter.display_name,
			roundi(float(result.set_quality) * 100.0),
		]) + (" Emergency second-contact assignment activated." if emergency_setter else ""),
		{"side": "home", "emergency_setter": emergency_setter,
			"first_contact_id": receiver.id})
	if assignment.tempo <= 1:
		result.key_factors.append(ExplanationText.factor("fast_tempo"))

	var approach_fit := _rating(hitter, "approach_timing") * 0.32 \
		+ _rating(hitter, "transition_speed") * 0.18
	var attack_base: float = _rating(hitter, "attack_accuracy") * 0.38 \
		+ _power_rating(hitter, "attack_power") * 0.24 \
		+ _rating(hitter, "decision_making") * 0.13 \
		+ approach_fit + result.set_quality * 0.25 - tempo_demand
	result.attack_quality = clampf(attack_base + rng.randf_range(-0.16, 0.16), 0.0, 1.0)
	var attack_target := Vector2(1.0 - set_target.x, rng.randf_range(0.12, 0.38))
	var hit_type := _hit_type(assignment, hitter)
	_add_event(result, RallyEventModel.EventType.ATTACK, hitter.id, hitter.display_name,
		set_target, attack_target, result.attack_quality >= 0.25,
		result.attack_quality, "%s: %s" % [hitter.display_name, hit_type],
		"%s from %s at T%d · %d%% contact quality." % [
			hit_type, assignment.lane, assignment.tempo,
			roundi(float(result.attack_quality) * 100.0),
		], {"side": "home", "lane": assignment.lane, "tempo": assignment.tempo,
			"attack_type": hit_type})
	if result.attack_quality < 0.29:
		return _finish(result, "attack_error", false, hitter.id, {
			"hitter": hitter.display_name,
		})

	var opponent_blocker := opponent_team.best_blocker() as VolleyballPlayer
	var block_strength := clampf(
		_rating(opponent_blocker, "block_timing") * 0.52
		+ _available_jump_rating(opponent_blocker) * 0.24
		+ _body_reach_rating(opponent_blocker) * 0.10
		+ rng.randf_range(-0.13, 0.13) \
		- float(3 - assignment.tempo) * 0.035, 0.15, 0.92)
	var adaptation_bonus := _opponent_adaptation_bonus(
		opponent_team, assignment.lane, assignment.tempo
	)
	block_strength = clampf(block_strength + adaptation_bonus, 0.15, 0.96)
	if adaptation_bonus >= 0.035:
		result.key_factors.append(ExplanationText.factor("opponent_adapted"))
	var block_margin := block_strength - float(result.attack_quality) \
		+ rng.randf_range(-0.15, 0.15)
	var block_outcome := "stuff" if block_margin > 0.12 else (
		"recycle" if block_margin > -0.10 else "miss"
	)
	var blocked := block_outcome == "stuff"
	var recycled := block_outcome == "recycle"
	var recycle_target := _attack_coverage_target(set_target, block_strength) \
		if recycled else Vector2(set_target.x, 0.50)
	_add_event(result, RallyEventModel.EventType.BLOCK, opponent_blocker.id,
		opponent_blocker.display_name,
		Vector2(set_target.x, 0.47), recycle_target, block_outcome != "miss",
		block_strength, "Block forms at %s" % assignment.lane,
		"%d%% close speed; the blockers seal the chosen lane.%s" % [
			roundi(block_strength * 100.0),
			" Scouting anticipated this pattern." if adaptation_bonus >= 0.035 else "",
		], {"side": "opponent", "lane": assignment.lane,
			"adaptation_bonus": adaptation_bonus, "outcome": block_outcome,
			"deflection_target": recycle_target})
	if blocked:
		result.key_factors.append(ExplanationText.factor("strong_block"))
		return _finish(result, "blocked", false, hitter.id, {
			"hitter": hitter.display_name,
		})
	if recycled:
		var coverage_result := _resolve_attack_coverage(
			players, lineup, defensive_plan, hitter, recycle_target, block_strength
		)
		var coverer := coverage_result.get("player") as VolleyballPlayer
		var coverage_success := bool(coverage_result.get("success", false))
		var coverage_quality := float(coverage_result.get("quality", 0.0))
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
				"blocked_hitter_id": hitter.id})
		if not coverage_success:
			return _finish(result, "blocked", false, hitter.id, {
				"hitter": hitter.display_name,
			})
		result.key_factors.append(ExplanationText.factor("attack_recycled"))
		return _resolve_home_continuation(
			result, players, lineup, coverer, recycle_target,
			opponent_team, defensive_plan, 1,
		)

	var opponent_defender := opponent_team.best_defender() as VolleyballPlayer
	var defense_strength := clampf(
		_rating(opponent_defender, "reception") * 0.46
		+ _rating(opponent_defender, "anticipation") * 0.38
		+ rng.randf_range(-0.16, 0.16), 0.1, 0.9
	)
	var dug: bool = defense_strength > float(result.attack_quality) \
		+ rng.randf_range(-0.20, 0.12)
	_add_event(result, RallyEventModel.EventType.DEFENSE, opponent_defender.id,
		opponent_defender.display_name,
		attack_target, attack_target + Vector2(0.04, -0.03), dug,
		defense_strength, "Defensive contact",
		"The floor defender %s the attack." % ("controls" if dug else "cannot reach"))
	if dug:
		result.key_factors.append(ExplanationText.factor("strong_defense"))
		return _resolve_opponent_transition(
			result, players, lineup, hitter, attack_target,
			opponent_team, defensive_plan, 1,
		)
	result.key_factors.append(ExplanationText.factor("attack_control"))
	var kill_key := "kill_default" if active_play == null else (
		"kill_called" if result.play_was_followed else "kill_improvised"
	)
	return _finish(result, "kill", true, hitter.id, {
		"setter": setter.display_name,
		"hitter": hitter.display_name,
		"play": result.active_play_name,
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
		_power_rating(server, "serve_power") * 0.48
		+ _rating(server, "serve_accuracy") * 0.34
		+ serve_risk * 0.18 + rng.randf_range(-0.14, 0.14), 0.05, 0.98
	)
	var error_chance := clampf(
		0.025 + serve_risk * 0.09 - _rating(server, "serve_accuracy") * 0.035,
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
		"%d%% pressure at %d%% selected risk." % [
			roundi(serve_quality * 100.0), roundi(serve_risk * 100.0),
		], {"side": "home", "target": target_name, "flight_time": serve_time})
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
	var reception_quality := clampf(
		_rating(receiver, "reception") * 0.58
		+ _rating(receiver, "ball_control") * 0.24
		- serve_quality * 0.44 + 0.27
		- CoverageModel.reception_body_penalty(receiver, opponent_arrival, serve_quality)
		+ clampf(float(opponent_arrival.get("arrival_margin", -1.0)) * 0.07, -0.16, 0.12)
		+ minf(float(support_count) * 0.025, 0.075)
		+ rng.randf_range(-0.12, 0.12),
		0.0, 1.0,
	)
	if not receiver_arrived:
		reception_quality = minf(reception_quality, 0.12)
	result.reception_quality = reception_quality
	var reception_success := receiver_arrived and reception_quality >= 0.18
	_add_event(result, RallyEventModel.EventType.RECEPTION, receiver.id, receiver.display_name,
		opponent_landing, Vector2(0.50, 0.34), reception_success,
		reception_quality, "%s receives" % receiver.display_name,
		"Opponent reception quality: %d%%. %s" % [
			roundi(reception_quality * 100.0),
			_arrival_phrase(opponent_arrival, receiver_arrived, support_count),
		], {"side": "opponent", "landing": opponent_landing,
			"flight_time": serve_time, "arrival": opponent_arrival,
			"support_count": support_count})
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
	var opponent_hitter := opponent_team.best_hitter() as VolleyballPlayer
	var transition_penalty := float(exchange_number - 1) * 0.035
	var opponent_set_quality := clampf(
		0.62 + rng.randf_range(-0.16, 0.16) - transition_penalty,
		0.2, 0.9,
	)
	var opponent_contact := Vector2(rng.randf_range(0.24, 0.76), 0.48)
	_add_event(result, RallyEventModel.EventType.SET, opponent_setter.id,
		opponent_setter.display_name,
		dig_position, opponent_contact, true, opponent_set_quality,
		"Opponent transition set · exchange %d" % exchange_number,
		"Contact 2 of 3 · %d%% set quality." % roundi(opponent_set_quality * 100.0))
	var opponent_attack := clampf(
		_power_rating(opponent_hitter, "attack_power") * 0.62 \
		+ opponent_set_quality * 0.20 + 0.08 \
		+ rng.randf_range(-0.16, 0.16), 0.2, 0.96)
	var home_target := Vector2(rng.randf_range(0.20, 0.80), rng.randf_range(0.76, 0.92))
	_add_event(result, RallyEventModel.EventType.ATTACK, opponent_hitter.id,
		opponent_hitter.display_name,
		opponent_contact, home_target, true, opponent_attack,
		"Opponent transition swing · exchange %d" % exchange_number,
		"Contact 3 of 3 · power swing at %d%% quality." % roundi(opponent_attack * 100.0),
		{"side": "opponent", "lane_x": opponent_contact.x,
			"attack_type": _opponent_attack_type(home_target)})
	var opponent_tempo := int(opponent_team.tendencies.get("tempo", 2))
	var block_result := _resolve_home_block(
		players, lineup, defensive_plan, opponent_contact.x,
		opponent_tempo, opponent_set_quality, opponent_attack,
	)
	var blocker := block_result.primary as VolleyballPlayer
	var assisting_blocker := block_result.assist as VolleyballPlayer
	var home_block := float(block_result.quality)
	var block_outcome := str(block_result.outcome)
	var deflection_target := home_target
	if block_outcome in ["touch", "funnel"]:
		deflection_target = _home_block_deflection_target(
			home_target, opponent_contact.x, home_block, block_outcome
		)
	var assist_text := ""
	if assisting_blocker != null:
		assist_text = " %s assisted at %d%% close." % [
			assisting_blocker.display_name,
			roundi(float(block_result.assist_close) * 100.0),
		]
	_add_event(result, RallyEventModel.EventType.BLOCK, blocker.id, blocker.display_name,
		Vector2(opponent_contact.x, 0.53), Vector2(opponent_contact.x, 0.50),
		block_outcome != "miss", home_block,
		"%s leads the block · %s" % [blocker.display_name, block_outcome.capitalize()],
		"Primary close %d%%; block quality %d%%.%s" % [
			roundi(float(block_result.primary_close) * 100.0),
			roundi(home_block * 100.0), assist_text,
		], {"side": "home", "outcome": block_outcome,
			"primary_close": block_result.primary_close,
			"assist_close": block_result.assist_close,
			"assist_id": assisting_blocker.id if assisting_blocker != null else -1,
			"deflection_target": deflection_target})
	if block_outcome == "stuff":
		return _finish(result, "counter_block", true, blocker.id, {
			"hitter": original_hitter.display_name,
			"blocker": blocker.display_name,
		})
	if block_outcome == "touch":
		result.key_factors.append(ExplanationText.factor("block_touch"))
		opponent_attack = maxf(opponent_attack - 0.10 - home_block * 0.05, 0.12)
		home_target = deflection_target
	elif block_outcome == "funnel":
		result.key_factors.append(ExplanationText.factor("block_funnel"))
		opponent_attack = maxf(opponent_attack - 0.035, 0.12)
		home_target = deflection_target
	var attack_type := _opponent_attack_type(home_target)
	var attack_time := _attack_flight_time(opponent_attack, attack_type)
	if block_outcome == "touch":
		attack_time += 0.24
	elif block_outcome == "funnel":
		attack_time += 0.06
	var defense_claim: Dictionary = CoverageModel.choose_claimant(
		_lineup_players(players, lineup),
		defensive_plan.zones_for(DefensiveZoneModel.ZoneType.FLOOR_DEFENSE),
		home_target, attack_time, "reception",
	)
	var defender := defense_claim.get("player") as VolleyballPlayer
	var defender_arrived := defender != null
	if defender == null:
		defender = _nearest_floor_defender(players, lineup, defensive_plan, home_target)
	var defense_arrival: Dictionary = defense_claim.get("arrival", {})
	var support_count := int(defense_claim.get("support_count", 0))
	var responsibility_fit := _defensive_responsibility_fit(
		defensive_plan, defender.id, home_target, attack_type
	)
	var defense_quality := _rating(defender, "anticipation") * 0.38 \
		+ _rating(defender, "reception") * 0.36 \
		+ _rating(defender, "lateral_speed") * 0.18 \
		+ responsibility_fit \
		+ clampf(float(defense_arrival.get("arrival_margin", -1.0)) * 0.065, -0.16, 0.12) \
		+ minf(float(support_count) * 0.018, 0.054) \
		- CoverageModel.reception_body_penalty(defender, defense_arrival, opponent_attack) \
		+ rng.randf_range(-0.12, 0.12)
	if not defender_arrived:
		defense_quality = minf(defense_quality, 0.10)
	var defense_success: bool = defender_arrived \
		and defense_quality > opponent_attack - 0.12
	_add_event(result, RallyEventModel.EventType.DEFENSE, defender.id, defender.display_name,
		home_target, home_target + Vector2(0.03, -0.04), defense_success,
		defense_quality, "%s defends" % defender.display_name,
		"%d%% defensive contact against a %d%% attack. %s %s" % [
			roundi(defense_quality * 100.0), roundi(opponent_attack * 100.0),
			_responsibility_phrase(defensive_plan, defender.id, attack_type),
			_arrival_phrase(defense_arrival, defender_arrived, support_count),
		], {"side": "home", "attack_type": attack_type,
			"responsibility_fit": responsibility_fit,
			"flight_time": attack_time, "arrival": defense_arrival,
			"support_count": support_count})
	result.key_factors.append(ExplanationText.factor(
		"defense_assignment_fit" if responsibility_fit >= 0.02 \
		else "defense_assignment_stretch"
	))
	if not defense_success:
		return _finish(result, "opponent_kill", false, -1, {
			"hitter": original_hitter.display_name,
		})
	if exchange_number >= MAX_EXCHANGES:
		var safety_win: bool = defense_quality + rng.randf_range(-0.18, 0.18) > 0.60
		return _finish(
			result,
			"long_rally_win" if safety_win else "long_rally_loss",
			safety_win,
			defender.id,
			{"hitter": original_hitter.display_name},
		)
	return _resolve_home_continuation(
		result, players, lineup, defender, home_target,
		opponent_team, defensive_plan, exchange_number,
	)


func _resolve_home_continuation(
	result: Resource,
	players: Array[VolleyballPlayer],
	lineup: RotationLineup,
	defender: VolleyballPlayer,
	dig_position: Vector2,
	opponent_team: Resource,
	defensive_plan: Resource,
	exchange_number: int,
) -> Resource:
	var setter := _second_contact_setter(
		players, lineup, defensive_plan, defender.id
	)
	var emergency_setter := setter != null and setter.id != lineup.setter_id
	var hitter := _fallback_hitter(players, lineup)
	var assignment := _fallback_assignment(hitter, lineup)
	var exchange_penalty := float(exchange_number) * 0.04
	var set_quality := clampf(
		_rating(setter, "set_accuracy") * 0.52
		+ _rating(setter, "ball_control") * 0.22
		+ _rating(setter, "composure") * 0.16
		- exchange_penalty + rng.randf_range(-0.14, 0.14), 0.18, 0.92
	)
	var set_target := CourtConstants.lane_target(assignment.lane)
	_add_event(result, RallyEventModel.EventType.SET, setter.id, setter.display_name,
		dig_position, set_target, true, set_quality,
		("Emergency second-contact set" if emergency_setter else "Transition set") \
		+ " · exchange %d" % exchange_number,
		"Contact 2 of 3 after %s's dig · %d%% set quality." % [
			defender.display_name, roundi(set_quality * 100.0),
		], {"side": "home", "emergency_setter": emergency_setter,
			"first_contact_id": defender.id})
	var attack_quality := clampf(
		_rating(hitter, "attack_accuracy") * 0.42
		+ _power_rating(hitter, "attack_power") * 0.26
		+ _rating(hitter, "approach_timing") * 0.18
		+ set_quality * 0.18 - exchange_penalty
		+ rng.randf_range(-0.15, 0.15), 0.12, 0.95
	)
	var attack_target := Vector2(1.0 - set_target.x, rng.randf_range(0.12, 0.38))
	_add_event(result, RallyEventModel.EventType.ATTACK, hitter.id, hitter.display_name,
		set_target, attack_target, attack_quality >= 0.25, attack_quality,
		"T3 outside swing · exchange %d" % exchange_number,
		"Contact 3 of 3 · %d%% attack quality." % roundi(attack_quality * 100.0),
		{"side": "home", "lane": assignment.lane, "tempo": assignment.tempo,
			"attack_type": _hit_type(assignment, hitter)})
	if attack_quality < 0.25:
		return _finish(result, "attack_error", false, hitter.id, {
			"hitter": hitter.display_name,
		})
	var opponent_blocker := opponent_team.best_blocker() as VolleyballPlayer
	var block_quality := _rating(opponent_blocker, "block_timing") * 0.52 \
		+ _available_jump_rating(opponent_blocker) * 0.24 \
		+ _body_reach_rating(opponent_blocker) * 0.10 \
		+ rng.randf_range(-0.12, 0.12)
	var blocked: bool = block_quality > attack_quality + rng.randf_range(-0.14, 0.16)
	_add_event(result, RallyEventModel.EventType.BLOCK, opponent_blocker.id,
		opponent_blocker.display_name, Vector2(set_target.x, 0.47),
		Vector2(set_target.x, 0.50), blocked, block_quality,
		"Opponent block · exchange %d" % exchange_number,
		"%d%% close quality at %s." % [roundi(block_quality * 100.0), assignment.lane])
	if blocked:
		return _finish(result, "blocked", false, hitter.id, {"hitter": hitter.display_name})
	var opponent_defender := opponent_team.best_defender() as VolleyballPlayer
	var defense_quality := _rating(opponent_defender, "reception") * 0.46 \
		+ _rating(opponent_defender, "anticipation") * 0.38 \
		+ rng.randf_range(-0.16, 0.16)
	var dug: bool = defense_quality > attack_quality + rng.randf_range(-0.18, 0.14)
	_add_event(result, RallyEventModel.EventType.DEFENSE, opponent_defender.id,
		opponent_defender.display_name, attack_target,
		attack_target + Vector2(0.04, -0.03), dug, defense_quality,
		"Opponent dig · exchange %d" % exchange_number,
		"Contact 1 of 3 · %d%% control." % roundi(defense_quality * 100.0))
	if not dug:
		return _finish(result, "kill", true, hitter.id, {
			"setter": setter.display_name,
			"hitter": hitter.display_name,
			"play": "Default T3 Outside",
		}, "kill_default")
	return _resolve_opponent_transition(
		result, players, lineup, hitter, attack_target,
		opponent_team, defensive_plan, exchange_number + 1,
	)


func _attack_coverage_target(set_target: Vector2, block_quality: float) -> Vector2:
	var spread := lerpf(0.14, 0.05, clampf(block_quality, 0.0, 1.0))
	return Vector2(
		clampf(set_target.x + rng.randf_range(-spread, spread), 0.08, 0.92),
		rng.randf_range(0.54, 0.70),
	)


func _second_contact_setter(
	players: Array[VolleyballPlayer],
	lineup: RotationLineup,
	defensive_plan: Resource,
	first_contact_player_id: int,
) -> VolleyballPlayer:
	var regular_setter := _player_by_id(players, lineup.setter_id)
	if regular_setter != null and regular_setter.id != first_contact_player_id:
		return regular_setter
	var best: VolleyballPlayer
	var best_score := -1000.0
	for slot_number in range(1, 7):
		var candidate := _player_by_id(players, lineup.player_at_slot(slot_number))
		if candidate == null or candidate.id == first_contact_player_id:
			continue
		var assignment: Resource = defensive_plan.assignment_for(candidate.id) \
			if defensive_plan != null else null
		var responsibility := str(assignment.second_contact_responsibility) \
			if assignment != null else "No second-contact duty"
		var responsibility_bonus := 0.0
		match responsibility:
			"Primary emergency setter":
				responsibility_bonus = 0.42
			"Secondary emergency setter":
				responsibility_bonus = 0.24
			"Stay available to attack":
				responsibility_bonus = -0.10
			"No second-contact duty":
				responsibility_bonus = -0.22
		var score := _rating(candidate, "set_accuracy") * 0.44 \
			+ _rating(candidate, "ball_control") * 0.28 \
			+ _rating(candidate, "decision_making") * 0.16 \
			+ responsibility_bonus
		if score > best_score:
			best = candidate
			best_score = score
	return best


func _home_block_deflection_target(
	original_target: Vector2,
	attack_x: float,
	block_quality: float,
	outcome: String,
) -> Vector2:
	if outcome == "touch":
		return Vector2(
			clampf(attack_x + rng.randf_range(-0.16, 0.16), 0.08, 0.92),
			rng.randf_range(0.58, lerpf(0.82, 0.69, block_quality)),
		)
	return Vector2(
		clampf(lerpf(original_target.x, 0.50, 0.18), 0.08, 0.92),
		clampf(original_target.y + 0.02, 0.54, 0.94),
	)


func _resolve_attack_coverage(
	players: Array[VolleyballPlayer],
	lineup: RotationLineup,
	defensive_plan: Resource,
	blocked_hitter: VolleyballPlayer,
	target: Vector2,
	block_quality: float,
) -> Dictionary:
	var best: VolleyballPlayer
	var best_score := -1000.0
	for slot_number in range(1, 7):
		var candidate := _player_by_id(players, lineup.player_at_slot(slot_number))
		if candidate == null or candidate.id == blocked_hitter.id:
			continue
		var assignment: Resource = defensive_plan.assignment_for(candidate.id) \
			if defensive_plan != null else null
		var responsibility := str(assignment.attack_coverage_responsibility) \
			if assignment != null else "Cover nearest attacker"
		var start := CourtConstants.slot_position(slot_number)
		if defensive_plan != null:
			start = defensive_plan.defender_position(candidate.id, start)
		var proximity := 1.0 - clampf(
			CoverageModel.court_distance_meters(start, target) / 9.0, 0.0, 1.0
		)
		var responsibility_bonus := 0.0
		match responsibility:
			"Cover nearest attacker":
				responsibility_bonus = proximity * 0.20
			"Cover assigned hitter":
				responsibility_bonus = 0.13
			"Take second contact":
				responsibility_bonus = 0.07
			"Release for transition":
				responsibility_bonus = -0.14
		var score := proximity * 0.42 \
			+ _rating(candidate, "ball_control") * 0.24 \
			+ _rating(candidate, "anticipation") * 0.18 \
			+ responsibility_bonus
		if score > best_score:
			best = candidate
			best_score = score
	if best == null:
		return {"player": null, "quality": 0.0, "success": false}
	var quality := clampf(
		best_score - block_quality * 0.22 + rng.randf_range(-0.10, 0.10),
		0.0, 1.0,
	)
	return {"player": best, "quality": quality, "success": quality >= 0.32}


func _finish_serve_error(result: Resource, server_name: String) -> Resource:
	return _finish(result, "serve_error", true, -1, {"server": server_name})


func _finish(
	result: Resource,
	outcome: String,
	home_won: bool,
	decisive_actor_id: int,
	values: Dictionary,
	explanation_key: String = "",
) -> Resource:
	result.home_team_won = home_won
	result.terminal_outcome = outcome
	result.decisive_actor_id = decisive_actor_id
	var chosen_key := explanation_key if not explanation_key.is_empty() else outcome
	result.explanation = ExplanationText.explanation(chosen_key, values)
	var end_position := Vector2(0.5, 0.90) if home_won else Vector2(0.5, 0.12)
	_add_event(result, RallyEventModel.EventType.POINT, decisive_actor_id,
		"Home" if home_won else "Opponent", end_position, end_position,
		home_won, 1.0, ExplanationText.headline(outcome), result.explanation)
	return result


func _add_event(
	result: Resource,
	event_type: int,
	actor_id: int,
	actor_name: String,
	start: Vector2,
	end: Vector2,
	success: bool,
	quality: float,
	headline: String,
	detail: String,
	metadata: Dictionary = {},
) -> void:
	var event: Resource = RallyEventModel.new()
	event.sequence = result.events.size()
	event.event_type = event_type
	event.actor_id = actor_id
	event.actor_name = actor_name
	event.start_position = start
	event.end_position = end
	event.success = success
	event.quality = quality
	event.headline = headline
	event.detail = detail
	event.metadata = metadata.duplicate(true)
	result.events.append(event)


func _opponent_adaptation_bonus(
	opponent_team: Resource,
	lane: String,
	tempo: int,
) -> float:
	if opponent_team == null:
		return 0.0
	var pattern_match := 0.0
	if opponent_team.anticipated_lane() == lane:
		pattern_match += 0.65
	if opponent_team.anticipated_tempo() == tempo:
		pattern_match += 0.35
	return float(opponent_team.adaptation_strength) * pattern_match * 0.12


func _opponent_attack_type(target: Vector2) -> String:
	if target.y < 0.80:
		return "Short tip"
	if target.x < 0.38 or target.x > 0.62:
		return "Line attack"
	return "Seam attack"


func _defensive_responsibility_fit(
	defensive_plan: Resource,
	player_id: int,
	target: Vector2,
	attack_type: String,
) -> float:
	if defensive_plan == null:
		return 0.0
	var assignment: Resource = defensive_plan.assignment_for(player_id)
	if assignment == null:
		return -0.035
	var fit := 0.0
	if attack_type == "Short tip" and "Tip" in str(assignment.short_ball_responsibility):
		fit += 0.055
	elif attack_type == "Seam attack" and "seam" in str(assignment.seam_responsibility).to_lower():
		fit += 0.045
	elif attack_type == "Line attack" and "Perimeter" in str(assignment.base_responsibility):
		fit += 0.035
	if defensive_plan.block_strategy == "Read Block" \
			and "read" in str(assignment.read_responsibility).to_lower():
		fit += 0.015
	if defensive_plan.floor_system == "Perimeter" \
			and "Perimeter" in str(assignment.base_responsibility):
		fit += 0.015
	elif defensive_plan.floor_system == "Middle-Up" \
			and "Middle-up" in str(assignment.base_responsibility):
		fit += 0.02
	elif defensive_plan.floor_system == "Rotation Defense" \
			and "Rotation" in str(assignment.base_responsibility):
		fit += 0.02
	var base_position: Vector2 = defensive_plan.defender_position(player_id, target)
	fit += lerpf(-0.025, 0.025, 1.0 - clampf(base_position.distance_to(target), 0.0, 1.0))
	return clampf(fit, -0.04, 0.08)


func _responsibility_phrase(
	defensive_plan: Resource,
	player_id: int,
	attack_type: String,
) -> String:
	if defensive_plan == null:
		return "No saved responsibility shaped the contact."
	var assignment: Resource = defensive_plan.assignment_for(player_id)
	if assignment == null:
		return "The defender covered outside a saved responsibility."
	return "%s met the %s responsibility behind the %s." % [
		str(assignment.base_responsibility), attack_type.to_lower(),
		str(defensive_plan.block_strategy).to_lower(),
	]


func _choose_assignment(
	play: OffensivePlay,
	follow_play: bool,
	players: Array[VolleyballPlayer],
	lineup: RotationLineup,
) -> HitterAssignment:
	if play == null or play.assignments.is_empty():
		return null
	if follow_play:
		var primary := play.assignment_for_player(play.primary_hitter_id)
		if primary != null:
			return primary
	var candidates: Array[HitterAssignment] = []
	for assignment in play.assignments:
		if _player_by_id(players, assignment.player_id) != null \
				and lineup.slot_for_player(assignment.player_id) >= 0:
			candidates.append(assignment)
	if candidates.is_empty():
		return null
	return candidates[rng.randi_range(0, candidates.size() - 1)]


func _fallback_hitter(players: Array[VolleyballPlayer], lineup: RotationLineup) -> VolleyballPlayer:
	var outside_candidates: Array[VolleyballPlayer] = []
	for slot_number in range(1, 7):
		var candidate := _player_by_id(players, lineup.player_at_slot(slot_number))
		if candidate != null and candidate.position_role == "Outside Hitter" \
				and CourtConstants.is_front_row_slot(slot_number):
			outside_candidates.append(candidate)
	if not outside_candidates.is_empty():
		var nearest := outside_candidates[0]
		var nearest_distance := 10.0
		for candidate in outside_candidates:
			var slot_number := lineup.slot_for_player(candidate.id)
			var position := CourtConstants.slot_position(slot_number)
			var pin_x := 0.12 if position.x <= 0.5 else 0.88
			var distance := absf(position.x - pin_x)
			if distance < nearest_distance:
				nearest = candidate
				nearest_distance = distance
		return nearest
	for player_id in lineup.front_row_player_ids():
		var player := _player_by_id(players, player_id)
		if player != null and player.position_role != "Setter":
			return player
	return _player_by_id(players, lineup.player_at_slot(4))


func _best_blocker(
	players: Array[VolleyballPlayer],
	lineup: RotationLineup,
) -> VolleyballPlayer:
	var best: VolleyballPlayer
	var best_score := -1
	for player_id in lineup.front_row_player_ids():
		var player := _player_by_id(players, player_id)
		if player == null:
			continue
		var score := player.block_timing + player.jump_reach
		if score > best_score:
			best = player
			best_score = score
	return best


func _resolve_home_block(
	players: Array[VolleyballPlayer],
	lineup: RotationLineup,
	defensive_plan: Resource,
	attack_x: float,
	tempo: int,
	set_quality: float,
	attack_quality: float,
) -> Dictionary:
	var front_blockers: Array[VolleyballPlayer] = []
	for player_id in lineup.front_row_player_ids():
		var player := _player_by_id(players, player_id)
		if player != null:
			front_blockers.append(player)
	var primary: VolleyballPlayer
	var primary_distance := 1000.0
	for candidate in front_blockers:
		var slot_number := lineup.slot_for_player(candidate.id)
		var candidate_x := CourtConstants.slot_position(slot_number).x
		var distance := absf(candidate_x - attack_x)
		if distance < primary_distance:
			primary = candidate
			primary_distance = distance
	var close_time := 0.30 + float(clampi(tempo, 0, 3)) * 0.045 \
		+ (1.0 - set_quality) * 0.18
	var strategy := str(defensive_plan.block_strategy) if defensive_plan != null \
		else "Read Block"
	var pin_attack := attack_x <= 0.34 or attack_x >= 0.66
	if strategy == "Commit Pin":
		close_time += 0.10 if pin_attack else -0.08
	elif strategy == "Commit Middle":
		close_time += 0.10 if not pin_attack else -0.09
	var primary_close := _blocker_close_fraction(
		primary, lineup, attack_x, close_time
	)
	var assist: VolleyballPlayer
	var assist_close := 0.0
	for candidate in front_blockers:
		if candidate.id == primary.id:
			continue
		var close_fraction := _blocker_close_fraction(
			candidate, lineup, attack_x, close_time
		)
		if close_fraction > assist_close:
			assist = candidate
			assist_close = close_fraction
	if assist_close < 0.34:
		assist = null
		assist_close = 0.0
	var primary_skill := _block_contact_skill(primary, primary_close)
	var assist_skill := _block_contact_skill(assist, assist_close) if assist != null else 0.0
	var block_quality := clampf(
		primary_skill * 0.68 + assist_skill * 0.32 * assist_close,
		0.08, 0.94,
	)
	var contest := block_quality + rng.randf_range(-0.14, 0.12)
	var outcome := "miss"
	if contest > attack_quality + 0.14 and primary_close >= 0.72:
		outcome = "stuff"
	elif contest > attack_quality - 0.16:
		outcome = "touch"
	elif contest > attack_quality - 0.30:
		outcome = "funnel"
	return {
		"primary": primary,
		"assist": assist,
		"primary_close": primary_close,
		"assist_close": assist_close,
		"quality": block_quality,
		"outcome": outcome,
	}


func _blocker_close_fraction(
	blocker: VolleyballPlayer,
	lineup: RotationLineup,
	attack_x: float,
	available_time: float,
) -> float:
	if blocker == null:
		return 0.0
	var slot_number := lineup.slot_for_player(blocker.id)
	var start_x := CourtConstants.slot_position(slot_number).x
	var distance_meters := absf(start_x - attack_x) * 9.0
	var anticipation := _rating(blocker, "anticipation")
	var reaction_delay := lerpf(0.34, 0.12, anticipation)
	var movement_time := maxf(available_time - reaction_delay, 0.0)
	var mass_multiplier := lerpf(1.05, 0.91, clampf(
		(blocker.mass_kg - 55.0) / 60.0, 0.0, 1.0
	))
	var movement_speed := lerpf(1.25, 4.40, _rating(blocker, "lateral_speed")) \
		* mass_multiplier
	var travel_capacity := movement_speed * movement_time + 0.72
	return clampf(1.0 - maxf(distance_meters - travel_capacity, 0.0) / 2.8, 0.0, 1.0)


func _block_contact_skill(blocker: VolleyballPlayer, close_fraction: float) -> float:
	if blocker == null:
		return 0.0
	return clampf(
		_rating(blocker, "block_timing") * 0.40
		+ _available_jump_rating(blocker) * 0.25
		+ _body_reach_rating(blocker) * 0.13
		+ _rating(blocker, "anticipation") * 0.08
		+ close_fraction * 0.14,
		0.05, 0.98,
	)


func _best_home_server(
	players: Array[VolleyballPlayer],
	lineup: RotationLineup,
) -> VolleyballPlayer:
	var best: VolleyballPlayer
	var best_score := -1
	for slot_number in range(1, 7):
		var player := _player_by_id(players, lineup.player_at_slot(slot_number))
		if player == null:
			continue
		var score := player.serve_power + player.serve_accuracy
		if score > best_score:
			best = player
			best_score = score
	return best


func _hit_type(assignment: HitterAssignment, hitter: VolleyballPlayer) -> String:
	if assignment.lane in ["Front Quick", "Right Quick"]:
		return "Quick attack"
	if assignment.lane == "Pipe":
		return "Pipe attack"
	if assignment.tempo == 3:
		return "High-ball swing"
	if hitter.attack_power >= 82:
		return "Power swing"
	return "Tempo swing"


func _fallback_assignment(hitter: VolleyballPlayer, lineup: RotationLineup) -> HitterAssignment:
	var assignment := HitterAssignment.new()
	assignment.player_id = hitter.id
	assignment.start_position = CourtConstants.slot_position(
		lineup.slot_for_player(hitter.id)
	)
	assignment.lane = "Left Pin" if assignment.start_position.x <= 0.5 \
		else "Right Pin"
	assignment.tempo = 3
	return assignment


func _lineup_players(
	players: Array[VolleyballPlayer],
	lineup: RotationLineup,
) -> Array[VolleyballPlayer]:
	var result: Array[VolleyballPlayer] = []
	for slot_number in range(1, 7):
		var player := _player_by_id(players, lineup.player_at_slot(slot_number))
		if player != null:
			result.append(player)
	return result


func _serve_landing_point(
	target_name: String,
	server: VolleyballPlayer,
	home_players: Array,
	lineup: RotationLineup,
	landing_on_home_side: bool,
) -> Vector2:
	var home_y := 0.84 if landing_on_home_side else 0.16
	var short_y := 0.67 if landing_on_home_side else 0.33
	var intended := Vector2(0.20, home_y)
	match target_name:
		"Zone 1":
			intended = Vector2(0.80, home_y)
		"Short Middle":
			intended = Vector2(0.50, short_y)
		"Weak Passer":
			intended = _weak_passer_target(home_players, lineup, landing_on_home_side)
		_:
			intended = Vector2(0.20, home_y)
	var accuracy := _rating(server, "serve_accuracy")
	var deviation := lerpf(0.105, 0.018, accuracy)
	var min_y := 0.54 if landing_on_home_side else 0.04
	var max_y := 0.96 if landing_on_home_side else 0.46
	return Vector2(
		clampf(intended.x + rng.randf_range(-deviation, deviation), 0.06, 0.94),
		clampf(intended.y + rng.randf_range(-deviation * 0.65, deviation * 0.65), min_y, max_y),
	)


func _weak_passer_target(
	home_players: Array,
	lineup: RotationLineup,
	landing_on_home_side: bool,
) -> Vector2:
	if landing_on_home_side and lineup != null:
		var weakest: VolleyballPlayer
		var weakest_slot := 5
		for slot_number in [5, 6, 1]:
			var candidate: VolleyballPlayer
			for player_resource in home_players:
				var player := player_resource as VolleyballPlayer
				if player.id == lineup.player_at_slot(slot_number):
					candidate = player
					break
			if candidate != null and (weakest == null or candidate.reception < weakest.reception):
				weakest = candidate
				weakest_slot = slot_number
		return CourtConstants.slot_position(weakest_slot)
	return Vector2(0.78, 0.16)


func _serve_flight_time(server: VolleyballPlayer, serve_quality: float) -> float:
	var power := _power_rating(server, "serve_power")
	return clampf(1.28 - power * 0.42 - serve_quality * 0.24, 0.58, 1.15)


func _attack_flight_time(attack_quality: float, attack_type: String) -> float:
	var base_time := 0.68 if attack_type == "Short tip" else 0.50
	return clampf(base_time - attack_quality * 0.17, 0.28, 0.72)


func _nearest_reception_player(
	players: Array[VolleyballPlayer],
	lineup: RotationLineup,
	defensive_plan: Resource,
	landing_point: Vector2,
) -> VolleyballPlayer:
	var zones: Dictionary = defensive_plan.zones_for(
		DefensiveZoneModel.ZoneType.SERVE_RECEIVE
	)
	return _nearest_zone_player(
		_lineup_players(players, lineup), zones, landing_point, true
	)


func _nearest_floor_defender(
	players: Array[VolleyballPlayer],
	lineup: RotationLineup,
	defensive_plan: Resource,
	landing_point: Vector2,
) -> VolleyballPlayer:
	var zones: Dictionary = defensive_plan.zones_for(
		DefensiveZoneModel.ZoneType.FLOOR_DEFENSE
	)
	return _nearest_zone_player(
		_lineup_players(players, lineup), zones, landing_point, false
	)


func _nearest_zone_player(
	candidates: Array[VolleyballPlayer],
	zones: Dictionary,
	landing_point: Vector2,
	require_enabled: bool,
) -> VolleyballPlayer:
	var nearest: VolleyballPlayer
	var nearest_distance := 1000.0
	for candidate in candidates:
		var zone: Resource = zones.get(candidate.id) as Resource
		if zone == null or (require_enabled and not bool(zone.enabled)):
			continue
		var distance := CoverageModel.court_distance_meters(zone.center, landing_point)
		if distance < nearest_distance:
			nearest = candidate
			nearest_distance = distance
	if nearest == null and not candidates.is_empty():
		nearest = candidates[0]
	return nearest


func _opponent_reception_coverage(opponent_team: Resource) -> Dictionary:
	var passers: Array[VolleyballPlayer] = []
	var zones := {}
	var outside_index := 0
	for player_resource in opponent_team.players:
		var player := player_resource as VolleyballPlayer
		if player.position_role not in ["Outside Hitter", "Libero"]:
			continue
		var zone: Resource = DefensiveZoneModel.new()
		zone.player_id = player.id
		zone.zone_type = DefensiveZoneModel.ZoneType.SERVE_RECEIVE
		zone.radius_meters = 3.2
		zone.priority = 2
		if player.position_role == "Libero":
			zone.center = Vector2(0.50, 0.13)
			zone.priority = 3
		else:
			zone.center = Vector2(0.20 if outside_index == 0 else 0.80, 0.16)
			outside_index += 1
		passers.append(player)
		zones[player.id] = zone
	return {"players": passers, "zones": zones}


func _arrival_phrase(arrival: Dictionary, arrived: bool, support_count: int) -> String:
	if not arrived:
		return "No assigned player could arrive before the ball landed."
	return "Arrived with %.2f m to spare; %d nearby teammate%s supported the zone." % [
		float(arrival.get("arrival_margin", 0.0)), support_count,
		"" if support_count == 1 else "s",
	]


func _receiver(players: Array[VolleyballPlayer], lineup: RotationLineup) -> VolleyballPlayer:
	var best: VolleyballPlayer
	for slot_number in [5, 6, 1]:
		var candidate := _player_by_id(players, lineup.player_at_slot(slot_number))
		if candidate != null and (best == null or candidate.reception > best.reception):
			best = candidate
	return best


func _best_positioned_defender(
	players: Array[VolleyballPlayer],
	lineup: RotationLineup,
	defensive_plan: Resource,
	target: Vector2,
) -> VolleyballPlayer:
	if defensive_plan == null:
		return _receiver(players, lineup)
	var best: VolleyballPlayer
	var best_score := -1000.0
	for slot_number in range(1, 7):
		var candidate := _player_by_id(players, lineup.player_at_slot(slot_number))
		if candidate == null:
			continue
		var position: Vector2 = defensive_plan.defender_position(
			candidate.id, CourtConstants.slot_position(slot_number)
		)
		var proximity := 1.0 - clampf(position.distance_to(target), 0.0, 1.0)
		var score := proximity * 100.0 + candidate.anticipation * 0.35 \
			+ candidate.lateral_speed * 0.20
		if score > best_score:
			best = candidate
			best_score = score
	return best


func _player_by_id(players: Array[VolleyballPlayer], player_id: int) -> VolleyballPlayer:
	for player in players:
		if player.id == player_id:
			return player
	return null


func _rating(player: VolleyballPlayer, property_name: String) -> float:
	if player == null:
		return 0.5
	var raw_rating := float(player.get(property_name)) / 100.0
	return clampf(
		raw_rating * (1.0 - player.fatigue * 0.18) + player.current_form * 0.06,
		0.05, 1.0,
	)


func _power_rating(player: VolleyballPlayer, property_name: String) -> float:
	var base := _rating(player, property_name)
	var mass_bonus := clampf((player.mass_kg - 82.0) / 48.0, -0.50, 1.0) * 0.07
	var explosive_bonus := 0.0
	if property_name == "attack_power":
		explosive_bonus = (_rating(player, "explosiveness") - 0.50) * 0.05
	return clampf(base + mass_bonus + explosive_bonus, 0.05, 1.0)


func _available_jump_rating(player: VolleyballPlayer) -> float:
	var maximum_jump := _rating(player, "jump_reach")
	var jump_access := lerpf(0.62, 1.0, _rating(player, "explosiveness"))
	return clampf(maximum_jump * jump_access, 0.05, 1.0)


func _body_reach_rating(player: VolleyballPlayer) -> float:
	var standing_reach := inverse_lerp(200.0, 275.0, player.standing_reach_cm())
	var wingspan := inverse_lerp(160.0, 225.0, player.wingspan_cm)
	return clampf(standing_reach * 0.68 + wingspan * 0.32, 0.05, 1.0)


func _quality_phrase(quality: float) -> String:
	if quality >= 0.72:
		return "Perfect pass; every attacker remains available."
	if quality >= 0.48:
		return "Playable pass with multiple options."
	if quality >= 0.25:
		return "The setter is pulled off the net."
	return "The offense cannot control the first contact."
