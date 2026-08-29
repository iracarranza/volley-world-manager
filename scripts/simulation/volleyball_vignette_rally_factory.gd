class_name VolleyballVignetteRallyFactory
extends RefCounted

const GameManagerScript := preload("res://scripts/managers/game_manager.gd")
const DefensivePlanScript := preload("res://scripts/models/defensive_plan.gd")
const OffensivePlayScript := preload("res://scripts/models/offensive_play.gd")
const HitterAssignmentScript := preload("res://scripts/models/hitter_assignment.gd")
const TeamPrinciplesScript := preload("res://scripts/models/team_principles.gd")
const RallyEventModel := preload("res://scripts/models/rally_event.gd")
const SimulatorScript := preload("res://scripts/simulation/vignette_rally_simulator.gd")

const H1_OUTSIDE := 2
const H2_MIDDLE := 3
const H3_SETTER := 1
const H4_OUTSIDE := 5
const H5_LIBERO := 6
const H6_OPPOSITE := 4

## The visual cast follows the approved script exactly by court job. IDs are the
## vertical-slice bodies behind those jobs; labels are hidden in creation.
const A1_LEFT_FRONT := 104
const A2_MIDDLE := 103
const A3_RIGHT_FRONT := 102
const A4_BACK := 105
const A5_MIDDLE_BACK := 106
const A6_BACK := 101

const BASE_SEED := 8300
const SEED_SEARCH := 720

static var _cache: Dictionary = {}


static func q1(mode: String) -> Resource:
	var key := mode.to_lower()
	if _cache.has(key):
		return _cache[key]
	var fixture := _fixture(key)
	if fixture.is_empty():
		return null
	var best: Resource = null
	var best_score := -1
	for offset in range(SEED_SEARCH):
		var simulator := SimulatorScript.new() as VignetteRallySimulator
		simulator.vignette_opponent_plan = fixture.opponent_plan
		var result: Resource = simulator.resolve(
			fixture.players, fixture.lineup, fixture.play,
			fixture.opponent, fixture.home_plan,
			false, BASE_SEED + offset,
			false, false, fixture.principles,
			"Q1 Home", {}, 0.0, false, false,
		)
		var score := _q1_score(result, key, fixture.opponent_lineup)
		if score > best_score:
			best = result
			best_score = score
		if score >= 100:
			best = result
			best.set_meta("vignette_seed", BASE_SEED + offset)
			break
	if best != null:
		best.set_meta("vignette_mode", key)
		best.set_meta("vignette_acceptance_score", best_score)
		_cache[key] = best
		print("Q1 vignette %s resolved at seed %d (acceptance %d)" % [
			key, int(best.get_meta("vignette_seed", -1)), best_score,
		])
	return best


static func _fixture(mode: String) -> Dictionary:
	var gm := GameManagerScript.new()
	gm.seed_vertical_slice_data()
	var players: Array[VolleyballPlayer] = gm.players
	var opponent: OpponentTeam = gm.opponent_team as OpponentTeam
	if opponent == null:
		return {}

	var lineup := _home_lineup()
	var opponent_lineup := _opponent_lineup()
	opponent.rotations.clear()
	opponent.rotations[1] = opponent_lineup
	opponent.setter_id = A6_BACK
	opponent.select_rotation(1)
	opponent.tendencies["serve_target"] = "Short Middle"

	_tune_cast(players, opponent)
	_configure_opponent_information(opponent, mode)
	var home_plan := DefensivePlanScript.new() as DefensivePlan
	home_plan.rotation_number = 1
	home_plan.ensure_defaults(lineup, players)
	var opponent_plan := _opponent_plan(opponent, opponent_lineup, mode)
	var play := _q1_play(mode)
	var values := {
		"decisiveness": 0.48 if mode == "read" else 0.72,
		"pin_focus": 0.38 if mode == "quick" else (0.48 if mode == "read" else 0.72),
		"tempo_variation": 0.68 if mode == "quick" else (0.62 if mode == "read" else 0.42),
		"emotional_expression": 0.50,
		"serve_aggression": 0.50,
		"transition_commitment": 0.50,
		"block_commitment": 0.50,
	}
	return {
		"players": players,
		"lineup": lineup,
		"opponent": opponent,
		"opponent_lineup": opponent_lineup,
		"home_plan": home_plan,
		"opponent_plan": opponent_plan,
		"play": play,
		"principles": TeamPrinciplesScript.custom("Q1 %s" % mode, values),
	}


