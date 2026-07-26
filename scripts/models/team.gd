class_name VolleyballTeam
extends Resource

@export var id: int = 1
@export var team_name: String = "Harbor City VC"
@export var short_name: String = "HCV"
@export var player_ids: Array[int] = []
@export var captain_id: int = -1
@export var libero_ids: Array[int] = []
@export var depth_chart: Dictionary = {}
@export_range(6, 18) var roster_limit: int = 14


func add_player(player_id: int) -> String:
	if player_id in player_ids:
		return "That player is already registered to the team."
	if player_ids.size() >= roster_limit:
		return "The active roster limit has been reached."
	player_ids.append(player_id)
	return ""


func remove_player(player_id: int) -> String:
	if player_id not in player_ids:
		return "That player is not registered to the team."
	player_ids.erase(player_id)
	if captain_id == player_id:
		captain_id = -1
	libero_ids.erase(player_id)
	for role in depth_chart:
		var ordered_ids: Array = depth_chart[role]
		ordered_ids.erase(player_id)
		depth_chart[role] = ordered_ids
	return ""


func set_captain(player_id: int) -> String:
	if player_id not in player_ids:
		return "The captain must be on the active roster."
	captain_id = player_id
	return ""


func set_libero(player_id: int, enabled: bool) -> String:
	if player_id not in player_ids:
		return "A libero must be on the active roster."
	if enabled and player_id not in libero_ids:
		if libero_ids.size() >= 2:
			return "Only two liberos may be designated."
		libero_ids.append(player_id)
	elif not enabled:
		libero_ids.erase(player_id)
	return ""


func set_depth_chart(role_name: String, ordered_player_ids: Array[int]) -> String:
	for player_id in ordered_player_ids:
		if player_id not in player_ids:
			return "Every depth-chart player must be on the active roster."
	depth_chart[role_name] = ordered_player_ids.duplicate()
	return ""


func validate() -> Array[String]:
	var errors: Array[String] = []
	if player_ids.size() < 6:
		errors.append("A match roster requires at least six players.")
	if player_ids.size() > roster_limit:
		errors.append("The roster exceeds its registration limit.")
	if captain_id >= 0 and captain_id not in player_ids:
		errors.append("The captain is not registered to the team.")
	for libero_id in libero_ids:
		if libero_id not in player_ids:
			errors.append("A designated libero is not registered to the team.")
	return errors


func to_dict() -> Dictionary:
	return {"id": id, "team_name": team_name, "short_name": short_name,
		"player_ids": player_ids.duplicate(), "captain_id": captain_id,
		"libero_ids": libero_ids.duplicate(), "depth_chart": depth_chart.duplicate(true),
		"roster_limit": roster_limit}


static func from_dict(data: Dictionary) -> VolleyballTeam:
	var team := VolleyballTeam.new()
	team.id = int(data.get("id", 1))
	team.team_name = str(data.get("team_name", "Harbor City VC"))
	team.short_name = str(data.get("short_name", "HCV"))
	for raw_id in data.get("player_ids", []):
		team.player_ids.append(int(raw_id))
	team.captain_id = int(data.get("captain_id", -1))
	for raw_id in data.get("libero_ids", []):
		team.libero_ids.append(int(raw_id))
	team.depth_chart = data.get("depth_chart", {}).duplicate(true)
	team.roster_limit = clampi(int(data.get("roster_limit", 14)), 6, 18)
	return team
