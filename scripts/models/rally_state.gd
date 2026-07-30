class_name RallyState
extends RefCounted

var seed_value: int = 0
var simulation_time: float = 0.0
var possession: StringName = &""
var rally_over: bool = false

## Nested side dictionaries prevent collisions when both teams use local IDs.
var home_players: Dictionary = {}
var opponent_players: Dictionary = {}
var ball := RallyBallState.new()

var home_lineup: RotationLineup
var opponent_lineup: RotationLineup
var home_plan: Resource
var opponent_plan: Resource
var active_play: OffensivePlay
var contact_number: int = 0

var events: Array[Resource] = []
var decision_log: Array[Dictionary] = []


func player_state(side: StringName, player_id: int) -> RallyPlayerState:
	var states := home_players if side == &"home" else opponent_players
	return states.get(player_id) as RallyPlayerState


func all_player_states() -> Array[RallyPlayerState]:
	var result: Array[RallyPlayerState] = []
	for value in home_players.values():
		var state := value as RallyPlayerState
		if state != null:
			result.append(state)
	for value in opponent_players.values():
		var state := value as RallyPlayerState
		if state != null:
			result.append(state)
	return result


func advance_to(new_time: float) -> void:
	simulation_time = maxf(new_time, simulation_time)
	ball.update_at(simulation_time)


func register_contact(side: StringName, player_id: int) -> void:
	if side != possession:
		possession = side
		contact_number = 1
	else:
		contact_number += 1
	ball.last_touch_side = side
	ball.last_touch_player_id = player_id
	ball.contact_count = contact_number


func end_rally() -> void:
	rally_over = true
	ball.status = RallyBallState.Status.DEAD


func snapshot() -> RallyState:
	var copy := RallyState.new()
	copy.seed_value = seed_value
	copy.simulation_time = simulation_time
	copy.possession = possession
	copy.rally_over = rally_over
	for player_id in home_players:
		var actor := home_players[player_id] as RallyPlayerState
		if actor != null:
			copy.home_players[player_id] = actor.snapshot()
	for player_id in opponent_players:
		var actor := opponent_players[player_id] as RallyPlayerState
		if actor != null:
			copy.opponent_players[player_id] = actor.snapshot()
	copy.ball = ball.snapshot()
	copy.home_lineup = home_lineup
	copy.opponent_lineup = opponent_lineup
	copy.home_plan = home_plan
	copy.opponent_plan = opponent_plan
	copy.active_play = active_play
	copy.contact_number = contact_number
	copy.events = events.duplicate()
	copy.decision_log = decision_log.duplicate(true)
	return copy