static func _home_lineup() -> RotationLineup:
	var lineup := RotationLineup.new()
	lineup.rotation_number = 1
	lineup.setter_id = H3_SETTER
	lineup.designated_setter_ids = [H3_SETTER]
	## LF / MF / RF then LB / MB / RB: exactly the approved Q1 cast.
	lineup.assign_slot(4, H1_OUTSIDE)
	lineup.assign_slot(3, H2_MIDDLE)
	lineup.assign_slot(2, H3_SETTER)
	lineup.assign_slot(5, H4_OUTSIDE)
	lineup.assign_slot(6, H5_LIBERO)
	lineup.assign_slot(1, H6_OPPOSITE)
	return lineup


static func _opponent_lineup() -> RotationLineup:
	var lineup := RotationLineup.new()
	lineup.rotation_number = 1
	lineup.setter_id = A6_BACK
	lineup.designated_setter_ids = [A6_BACK]
	lineup.assign_slot(4, A1_LEFT_FRONT)
	lineup.assign_slot(3, A2_MIDDLE)
	lineup.assign_slot(2, A3_RIGHT_FRONT)
	lineup.assign_slot(5, A4_BACK)
	lineup.assign_slot(6, A5_MIDDLE_BACK)
	lineup.assign_slot(1, A6_BACK)
	return lineup


static func _tune_cast(players: Array[VolleyballPlayer], opponent: OpponentTeam) -> void:
	var h5 := _home_player(players, H5_LIBERO)
	if h5 != null:
		h5.reception = 97
		h5.reception_balance = 96
		h5.reception_stability = 96
		h5.ball_control = 94
		h5.anticipation = 92
	var h4 := _home_player(players, H4_OUTSIDE)
	if h4 != null:
		h4.reception = 76
	var h6 := _home_player(players, H6_OPPOSITE)
	if h6 != null:
		h6.reception = 66
		h6.approach_timing = 86
	var setter := _home_player(players, H3_SETTER)
	if setter != null:
		setter.set_accuracy = 96
		setter.set_balance = 94
		setter.set_stability = 95
		setter.tempo_control = 97
		setter.set_disguise = 94
		setter.decision_making = 95
	var outside := _home_player(players, H1_OUTSIDE)
	if outside != null:
		outside.attack_accuracy = 91
		outside.attack_power = 82
		outside.approach_timing = 94
		outside.tooling = 100
		outside.court_vision = 92
		outside.composure = 93
	var middle := _home_player(players, H2_MIDDLE)
	if middle != null:
		middle.attack_accuracy = 91
		middle.attack_power = 85
		middle.approach_timing = 97
		middle.explosiveness = 94
		middle.jump_reach = 90

	## The opening is a genuinely good first ball, not a lucky ace/shank lottery.
	var server := opponent.player_by_id(A6_BACK) as VolleyballPlayer
	if server != null:
		server.serve_power = 36
		server.serve_accuracy = 95
		server.serve_technique = 94
		server.serve_placement = 94
		server.serve_consistency = 98
		server.serve_aggression = 24
		server.primary_serve_style = "Standing"
	for blocker_id in [A1_LEFT_FRONT, A2_MIDDLE, A3_RIGHT_FRONT]:
		var blocker := opponent.player_by_id(blocker_id) as VolleyballPlayer
		if blocker == null:
			continue
		blocker.block_timing = 82 if blocker_id == A2_MIDDLE else 74
		blocker.lateral_speed = 78
		blocker.acceleration = 76
		blocker.jump_reach = 74
		blocker.anticipation = 80
		blocker.tactical_discipline = 82
	for defender_id in [A4_BACK, A5_MIDDLE_BACK, A6_BACK]:
		var defender := opponent.player_by_id(defender_id) as VolleyballPlayer
		if defender != null:
			defender.anticipation = 82
			defender.lateral_speed = 78
			defender.acceleration = 76
			defender.dig_control = 78


