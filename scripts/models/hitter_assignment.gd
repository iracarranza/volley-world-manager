class_name HitterAssignment
extends Resource

@export var player_id: int = -1
@export var start_position: Vector2 = Vector2(0.5, 0.75)
@export var lane: String = "Left Pin"
@export_range(0, 3) var tempo: int = 2
@export_range(1, 6) var priority: int = 1
@export var is_decoy: bool = false


func validate() -> Array[String]:
	var errors: Array[String] = []
	if player_id < 0:
		errors.append("Hitter assignment requires a player.")
	if not CourtConstants.is_normalized(start_position):
		errors.append("Hitter starting position must use normalized court coordinates.")
	if not CourtConstants.is_valid_lane(lane):
		errors.append("Unknown hitter lane: %s." % lane)
	if not CourtConstants.is_valid_tempo(tempo):
		errors.append("Set tempo must be T0 through T3.")
	return errors


func to_dict() -> Dictionary:
	return {
		"player_id": player_id,
		"start_position": [start_position.x, start_position.y],
		"lane": lane,
		"tempo": tempo,
		"priority": priority,
		"is_decoy": is_decoy,
	}


static func from_dict(data: Dictionary) -> HitterAssignment:
	var assignment := HitterAssignment.new()
	assignment.player_id = int(data.get("player_id", -1))
	var saved_position: Array = data.get("start_position", [0.5, 0.75])
	if saved_position.size() >= 2:
		assignment.start_position = Vector2(
			float(saved_position[0]), float(saved_position[1])
		)
	assignment.lane = str(data.get("lane", "Left Pin"))
	assignment.tempo = int(data.get("tempo", 2))
	assignment.priority = clampi(int(data.get("priority", 1)), 1, 6)
	assignment.is_decoy = bool(data.get("is_decoy", false))
	return assignment
