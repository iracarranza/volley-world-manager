class_name OpponentTeam
extends Resource

const RallyEventModel := preload("res://scripts/models/rally_event.gd")

@export var team_name: String = "Port Azure VC"
@export var players: Array[Resource] = []
@export var setter_id: int = -1
@export_range(1, 6) var current_rotation: int = 1
@export var rotations: Dictionary = {}
@export_range(0.0, 1.0) var scouting_confidence: float = 0.42
@export var tendencies: Dictionary = {
	"preferred_lane": "Left Pin",
	"tempo": 2,
	"serve_target": "Zone 5",
}
@export_range(0.0, 1.0) var adaptation_rate: float = 0.16
@export_range(0.0, 1.0) var adaptation_strength: float = 0.0
@export var observed_attack_lanes: Dictionary = {}
@export var observed_tempos: Dictionary = {}
@export var observed_serve_targets: Dictionary = {}
@export var rallies_observed: int = 0


func player_by_id(player_id: int) -> Resource:
	for player in players:
		if int(player.id) == player_id:
			return player
	return null


func current_lineup() -> RotationLineup:
	return rotations.get(current_rotation) as RotationLineup


func on_court_players() -> Array[Resource]:
	var result: Array[Resource] = []
	var lineup := current_lineup()
	if lineup == null:
		return players.duplicate()
	for slot_number in range(1, 7):
		var player := player_by_id(lineup.player_at_slot(slot_number))
		if player != null:
			result.append(player)
	return result


func select_rotation(rotation_number: int) -> void:
	current_rotation = clampi(rotation_number, 1, 6)


func rotate() -> void:
	current_rotation = posmod(current_rotation, 6) + 1


func setter() -> Resource:
	return player_by_id(setter_id)


func best_server() -> Resource:
	return _best_by_sum(["serve_power", "serve_technique", "serve_placement",
		"serve_consistency"])


func best_hitter() -> Resource:
	return _best_by_sum(["attack_power", "attack_accuracy"])


func best_blocker() -> Resource:
	return _best_by_sum(["block_timing", "jump_reach"])


func best_defender() -> Resource:
	return _best_by_sum(["reception", "anticipation"])


func court_position(player_id: int, phase: String = "defense") -> Vector2:
	var player := player_by_id(player_id)
	if player == null:
		return Vector2(0.5, 0.25)
	var lineup := current_lineup()
	if lineup != null:
		var slot_number := lineup.slot_for_player(player_id)
		if slot_number >= 1:
			var home_position := CourtConstants.slot_position(slot_number)
			return Vector2(home_position.x, 1.0 - home_position.y)
	var code := str(player.position_code)
	var positions := {
		"S": Vector2(0.70, 0.38), "M1": Vector2(0.50, 0.40),
		"OH1": Vector2(0.18, 0.40), "OP": Vector2(0.82, 0.40),
		"OH2": Vector2(0.24, 0.20), "L": Vector2(0.55, 0.16),
	}
	var position: Vector2 = positions.get(code, Vector2(0.5, 0.25))
	if phase == "serve_receive" and code in ["OH1", "OH2", "L"]:
		position.y = 0.16
	return position


func eligible_hitters(setter_player_id: int = -1) -> Array[Resource]:
	var candidates: Array[Resource] = []
	for player in on_court_players():
		if int(player.id) == setter_player_id or str(player.position_code) == "L":
			continue
		if str(player.position_code) in ["OH1", "OH2", "OP", "M1", "M2"]:
			candidates.append(player)
	return candidates


func _best_by_sum(properties: Array[String]) -> Resource:
	var best: Resource
	var best_score := -1
	for player in on_court_players():
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


func observe_rally(result: Resource) -> void:
	var pattern_observed := false
	for event_resource in result.events:
		var event: Resource = event_resource
		var side := str(event.metadata.get("side", ""))
		if side != "home":
			continue
		match int(event.event_type):
			RallyEventModel.EventType.ATTACK:
				_increment(observed_attack_lanes, str(event.metadata.get("lane", "Unknown")))
				_increment(observed_tempos, "T%d" % int(event.metadata.get("tempo", 3)))
				pattern_observed = true
			RallyEventModel.EventType.SERVE:
				_increment(observed_serve_targets, str(event.metadata.get("target", "Unknown")))
				pattern_observed = true
	if not pattern_observed:
		return
	rallies_observed += 1
	adaptation_strength = clampf(
		adaptation_strength + adaptation_rate * (1.0 - adaptation_strength),
		0.0, 0.85,
	)


func anticipated_lane() -> String:
	return _most_observed(observed_attack_lanes, "")


func anticipated_tempo() -> int:
	var label := _most_observed(observed_tempos, "")
	return int(label.trim_prefix("T")) if label.begins_with("T") else -1


func adaptation_summary() -> String:
	if rallies_observed <= 0:
		return "No in-match patterns learned yet."
	var lane := anticipated_lane()
	var tempo := anticipated_tempo()
	return "Adaptation %d%% · expects %s%s after %d rallies" % [
		roundi(adaptation_strength * 100.0),
		lane if not lane.is_empty() else "mixed lanes",
		" at T%d" % tempo if tempo >= 0 else "",
		rallies_observed,
	]


func adaptation_to_dict() -> Dictionary:
	return {
		"adaptation_rate": adaptation_rate,
		"adaptation_strength": adaptation_strength,
		"observed_attack_lanes": observed_attack_lanes.duplicate(true),
		"observed_tempos": observed_tempos.duplicate(true),
		"observed_serve_targets": observed_serve_targets.duplicate(true),
		"rallies_observed": rallies_observed,
	}


func load_adaptation(data: Dictionary) -> void:
	adaptation_rate = clampf(float(data.get("adaptation_rate", adaptation_rate)), 0.0, 1.0)
	adaptation_strength = clampf(float(data.get("adaptation_strength", 0.0)), 0.0, 0.85)
	observed_attack_lanes = data.get("observed_attack_lanes", {}).duplicate(true)
	observed_tempos = data.get("observed_tempos", {}).duplicate(true)
	observed_serve_targets = data.get("observed_serve_targets", {}).duplicate(true)
	rallies_observed = maxi(int(data.get("rallies_observed", 0)), 0)


func _increment(target: Dictionary, key: String) -> void:
	if key.is_empty() or key == "Unknown":
		return
	target[key] = int(target.get(key, 0)) + 1


func _most_observed(source: Dictionary, fallback: String) -> String:
	var best_key := fallback
	var best_count := -1
	for key in source:
		var count := int(source[key])
		if count > best_count:
			best_key = str(key)
			best_count = count
	return best_key