static func _configure_opponent_information(opponent: OpponentTeam, mode: String) -> void:
	opponent.observed_attack_lanes.clear()
	opponent.observed_tempos.clear()
	opponent.rallies_observed = 0
	opponent.block_adaptation_strength = 0.0
	opponent.floor_defense_adaptation_strength = 0.0
	if mode == "read":
		## The defense has consumed the quick cue. The real resolver decides how
		## far each body can commit and how much it can repair once the set leaves.
		opponent.observed_attack_lanes["Front Quick"] = 12
		opponent.observed_tempos["T0"] = 12
		opponent.rallies_observed = 12
		opponent.block_adaptation_strength = 0.82
		opponent.floor_defense_adaptation_strength = 0.58
	elif mode == "hitter":
		## Nobody is fooled. They are organised for the pin and the hitter must
		## solve a real wall plus line/deep/cross floor coverage.
		opponent.observed_attack_lanes["Left Pin"] = 12
		opponent.observed_tempos["T2"] = 12
		opponent.rallies_observed = 12
		opponent.block_adaptation_strength = 0.80
		opponent.floor_defense_adaptation_strength = 0.72


static func _opponent_plan(
	opponent: OpponentTeam, lineup: RotationLineup, mode: String
) -> DefensivePlan:
	var plan := DefensivePlanScript.new() as DefensivePlan
	plan.rotation_number = 1
	plan.ensure_defaults(lineup, opponent.players)
	plan.block_intent = "Balanced"
	match mode:
		"quick":
			plan.block_strategy = "Read Block"
			## Wings stay honest while middle-back steps into the fast central ball.
			plan.set_defender_position(A4_BACK, Vector2(0.20, 0.85))
			plan.set_defender_position(A5_MIDDLE_BACK, Vector2(0.50, 0.77))
			plan.set_defender_position(A6_BACK, Vector2(0.80, 0.85))
		"read":
			plan.block_strategy = "Commit Middle"
			## A subtle central squeeze follows the credible quick. When the set
			## releases left, these are starting obligations, not teleports.
			plan.set_defender_position(A4_BACK, Vector2(0.27, 0.82))
			plan.set_defender_position(A5_MIDDLE_BACK, Vector2(0.48, 0.78))
			plan.set_defender_position(A6_BACK, Vector2(0.72, 0.82))
		_:
			plan.block_strategy = "Commit Pin"
			plan.block_intent = "Seal"
			## Coherent pin defense: line, deep middle, crosscourt. The resolver
			## remains free to stop a body short if the flight does not buy the time.
			plan.set_defender_position(A6_BACK, Vector2(0.18, 0.82))
			plan.set_defender_position(A5_MIDDLE_BACK, Vector2(0.50, 0.91))
			plan.set_defender_position(A4_BACK, Vector2(0.80, 0.82))
	return plan


