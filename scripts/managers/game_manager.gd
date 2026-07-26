extends Node

const RallySimulatorScript := preload("res://scripts/simulation/rally_simulator.gd")
const MatchStateScript := preload("res://scripts/models/match_state.gd")
const DefensivePlanScript := preload("res://scripts/models/defensive_plan.gd")
const OpponentTeamScript := preload("res://scripts/models/opponent_team.gd")

signal rotation_changed(rotation_number: int)
signal playbook_changed

var players: Array[VolleyballPlayer] = []
var rotations: Dictionary = {} # rotation number -> RotationLineup
var saved_plays: Array[OffensivePlay] = []
var selected_rotation: int = 1
var called_play_id: int = -1
var active_play_ids_by_rotation: Dictionary = {}
var _next_play_id: int = 1
var match_state: Resource
var defensive_plans: Dictionary = {}
var opponent_team: Resource


func _ready() -> void:
	if players.is_empty():
		seed_vertical_slice_data()


func seed_vertical_slice_data() -> void:
	players.clear()
	players.append(_make_player(1, "Mira", "Setter", "S", {
		"set_accuracy": 86, "court_vision": 90, "decision_making": 84,
		"improvisation": 78,
	}))
	players.append(_make_player(2, "Tala", "Outside Hitter", "OH1", {
		"reception": 78, "attack_accuracy": 76, "approach_timing": 80,
	}))
	players.append(_make_player(3, "Boro", "Middle Blocker", "M1", {
		"jump_reach": 88, "block_timing": 84, "approach_timing": 79,
	}))
	players.append(_make_player(4, "Sena", "Opposite", "OP", {
		"attack_power": 91, "jump_reach": 86, "lateral_speed": 38,
	}))
	players.append(_make_player(5, "Ivo", "Outside Hitter", "OH2", {
		"transition_speed": 82, "attack_accuracy": 73, "court_vision": 76,
	}))
	players.append(_make_player(6, "Nemi", "Libero", "L", {
		"reception": 92, "ball_control": 90, "anticipation": 88,
		"attack_power": 20,
	}))
	players.append(_make_player(7, "Kiri", "Middle Blocker", "M2", {
		"jump_reach": 84, "block_timing": 79, "transition_speed": 74,
	}))
	players.append(_make_player(8, "Rui", "Outside Hitter", "OH3", {
		"reception": 70, "attack_accuracy": 68, "stamina": 76,
	}))
	rotations.clear()
	var base_rotation_ids: Array[int] = [1, 2, 3, 4, 5, 7]
	for rotation_number in range(1, 7):
		var lineup := RotationLineup.new()
		lineup.rotation_number = rotation_number
		lineup.setter_id = 1
		for slot_number in range(1, 7):
			var player_index := posmod(slot_number - rotation_number, 6)
			var player_id: int = base_rotation_ids[player_index]
			if slot_number in [1, 5, 6] and player_id in [3, 7]:
				player_id = 6
			lineup.assign_slot(slot_number, player_id)
		rotations[rotation_number] = lineup
	selected_rotation = 1
	saved_plays.clear()
	called_play_id = -1
	active_play_ids_by_rotation.clear()
	_next_play_id = 1
	match_state = MatchStateScript.new()
	defensive_plans.clear()
	for rotation_number in range(1, 7):
		var plan: Resource = DefensivePlanScript.new()
		plan.rotation_number = rotation_number
		plan.plan_name = "Rotation %d Defense" % rotation_number
		plan.ensure_defaults(rotations[rotation_number])
		defensive_plans[rotation_number] = plan
	_seed_opponent()


