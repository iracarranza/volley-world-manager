class_name OpponentTeam
extends Resource

@export var team_name: String = "Port Azure VC"
@export var players: Array[Resource] = []
@export var setter_id: int = -1
@export_range(0.0, 1.0) var scouting_confidence: float = 0.42
@export var tendencies: Dictionary = {
	"preferred_lane": "Left Pin",
	"tempo": 2,
	"serve_target": "Zone 5",
}


func player_by_id(player_id: int) -> Resource:
	for player in players:
		if int(player.id) == player_id:
			return player
	return null


func setter() -> Resource:
	return player_by_id(setter_id)


func best_server() -> Resource:
	return _best_by_sum(["serve_power", "serve_accuracy"])


func best_hitter() -> Resource:
	return _best_by_sum(["attack_power", "attack_accuracy"])


func best_blocker() -> Resource:
	return _best_by_sum(["block_timing", "jump_reach"])


func best_defender() -> Resource:
	return _best_by_sum(["reception", "anticipation"])


func _best_by_sum(properties: Array[String]) -> Resource:
	var best: Resource
	var best_score := -1
	for player in players:
		var score := 0
		for property_name in properties:
			score += int(player.get(property_name))
		if score > best_score:
			best = player
			best_score = score
	return best


func scouting_summary() -> String:
	var confidence_label := "Low"
	if scouting_confidence >= 0.72:
		confidence_label = "High"
	elif scouting_confidence >= 0.48:
		confidence_label = "Moderate"
	return "%s scouting · likely %s preference · %s tempo" % [
		confidence_label,
		str(tendencies.get("preferred_lane", "unknown lane")),
		"fast" if int(tendencies.get("tempo", 2)) <= 1 else "controlled",
	]
