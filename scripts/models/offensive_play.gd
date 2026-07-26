class_name OffensivePlay
extends Resource

@export var id: int = -1
@export var play_name: String = "New Play"
@export_range(1, 6) var rotation_number: int = 1
@export var context: String = "Serve Receive"
@export var assignments: Array[HitterAssignment] = []
@export var primary_hitter_id: int = -1
@export var secondary_hitter_id: int = -1
@export var fallback_lane: String = "Left Pin"


func assignment_for_player(player_id: int) -> HitterAssignment:
	for assignment in assignments:
		if assignment.player_id == player_id:
			return assignment
	return null


func to_dict() -> Dictionary:
	var assignment_data: Array[Dictionary] = []
	for assignment in assignments:
		assignment_data.append(assignment.to_dict())
	return {
		"id": id,
		"play_name": play_name,
		"rotation_number": rotation_number,
		"context": context,
		"assignments": assignment_data,
		"primary_hitter_id": primary_hitter_id,
		"secondary_hitter_id": secondary_hitter_id,
		"fallback_lane": fallback_lane,
	}


static func from_dict(data: Dictionary) -> OffensivePlay:
	var play := OffensivePlay.new()
	play.id = int(data.get("id", -1))
	play.play_name = str(data.get("play_name", "New Play"))
	play.rotation_number = clampi(int(data.get("rotation_number", 1)), 1, 6)
	play.context = str(data.get("context", "Serve Receive"))
	for assignment_data in data.get("assignments", []):
		play.assignments.append(HitterAssignment.from_dict(assignment_data))
	play.primary_hitter_id = int(data.get("primary_hitter_id", -1))
	play.secondary_hitter_id = int(data.get("secondary_hitter_id", -1))
	play.fallback_lane = str(data.get("fallback_lane", "Left Pin"))
	return play
