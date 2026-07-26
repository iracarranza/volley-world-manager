class_name RallySimulator
extends RefCounted

const RallyEventModel := preload("res://scripts/models/rally_event.gd")
const RallyResultModel := preload("res://scripts/models/rally_result.gd")
const ExplanationText := preload("res://scripts/data/rally_explanations.gd")
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
	var receiver := _receiver(players, lineup)
	var setter := _player_by_id(players, lineup.setter_id)
	var serve_quality := clampf(
		_rating(opponent_server, "serve_power") * 0.56
		+ _rating(opponent_server, "serve_accuracy") * 0.34
		+ rng.randf_range(-0.18, 0.18), 0.05, 0.98
	)
	var serve_error := rng.randf() < 0.055
	_add_event(result, RallyEventModel.EventType.SERVE, -1, server_name,
		Vector2(0.80, 0.08), Vector2(0.22, 0.88), not serve_error, serve_quality,
		"Pressure serve" if not serve_error else "Serve misses",
		"%d%% pressure toward the receiver." % roundi(serve_quality * 100.0) \
		if not serve_error else "The serve does not enter the court.")

	if serve_error:
		return _finish_serve_error(result, server_name)

	var reception_base := _rating(receiver, "reception") * 0.65 \
		+ _rating(receiver, "ball_control") * 0.20 \
		+ _rating(receiver, "composure") * 0.15
	result.reception_quality = clampf(reception_base - serve_quality * 0.48 \
		+ rng.randf_range(-0.14, 0.14) + 0.30, 0.0, 1.0)
	var reception_success: bool = float(result.reception_quality) >= 0.18
	_add_event(result, RallyEventModel.EventType.RECEPTION, receiver.id, receiver.display_name,
		Vector2(0.22, 0.88), Vector2(0.50, 0.67), reception_success,
		result.reception_quality, "%s receives" % receiver.display_name,
		"%d%% reception quality. %s" % [
			roundi(float(result.reception_quality) * 100.0),
			_quality_phrase(float(result.reception_quality)),
		])
	if not reception_success:
		return _finish(result, "ace", false, receiver.id, {
			"server": server_name,
		})

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
		result.reception_quality, "Setter decision",
		"Stays with %s." % result.active_play_name if result.play_was_followed \
		else ("Uses the default T3 ball to the nearest outside pin." \
		if active_play == null else "Moves to the safest available option."))

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
		"T%d set for %s · %d%% accuracy." % [
			assignment.tempo, hitter.display_name,
			roundi(float(result.set_quality) * 100.0),
		])
	if assignment.tempo <= 1:
		result.key_factors.append(ExplanationText.factor("fast_tempo"))

	var approach_fit := _rating(hitter, "approach_timing") * 0.32 \
		+ _rating(hitter, "transition_speed") * 0.18
	var attack_base: float = _rating(hitter, "attack_accuracy") * 0.38 \
		+ _rating(hitter, "attack_power") * 0.24 \
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
		])
	if result.attack_quality < 0.29:
		return _finish(result, "attack_error", false, hitter.id, {
			"hitter": hitter.display_name,
		})

	var opponent_blocker := opponent_team.best_blocker() as VolleyballPlayer
	var block_strength := clampf(
		_rating(opponent_blocker, "block_timing") * 0.52
		+ _rating(opponent_blocker, "jump_reach") * 0.34
		+ rng.randf_range(-0.13, 0.13) \
		- float(3 - assignment.tempo) * 0.035, 0.15, 0.92)
	var blocked: bool = block_strength > float(result.attack_quality) \
		+ rng.randf_range(-0.15, 0.15)
	_add_event(result, RallyEventModel.EventType.BLOCK, opponent_blocker.id,
		opponent_blocker.display_name,
		Vector2(set_target.x, 0.47), Vector2(set_target.x, 0.50), blocked,
		block_strength, "Block forms at %s" % assignment.lane,
		"%d%% close speed; the blockers seal the chosen lane." % roundi(block_strength * 100.0))
	if blocked:
		result.key_factors.append(ExplanationText.factor("strong_block"))
		return _finish(result, "blocked", false, hitter.id, {
			"hitter": hitter.display_name,
		})

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
		_rating(server, "serve_power") * 0.48
		+ _rating(server, "serve_accuracy") * 0.34
		+ serve_risk * 0.18 + rng.randf_range(-0.14, 0.14), 0.05, 0.98
	)
	var error_chance := clampf(
		0.025 + serve_risk * 0.09 - _rating(server, "serve_accuracy") * 0.035,
		0.01, 0.14,
	)
	var serve_error := rng.randf() < error_chance
	_add_event(result, RallyEventModel.EventType.SERVE, server.id, server.display_name,
		Vector2(0.82, 0.92), Vector2(0.22, 0.12), not serve_error,
		serve_quality, "%s serves" % server.display_name,
		"%d%% pressure at %d%% selected risk." % [
			roundi(serve_quality * 100.0), roundi(serve_risk * 100.0),
		])
	if serve_error:
		return _finish(result, "serve_error", false, server.id, {
			"server": server.display_name,
		})
	var receiver := opponent_team.best_defender() as VolleyballPlayer
	var reception_quality := clampf(
		_rating(receiver, "reception") * 0.58
		+ _rating(receiver, "ball_control") * 0.24
		- serve_quality * 0.44 + 0.27 + rng.randf_range(-0.12, 0.12),
		0.0, 1.0,
	)
	result.reception_quality = reception_quality
	var reception_success := reception_quality >= 0.18
	_add_event(result, RallyEventModel.EventType.RECEPTION, receiver.id, receiver.display_name,
		Vector2(0.22, 0.12), Vector2(0.50, 0.34), reception_success,
		reception_quality, "%s receives" % receiver.display_name,
		"Opponent reception quality: %d%%." % roundi(reception_quality * 100.0))
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
	var opponent_attack := clampf(0.64 + opponent_set_quality * 0.20 \
		+ rng.randf_range(-0.16, 0.16), 0.2, 0.96)
	var home_target := Vector2(rng.randf_range(0.20, 0.80), rng.randf_range(0.76, 0.92))
	_add_event(result, RallyEventModel.EventType.ATTACK, opponent_hitter.id,
		opponent_hitter.display_name,
		opponent_contact, home_target, true, opponent_attack,
		"Opponent transition swing · exchange %d" % exchange_number,
		"Contact 3 of 3 · power swing at %d%% quality." % roundi(opponent_attack * 100.0))
	var blocker := _best_blocker(players, lineup)
	var home_block := _rating(blocker, "block_timing") * 0.55 \
		+ _rating(blocker, "jump_reach") * 0.30 \
		+ _rating(blocker, "lateral_speed") * 0.15
	if defensive_plan != null:
		if defensive_plan.block_strategy == "Read Block":
			home_block += 0.04
		elif defensive_plan.block_strategy == "Commit Pin" \
				and str(opponent_team.tendencies.get("preferred_lane", "")) == "Left Pin":
			home_block += 0.10
	var block_success: bool = home_block + rng.randf_range(-0.13, 0.13) > opponent_attack
	_add_event(result, RallyEventModel.EventType.BLOCK, blocker.id, blocker.display_name,
		Vector2(opponent_contact.x, 0.53), Vector2(opponent_contact.x, 0.50),
		block_success, home_block, "%s closes the block" % blocker.display_name,
		"Tracks lane %.0f%% across court at %d%% close quality." % [
			opponent_contact.x * 100.0, roundi(home_block * 100.0),
		])
	if block_success:
		return _finish(result, "counter_block", true, blocker.id, {
			"hitter": original_hitter.display_name,
			"blocker": blocker.display_name,
		})
	var defender := _best_positioned_defender(players, lineup, defensive_plan, home_target)
	var defense_quality := _rating(defender, "anticipation") * 0.38 \
		+ _rating(defender, "reception") * 0.36 \
		+ _rating(defender, "lateral_speed") * 0.18 \
		+ rng.randf_range(-0.12, 0.12)
	var defense_success: bool = defense_quality > opponent_attack - 0.12
	_add_event(result, RallyEventModel.EventType.DEFENSE, defender.id, defender.display_name,
		home_target, home_target + Vector2(0.03, -0.04), defense_success,
		defense_quality, "%s defends" % defender.display_name,
		"%d%% defensive contact against a %d%% attack." % [
			roundi(defense_quality * 100.0), roundi(opponent_attack * 100.0),
		])
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
	var setter := _player_by_id(players, lineup.setter_id)
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
		"Emergency T3 outside set · exchange %d" % exchange_number,
		"Contact 2 of 3 after %s's dig · %d%% set quality." % [
			defender.display_name, roundi(set_quality * 100.0),
		])
	var attack_quality := clampf(
		_rating(hitter, "attack_accuracy") * 0.42
		+ _rating(hitter, "attack_power") * 0.26
		+ _rating(hitter, "approach_timing") * 0.18
		+ set_quality * 0.18 - exchange_penalty
		+ rng.randf_range(-0.15, 0.15), 0.12, 0.95
	)
	var attack_target := Vector2(1.0 - set_target.x, rng.randf_range(0.12, 0.38))
	_add_event(result, RallyEventModel.EventType.ATTACK, hitter.id, hitter.display_name,
		set_target, attack_target, attack_quality >= 0.25, attack_quality,
		"T3 outside swing · exchange %d" % exchange_number,
		"Contact 3 of 3 · %d%% attack quality." % roundi(attack_quality * 100.0))
	if attack_quality < 0.25:
		return _finish(result, "attack_error", false, hitter.id, {
			"hitter": hitter.display_name,
		})
	var opponent_blocker := opponent_team.best_blocker() as VolleyballPlayer
	var block_quality := _rating(opponent_blocker, "block_timing") * 0.52 \
		+ _rating(opponent_blocker, "jump_reach") * 0.34 \
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
	result.events.append(event)


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


func _quality_phrase(quality: float) -> String:
	if quality >= 0.72:
		return "Perfect pass; every attacker remains available."
	if quality >= 0.48:
		return "Playable pass with multiple options."
	if quality >= 0.25:
		return "The setter is pulled off the net."
	return "The offense cannot control the first contact."
