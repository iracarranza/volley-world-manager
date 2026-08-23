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
			## **Which side they were on.**
			##
			## This table has always been keyed by actor id alone, and both teams'
			## volis land in it -- so a reader had no way to tell one of ours from
			## one of theirs, and the scouting board's cuttings named every
			## standout "a visiting voli" because the id never matched our roster.
			## An id is only unique within a side.
			player_stats["side"] = side
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
		int(home.get("dig", 0)), int(opponent.get("dig", 0)),
	]


func to_dict() -> Dictionary:
	return {"home": home.duplicate(true), "opponent": opponent.duplicate(true),
		"players": players.duplicate(true)}


## **The one place an `EventType` name is persisted.** Keys here come from
## `type_name().to_lower()`, and this dictionary is saved inside `match_state`,
## so renaming `DEFENSE` to `DIG` would have stranded every counter a save had
## already accumulated -- and the line labelled "Digs" would have read zero on
## load for a match in progress. No ordinal is persisted anywhere; this is the
## whole compatibility surface.
##
## Old saves counted attack coverage in the same bucket, which is exactly the
## conflation this rename exists to end. Those historic totals cannot be split
## after the fact -- nothing recorded which contact each one was -- so they carry
## forward under `dig` slightly overstated, and every rally played from here is
## counted correctly.
func load_dict(data: Dictionary) -> void:
	home = _migrate(data.get("home", {}).duplicate(true))
	opponent = _migrate(data.get("opponent", {}).duplicate(true))
	players = data.get("players", {}).duplicate(true)
	for key in players:
		players[key] = _migrate(players[key])


static func _migrate(stats: Dictionary) -> Dictionary:
	for old_key in ["defense", "defense_errors"]:
		if not stats.has(old_key):
			continue
		var new_key: String = old_key.replace("defense", "dig")
		stats[new_key] = int(stats.get(new_key, 0)) + int(stats[old_key])
		stats.erase(old_key)
	return stats


func _increment(target: Dictionary, key: String) -> void:
	target[key] = int(target.get(key, 0)) + 1