func _seed_opponent() -> void:
	opponent_team = OpponentTeamScript.new()
	opponent_team.team_name = "Port Azure VC"
	opponent_team.setter_id = 101
	opponent_team.scouting_confidence = 0.56
	opponent_team.tendencies = {
		"preferred_lane": "Left Pin", "tempo": 1, "serve_target": "Zone 5",
	}
	var opponent_players: Array[Resource] = []
	opponent_players.append(_make_player(101, "Ari", "Setter", "S", {
			"set_accuracy": 78, "court_vision": 82, "decision_making": 76,
		}))
	opponent_players.append(_make_player(102, "Vale", "Outside Hitter", "OH1", {
			"attack_power": 84, "attack_accuracy": 76, "serve_power": 81,
		}))
	opponent_players.append(_make_player(103, "Oren", "Middle Blocker", "M1", {
			"block_timing": 86, "jump_reach": 89,
		}))
	opponent_players.append(_make_player(104, "Pax", "Opposite", "OP", {
			"attack_power": 88, "attack_accuracy": 71,
		}))
	opponent_players.append(_make_player(105, "Lio", "Outside Hitter", "OH2", {
			"reception": 75, "anticipation": 74,
		}))
	opponent_players.append(_make_player(106, "Emi", "Libero", "L", {
			"reception": 88, "anticipation": 85, "ball_control": 87,
		}))
	opponent_team.players = opponent_players


func _make_player(
	player_id: int,
	player_name: String,
	role_name: String,
	position_code: String,
	overrides: Dictionary,
) -> VolleyballPlayer:
	var player := VolleyballPlayer.new()
	player.id = player_id
	player.display_name = player_name
	player.position_role = role_name
	player.position_code = position_code
	for property_name in overrides:
		player.set(str(property_name), overrides[property_name])
	return player


func select_rotation(rotation_number: int) -> String:
	if rotation_number not in rotations:
		return "Rotation %d is unavailable." % rotation_number
	selected_rotation = rotation_number
	called_play_id = int(active_play_ids_by_rotation.get(rotation_number, -1))
	rotation_changed.emit(selected_rotation)
	return ""


func current_lineup() -> RotationLineup:
	return rotations.get(selected_rotation) as RotationLineup


func current_defensive_plan() -> Resource:
	return defensive_plans.get(selected_rotation) as Resource


func save_defensive_plan(
	block_strategy: String,
	floor_system: String,
	serve_target: String,
	serve_risk: float,
) -> void:
	var plan: Resource = current_defensive_plan()
	if plan == null:
		plan = DefensivePlanScript.new()
		plan.rotation_number = selected_rotation
		defensive_plans[selected_rotation] = plan
	plan.block_strategy = block_strategy
	plan.floor_system = floor_system
	plan.serve_target = serve_target
	plan.serve_risk = clampf(serve_risk, 0.0, 1.0)


func set_defender_position(player_id: int, position: Vector2) -> void:
	var plan: Resource = current_defensive_plan()
	if plan != null:
		plan.set_defender_position(player_id, position)


func player_by_id(player_id: int) -> VolleyballPlayer:
	for player in players:
		if player.id == player_id:
			return player
	return null


func save_offensive_play(play: OffensivePlay) -> Dictionary:
	var lineup := rotations.get(play.rotation_number) as RotationLineup
	if lineup == null:
		return {"success": false, "errors": ["Play rotation is unavailable."]}
	for assignment in play.assignments:
		var assigned_player := player_by_id(assignment.player_id)
		if assigned_player != null and assigned_player.position_role == "Libero":
			return {
				"success": false,
				"errors": ["The libero cannot be assigned an attack."],
			}
	var errors := PlayValidator.validate(play, lineup)
	if not errors.is_empty():
		return {"success": false, "errors": errors}
	var saved_copy := OffensivePlay.from_dict(play.to_dict())
	if saved_copy.id < 0:
		saved_copy.id = _next_play_id
		_next_play_id += 1
	var replaced := false
	for index in range(saved_plays.size()):
		if saved_plays[index].id == saved_copy.id:
			saved_plays[index] = saved_copy
			replaced = true
			break
	if not replaced:
		saved_plays.append(saved_copy)
	if int(active_play_ids_by_rotation.get(saved_copy.rotation_number, -1)) < 0:
		active_play_ids_by_rotation[saved_copy.rotation_number] = saved_copy.id
		if saved_copy.rotation_number == selected_rotation:
			called_play_id = saved_copy.id
	playbook_changed.emit()
	return {"success": true, "play": saved_copy}


func call_play(play_id: int) -> String:
	for play in saved_plays:
		if play.id == play_id and play.rotation_number == selected_rotation:
			called_play_id = play_id
			active_play_ids_by_rotation[selected_rotation] = play_id
			return ""
	return "The selected play is not available for rotation %d." % selected_rotation


func called_play() -> OffensivePlay:
	for play in saved_plays:
		if play.id == called_play_id:
			return play
	return null


