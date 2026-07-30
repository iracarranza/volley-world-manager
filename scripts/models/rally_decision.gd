class_name RallyDecision
extends RefCounted

var decision_type: StringName = &""
var time: float = 0.0
var selected_player_id: int = -1
var selected_action: StringName = &""
var options: Array[Dictionary] = []
var ambiguity: float = 0.0
var conflict: bool = false
var reason: String = ""
var contact_result: Dictionary = {}


func to_dict() -> Dictionary:
	return {
		"decision_type": String(decision_type),
		"time": time,
		"selected_player_id": selected_player_id,
		"selected_action": String(selected_action),
		"options": options.duplicate(true),
		"option_count": options.size(),
		"ambiguity": ambiguity,
		"conflict": conflict,
		"reason": reason,
		"contact_result": contact_result.duplicate(true),
	}