static func _q1_play(mode: String) -> OffensivePlay:
	var play := OffensivePlayScript.new() as OffensivePlay
	play.id = 9101
	play.play_name = "Q1 %s" % mode.capitalize()
	play.rotation_number = 1
	play.context = "Serve Receive"
	var outside := _assignment(H1_OUTSIDE, Vector2(0.18, 0.57), "Left Pin", 2, 6, false)
	var quick := _assignment(H2_MIDDLE, Vector2(0.50, 0.56), "Front Quick", 0, 6, mode != "quick")
	var pipe := _assignment(H6_OPPOSITE, Vector2(0.80, 0.84), "Pipe", 2, 4, true)
	if mode == "quick":
		outside.is_decoy = true
		quick.is_decoy = false
		play.primary_hitter_id = H2_MIDDLE
	else:
		outside.is_decoy = false
		play.primary_hitter_id = H1_OUTSIDE
	play.secondary_hitter_id = H6_OPPOSITE
	play.assignments.assign([outside, quick, pipe])
	play.fallback_lane = "Left Pin"
	return play


static func _assignment(
	player_id: int, start: Vector2, lane: String, tempo: int,
	priority: int, decoy: bool
) -> HitterAssignment:
	var assignment := HitterAssignmentScript.new() as HitterAssignment
	assignment.player_id = player_id
	assignment.start_position = start
	assignment.lane = lane
	assignment.tempo = tempo
	assignment.priority = priority
	assignment.is_decoy = decoy
	return assignment


static func _home_player(
	players: Array[VolleyballPlayer], player_id: int
) -> VolleyballPlayer:
	for player in players:
		if player != null and player.id == player_id:
			return player
	return null


static func _first_event(result: Resource, event_type: int, side: String) -> Resource:
	if result == null:
		return null
	for raw_event in result.events:
		var event: Resource = raw_event
		if event != null and int(event.event_type) == event_type \
				and str(event.metadata.get("side", "")) == side:
			return event
	return null


static func _q1_score(
	result: Resource, mode: String, opponent_lineup: RotationLineup
) -> int:
	if result == null:
		return -1
	var reception := _first_event(result, RallyEventModel.EventType.RECEPTION, "home")
	var attack := _first_event(result, RallyEventModel.EventType.ATTACK, "home")
	if reception == null or attack == null:
		return 0
	var score := 0
	if int(reception.actor_id) == H5_LIBERO and bool(reception.success) \
			and float(reception.quality) >= 0.60:
		score += 20
	var expected_hitter := H2_MIDDLE if mode == "quick" else H1_OUTSIDE
	if int(attack.actor_id) == expected_hitter:
		score += 20
	if (mode == "quick" and int(attack.metadata.get("tempo", 3)) <= 1) \
			or (mode != "quick" and str(attack.metadata.get("lane", "")) == "Left Pin"):
		score += 15

	## This is the non-negotiable back-row gate. Playback invents no movement;
	## all three defenders must have positions published by the resolver on the
	## same attack event that publishes the block.
	var targets: Dictionary = attack.metadata.get("opponent_phase_targets", {})
	var intents: Dictionary = attack.metadata.get("opponent_phase_intents", {})
	var back_ids := [
		opponent_lineup.player_at_slot(5),
		opponent_lineup.player_at_slot(6),
		opponent_lineup.player_at_slot(1),
	]
	var back_row_complete := true
	for player_id in back_ids:
		if not targets.has(player_id) or not intents.has(player_id):
			back_row_complete = false
	if back_row_complete:
		score += 25

	var wall_size := int(attack.metadata.get("wall_size", 0))
	if mode == "quick":
		## Time has to beat organisation: not a fully formed two-person wall.
		if wall_size < 2:
			score += 20
	elif mode == "read":
		## The committed middle may repair, but the resulting wall must still be
		## weaker than the clean pin wall used by Trust your hitters.
		var block_terms: Dictionary = attack.metadata.get("opponent_block_terms", {})
		var assist_close := float(block_terms.get("assist_close_attempted", 0.0))
		if wall_size < 2 or assist_close < 0.78:
			score += 20
	else:
		var block := _first_event(result, RallyEventModel.EventType.BLOCK, "opponent")
		if wall_size >= 2:
			score += 10
		if block != null and str(block.metadata.get("outcome", "")) == "tool":
			score += 10
	return score
