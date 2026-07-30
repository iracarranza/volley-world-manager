class_name RallyStateBuilder
extends RefCounted

const DefensiveZoneModel := preload("res://scripts/models/defensive_zone.gd")


static func build(
	home_roster: Array[VolleyballPlayer],
	home_lineup: RotationLineup,
	home_plan: Resource,
	opponent_team: Resource,
	active_play: OffensivePlay,
	home_serving: bool,
	seed_value: int,
) -> RallyState:
	var state := RallyState.new()
	state.seed_value = seed_value
	state.home_lineup = home_lineup
	state.opponent_lineup = opponent_team.current_lineup() \
		if opponent_team != null and opponent_team.has_method("current_lineup") else null
	state.home_plan = home_plan
	state.active_play = active_play

	if home_lineup != null:
		for slot in range(1, 7):
			var player_id := home_lineup.player_at_slot(slot)
			var player := _find_player(home_roster, player_id)
			if player == null:
				continue
			var position := CourtConstants.slot_position(slot)
			if home_plan != null:
				if not home_serving and home_plan.has_method("zone_for"):
					var zone: Resource = home_plan.zone_for(
						player_id, DefensiveZoneModel.ZoneType.SERVE_RECEIVE
					)
					if zone != null and bool(zone.enabled):
						position = Vector2(zone.center)
				elif home_plan.has_method("defender_position"):
					position = home_plan.defender_position(player_id, position)
			state.home_players[player_id] = RallyPlayerState.create(
				player, &"home", slot, position
			)

	if state.opponent_lineup != null and opponent_team != null:
		for slot in range(1, 7):
			var opponent_player: VolleyballPlayer = null
			if opponent_team.has_method("player_at_slot"):
				opponent_player = opponent_team.player_at_slot(slot) as VolleyballPlayer
			if opponent_player == null:
				continue
			var position := CourtConstants.slot_position(slot)
			if opponent_team.has_method("court_position"):
				position = opponent_team.court_position(opponent_player.id)
			state.opponent_players[opponent_player.id] = RallyPlayerState.create(
				opponent_player, &"opponent", slot, position
			)

	return state


static func _find_player(
	players: Array[VolleyballPlayer],
	player_id: int,
) -> VolleyballPlayer:
	for player in players:
		if player != null and player.id == player_id:
			return player
	return null
