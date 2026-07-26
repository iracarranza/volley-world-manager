class_name MatchStatistics
extends Resource

@export var home: Dictionary = {}
@export var opponent: Dictionary = {}
@export var players: Dictionary = {}


func record_rally(result: Resource) -> void:
	for event_resource in result.events:
		var event: Resource = event_resource
		if int(event.event_type) == RallyEvent.EventType.POINT:
			continue
		var side := str(event.metadata.get("side", "home"))
		var side_stats: Dictionary = home if side == "home" else opponent
		_increment(side_stats, event.type_name().to_lower())
		if not bool(event.success):
			_increment(side_stats, "%s_errors" % event.type_name().to_lower())
		if int(event.actor_id) >= 0:
			var player_key := str(event.actor_id)
			var player_stats: Dictionary = players.get(player_key, {})
			_increment(player_stats, event.type_name().to_lower())
			player_stats["quality_total"] = float(player_stats.get("quality_total", 0.0)) \
				+ float(event.quality)
			player_stats["contacts"] = int(player_stats.get("contacts", 0)) + 1
			players[player_key] = player_stats
	if bool(result.home_team_won):
		_increment(home, "points")
	else:
		_increment(opponent, "points")
	match str(result.terminal_outcome):
		"ace": _increment(home if result.home_team_won else opponent, "aces")
		"kill", "opponent_kill": _increment(
			home if result.home_team_won else opponent, "kills"
		)
		"blocked", "counter_block": _increment(
			home if result.home_team_won else opponent, "blocks"
		)


func summary() -> String:
	return "Kills %d–%d · Blocks %d–%d · Aces %d–%d · Digs %d–%d" % [
		int(home.get("kills", 0)), int(opponent.get("kills", 0)),
		int(home.get("blocks", 0)), int(opponent.get("blocks", 0)),
		int(home.get("aces", 0)), int(opponent.get("aces", 0)),
		int(home.get("defense", 0)), int(opponent.get("defense", 0)),
	]


func to_dict() -> Dictionary:
	return {"home": home.duplicate(true), "opponent": opponent.duplicate(true),
		"players": players.duplicate(true)}


func load_dict(data: Dictionary) -> void:
	home = data.get("home", {}).duplicate(true)
	opponent = data.get("opponent", {}).duplicate(true)
	players = data.get("players", {}).duplicate(true)


func _increment(target: Dictionary, key: String) -> void:
	target[key] = int(target.get(key, 0)) + 1
