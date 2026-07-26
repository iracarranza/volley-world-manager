class_name DefensiveAssignment
extends Resource

@export var player_id: int = -1
@export var base_responsibility: String = "Perimeter"
@export var read_responsibility: String = "Read hitter"
@export var seam_responsibility: String = "Inside seam"
@export var short_ball_responsibility: String = "Tip coverage"
@export var emergency_responsibility: String = "Deep pursuit"


func coverage_tags() -> Array[String]:
	return [
		base_responsibility,
		read_responsibility,
		seam_responsibility,
		short_ball_responsibility,
		emergency_responsibility,
	]


func to_dict() -> Dictionary:
	return {
		"player_id": player_id,
		"base_responsibility": base_responsibility,
		"read_responsibility": read_responsibility,
		"seam_responsibility": seam_responsibility,
		"short_ball_responsibility": short_ball_responsibility,
		"emergency_responsibility": emergency_responsibility,
	}


static func from_dict(data: Dictionary) -> DefensiveAssignment:
	var assignment := DefensiveAssignment.new()
	assignment.player_id = int(data.get("player_id", -1))
	assignment.base_responsibility = str(data.get("base_responsibility", "Perimeter"))
	assignment.read_responsibility = str(data.get("read_responsibility", "Read hitter"))
	assignment.seam_responsibility = str(data.get("seam_responsibility", "Inside seam"))
	assignment.short_ball_responsibility = str(data.get("short_ball_responsibility", "Tip coverage"))
	assignment.emergency_responsibility = str(data.get("emergency_responsibility", "Deep pursuit"))
	return assignment
