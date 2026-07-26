class_name VolleyballMatchState
extends Resource

const MatchStatisticsModel := preload("res://scripts/models/match_statistics.gd")
const MatchFormatModel := preload("res://scripts/models/match_format.gd")

@export var home_score: int = 0
@export var opponent_score: int = 0
@export var home_sets: int = 0
@export var opponent_sets: int = 0
@export var serving_home: bool = false
@export_range(1, 6) var home_rotation: int = 1
@export_range(1, 6) var opponent_rotation: int = 1
@export var set_number: int = 1
@export var match_complete: bool = false
@export var home_timeouts_remaining: int = 2
@export var home_substitutions_used: int = 0
@export var substitution_pairs: Dictionary = {}
@export var substitution_history: Array[Dictionary] = []
@export var rally_history: Array[Dictionary] = []
@export var statistics: Resource = MatchStatisticsModel.new()
@export var match_format: Resource = MatchFormatModel.new()


func record_rally(result: Resource) -> Dictionary:
	if match_complete:
		return {"match_complete": true, "set_complete": false, "rotated": false}
	var home_won: bool = bool(result.home_team_won)
	var rotated := false
	var opponent_rotated := false
	if home_won:
		home_score += 1
		if not serving_home:
			serving_home = true
			home_rotation = posmod(home_rotation, 6) + 1
			rotated = true
	else:
		opponent_score += 1
		if serving_home:
			opponent_rotation = posmod(opponent_rotation, 6) + 1
			opponent_rotated = true
		serving_home = false
	statistics.record_rally(result)
	rally_history.append({
		"set": set_number,
		"home_score": home_score,
		"opponent_score": opponent_score,
		"home_won": home_won,
		"outcome": str(result.terminal_outcome),
		"explanation": str(result.explanation),
	})
	var target: int = match_format.target_for_set(set_number)
	var set_complete := (home_score >= target or opponent_score >= target) \
		and absi(home_score - opponent_score) >= int(match_format.win_by)
	if set_complete:
		if home_score > opponent_score:
			home_sets += 1
		else:
			opponent_sets += 1
		match_complete = home_sets >= match_format.sets_to_win() \
			or opponent_sets >= match_format.sets_to_win()
		if not match_complete:
			set_number += 1
			home_score = 0
			opponent_score = 0
			home_timeouts_remaining = 2
			home_substitutions_used = 0
			substitution_pairs.clear()
			substitution_history.clear()
	return {
		"match_complete": match_complete,
		"home_timeouts_remaining": home_timeouts_remaining,
		"home_substitutions_used": home_substitutions_used,
		"set_complete": set_complete,
		"rotated": rotated,
		"opponent_rotated": opponent_rotated,
	}


func score_text() -> String:
	return "HOME %d  —  %d OPPONENT   ·   Sets %d–%d   ·   Set %d" % [
		home_score, opponent_score, home_sets, opponent_sets, set_number,
	]


func to_dict() -> Dictionary:
	return {
		"home_score": home_score,
		"opponent_score": opponent_score,
		"home_sets": home_sets,
		"opponent_sets": opponent_sets,
		"serving_home": serving_home,
		"home_rotation": home_rotation,
		"opponent_rotation": opponent_rotation,
		"set_number": set_number,
		"match_complete": match_complete,
		"home_timeouts_remaining": home_timeouts_remaining,
		"home_substitutions_used": home_substitutions_used,
		"substitution_pairs": substitution_pairs.duplicate(true),
		"substitution_history": substitution_history.duplicate(true),
		"rally_history": rally_history.duplicate(true),
		"statistics": statistics.to_dict(),
		"match_format": match_format.to_dict(),
	}


func load_dict(data: Dictionary) -> void:
	home_score = int(data.get("home_score", 0))
	opponent_score = int(data.get("opponent_score", 0))
	home_sets = int(data.get("home_sets", 0))
	opponent_sets = int(data.get("opponent_sets", 0))
	serving_home = bool(data.get("serving_home", false))
	home_rotation = clampi(int(data.get("home_rotation", 1)), 1, 6)
	opponent_rotation = clampi(int(data.get("opponent_rotation", 1)), 1, 6)
	set_number = clampi(int(data.get("set_number", 1)), 1, 5)
	match_complete = bool(data.get("match_complete", false))
	home_timeouts_remaining = int(data.get("home_timeouts_remaining", 2))
	home_substitutions_used = int(data.get("home_substitutions_used", 0))
	substitution_pairs = data.get("substitution_pairs", {}).duplicate(true)
	substitution_history.assign(data.get("substitution_history", []))
	rally_history.assign(data.get("rally_history", []))
	statistics = MatchStatisticsModel.new()
	statistics.load_dict(data.get("statistics", {}))
	match_format = MatchFormatModel.from_dict(data.get("match_format", {
		"format_name": "Best of 5", "best_of_sets": 5,
		"regular_set_target": 25, "deciding_set_target": 15, "win_by": 2,
	}))