func resolve_active_rally(seed_value: int) -> Resource:
	var simulator: RefCounted = RallySimulatorScript.new()
	return simulator.resolve(
		players, current_lineup(), called_play(), opponent_team,
		current_defensive_plan(), bool(match_state.serving_home), seed_value,
	)


func record_rally(result: Resource) -> Dictionary:
	if match_state == null:
		match_state = MatchStateScript.new()
	var update: Dictionary = match_state.record_rally(result)
	_apply_rally_fatigue_and_form(result)
	if bool(update.get("rotated", false)):
		select_rotation(int(match_state.home_rotation))
	return update


func call_timeout() -> String:
	if match_state == null or match_state.match_complete:
		return "No active match is available."
	if match_state.home_timeouts_remaining <= 0:
		return "No timeouts remain in this set."
	match_state.home_timeouts_remaining -= 1
	for player in players:
		player.fatigue = maxf(player.fatigue - 0.08, 0.0)
	return ""


func substitute_current_rotation(player_out_id: int, player_in_id: int) -> String:
	var current := current_lineup()
	var slot_number := current.slot_for_player(player_out_id)
	if slot_number < 0:
		return "The outgoing player is not on court."
	if current.slot_for_player(player_in_id) >= 0:
		return "The incoming player is already on court."
	var player_out := player_by_id(player_out_id)
	var player_in := player_by_id(player_in_id)
	if player_out == null or player_in == null:
		return "Both substitution players must exist."
	if player_out.position_role == "Setter" and player_in.position_role != "Setter":
		return "A setter requires another setter as the legal replacement."
	var libero_exchange := player_out.position_role == "Libero" \
		or player_in.position_role == "Libero"
	if libero_exchange:
		var partner := player_in if player_out.position_role == "Libero" else player_out
		if partner.position_role != "Middle Blocker":
			return "The libero may only exchange with a middle blocker."
		if CourtConstants.is_front_row_slot(slot_number):
			return "The libero exchange is only legal in a back-row slot."
		var error := current.assign_slot(slot_number, player_in_id)
		if not error.is_empty():
			return error
		match_state.substitution_history.append({
			"out": player_out_id, "in": player_in_id, "counted": false,
			"changes": [{"rotation": selected_rotation, "slot": slot_number}],
		})
		return ""
	if match_state.home_substitutions_used >= 6:
		return "The six-substitution limit has been reached for this set."
	var existing_partner := int(match_state.substitution_pairs.get(player_out_id, -1))
	if existing_partner >= 0 and existing_partner != player_in_id:
		return "The outgoing player is already paired with another substitute."
	var changes: Array[Dictionary] = []
	for rotation_number in range(1, 7):
		var lineup := rotations[rotation_number] as RotationLineup
		var rotation_slot := lineup.slot_for_player(player_out_id)
		if rotation_slot < 0:
			continue
		if lineup.slot_for_player(player_in_id) >= 0:
			return "The incoming player already appears in rotation %d." % rotation_number
		changes.append({"rotation": rotation_number, "slot": rotation_slot})
	if changes.is_empty():
		return "The outgoing player has no rotation-sheet positions to replace."
	for change in changes:
		var lineup := rotations[int(change["rotation"])] as RotationLineup
		lineup.assign_slot(int(change["slot"]), player_in_id)
		var plan: Resource = defensive_plans.get(int(change["rotation"])) as Resource
		if plan != null:
			plan.set_defender_position(
				player_in_id, CourtConstants.slot_position(int(change["slot"]))
			)
	match_state.home_substitutions_used += 1
	match_state.substitution_pairs[player_out_id] = player_in_id
	match_state.substitution_pairs[player_in_id] = player_out_id
	match_state.substitution_history.append({
		"out": player_out_id, "in": player_in_id, "counted": true,
		"changes": changes,
	})
	return ""


