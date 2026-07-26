class_name DefensiveAssignment
extends Resource

@export var player_id: int = -1
@export var base_responsibility: String = "Perimeter"
@export var seam_responsibility: String = "Inside seam"
@export var short_ball_responsibility: String = "Tip coverage"
@export var emergency_responsibility: String = "Deep pursuit"
@export var attack_coverage_responsibility: String = "Cover assigned hitter"
@export var second_contact_responsibility: String = "No second-contact duty"
@export var block_participation: bool = true
@export var short_ball_priority: int = 1
@export var deflection_priority: int = 1
@export var emergency_pursuit: bool = true


func coverage_tags() -> Array[String]:
	return [
		base_responsibility,
		seam_responsibility,
		short_ball_responsibility,
		emergency_responsibility,
		attack_coverage_responsibility,
		second_contact_responsibility,
	]


func to_dict() -> Dictionary:
	return {
		"player_id": player_id,
		"base_responsibility": base_responsibility,
		"seam_responsibility": seam_responsibility,
		"short_ball_responsibility": short_ball_responsibility,
		"emergency_responsibility": emergency_responsibility,
		"attack_coverage_responsibility": attack_coverage_responsibility,
		"second_contact_responsibility": second_contact_responsibility,
		"block_participation": block_participation,
		"short_ball_priority": short_ball_priority,
		"deflection_priority": deflection_priority,
		"emergency_pursuit": emergency_pursuit,
	}


static func from_dict(data: Dictionary) -> DefensiveAssignment:
	var assignment := DefensiveAssignment.new()
	assignment.player_id = int(data.get("player_id", -1))
	assignment.base_responsibility = str(data.get("base_responsibility", "Perimeter"))
	assignment.seam_responsibility = str(data.get("seam_responsibility", "Inside seam"))
	assignment.short_ball_responsibility = str(data.get("short_ball_responsibility", "Tip coverage"))
	assignment.emergency_responsibility = str(data.get("emergency_responsibility", "Deep pursuit"))
	assignment.attack_coverage_responsibility = str(data.get(
		"attack_coverage_responsibility", "Cover assigned hitter"
	))
	assignment.second_contact_responsibility = str(data.get(
		"second_contact_responsibility", "No second-contact duty"
	))
	assignment.block_participation = bool(data.get("block_participation", true))
	assignment.short_ball_priority = clampi(int(data.get("short_ball_priority", 1)), 0, 3)
	assignment.deflection_priority = clampi(int(data.get("deflection_priority", 1)), 0, 3)
	assignment.emergency_pursuit = bool(data.get("emergency_pursuit", true))
	return assignment