func undo_last_substitution() -> String:
	if match_state.substitution_history.is_empty():
		return "There is no substitution to undo."
	var entry: Dictionary = match_state.substitution_history.pop_back()
	var player_out_id := int(entry.get("out", -1))
	var player_in_id := int(entry.get("in", -1))
	for change in entry.get("changes", []):
		var rotation_number := int(change.get("rotation", selected_rotation))
		var slot_number := int(change.get("slot", -1))
		if rotation_number in rotations and slot_number >= 1:
			(rotations[rotation_number] as RotationLineup).assign_slot(
				slot_number, player_out_id
			)
	if bool(entry.get("counted", false)):
		match_state.home_substitutions_used = maxi(
			match_state.home_substitutions_used - 1, 0
		)
		match_state.substitution_pairs.erase(player_out_id)
		match_state.substitution_pairs.erase(player_in_id)
	return ""


func bench_player_ids() -> Array[int]:
	var result: Array[int] = []
	var lineup := current_lineup()
	for player in players:
		if lineup.slot_for_player(player.id) < 0:
			result.append(player.id)
	return result


func _apply_rally_fatigue_and_form(result: Resource) -> void:
	var lineup := current_lineup()
	for slot_number in range(1, 7):
		var player := player_by_id(lineup.player_at_slot(slot_number))
		if player != null:
			player.fatigue = minf(player.fatigue + 0.008, 1.0)
			player.current_form *= 0.97
	var decisive := player_by_id(int(result.decisive_actor_id))
	if decisive != null:
		decisive.fatigue = minf(decisive.fatigue + 0.012, 1.0)
		decisive.current_form = clampf(
			decisive.current_form + (0.05 if result.home_team_won else -0.04),
			-1.0, 1.0,
		)


func to_dict() -> Dictionary:
	var player_data: Array[Dictionary] = []
	for player in players:
		player_data.append(player.to_dict())
	var rotation_data: Array[Dictionary] = []
	for rotation_number in range(1, 7):
		if rotation_number in rotations:
			rotation_data.append((rotations[rotation_number] as RotationLineup).to_dict())
	var play_data: Array[Dictionary] = []
	for play in saved_plays:
		play_data.append(play.to_dict())
	return {
		"players": player_data,
		"rotations": rotation_data,
		"saved_plays": play_data,
		"selected_rotation": selected_rotation,
		"called_play_id": called_play_id,
		"active_play_ids_by_rotation": active_play_ids_by_rotation.duplicate(),
		"next_play_id": _next_play_id,
		"match_state": match_state.to_dict() if match_state != null else {},
		"defensive_plans": _defensive_plans_to_data(),
	}


func from_dict(data: Dictionary) -> void:
	_seed_opponent()
	players.clear()
	for player_data in data.get("players", []):
		players.append(VolleyballPlayer.from_dict(player_data))
	rotations.clear()
	for rotation_data in data.get("rotations", []):
		var lineup := RotationLineup.from_dict(rotation_data)
		rotations[lineup.rotation_number] = lineup
	saved_plays.clear()
	for play_data in data.get("saved_plays", []):
		saved_plays.append(OffensivePlay.from_dict(play_data))
	selected_rotation = clampi(int(data.get("selected_rotation", 1)), 1, 6)
	active_play_ids_by_rotation.clear()
	var active_data: Dictionary = data.get("active_play_ids_by_rotation", {})
	for rotation_key in active_data:
		active_play_ids_by_rotation[int(rotation_key)] = int(active_data[rotation_key])
	called_play_id = int(active_play_ids_by_rotation.get(
		selected_rotation, data.get("called_play_id", -1)
	))
	if called_play_id >= 0 and selected_rotation not in active_play_ids_by_rotation:
		active_play_ids_by_rotation[selected_rotation] = called_play_id
	_next_play_id = maxi(int(data.get("next_play_id", 1)), 1)
	match_state = MatchStateScript.new()
	match_state.load_dict(data.get("match_state", {}))
	defensive_plans.clear()
	for plan_data in data.get("defensive_plans", []):
		var plan: Resource = DefensivePlanScript.new()
		plan.load_dict(plan_data)
		defensive_plans[plan.rotation_number] = plan
	for rotation_number in range(1, 7):
		if rotation_number not in defensive_plans:
			var fallback: Resource = DefensivePlanScript.new()
			fallback.rotation_number = rotation_number
			fallback.ensure_defaults(rotations[rotation_number])
			defensive_plans[rotation_number] = fallback


func _defensive_plans_to_data() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for rotation_number in range(1, 7):
		if rotation_number in defensive_plans:
			result.append(defensive_plans[rotation_number].to_dict())
	return result
