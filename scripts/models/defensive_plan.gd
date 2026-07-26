class_name DefensivePlan
extends Resource

const DefensiveAssignmentModel := preload("res://scripts/models/defensive_assignment.gd")

@export_range(1, 6) var rotation_number: int = 1
@export var plan_name: String = "Base Defense"
@export var block_strategy: String = "Read Block"
@export var floor_system: String = "Perimeter"
@export var serve_target: String = "Zone 5"
@export_range(0.0, 1.0) var serve_risk: float = 0.5
@export var defender_positions: Dictionary = {}
@export var assignments: Dictionary = {}


func ensure_defaults(lineup: RotationLineup) -> void:
	for slot_number in range(1, 7):
		var player_id := lineup.player_at_slot(slot_number)
		if player_id not in defender_positions:
			defender_positions[player_id] = CourtConstants.slot_position(slot_number)
		if player_id not in assignments:
			assignments[player_id] = _default_assignment(player_id, slot_number)


func assignment_for(player_id: int) -> Resource:
	return assignments.get(player_id) as Resource


func set_assignment(player_id: int, assignment: Resource) -> void:
	assignment.player_id = player_id
	assignments[player_id] = assignment


func responsibility_summary(player_id: int) -> String:
	var assignment := assignment_for(player_id)
	if assignment == null:
		return "Unassigned"
	return "%s · %s · %s" % [
		assignment.base_responsibility,
		assignment.seam_responsibility,
		assignment.short_ball_responsibility,
	]


func set_defender_position(player_id: int, position: Vector2) -> void:
	defender_positions[player_id] = Vector2(
		clampf(position.x, 0.06, 0.94),
		clampf(position.y, 0.53, 0.96),
	)


func defender_position(player_id: int, fallback: Vector2) -> Vector2:
	return defender_positions.get(player_id, fallback)


func to_dict() -> Dictionary:
	var positions := {}
	for player_id in defender_positions:
		var position: Vector2 = defender_positions[player_id]
		positions[player_id] = [position.x, position.y]
	var assignment_data := {}
	for player_id in assignments:
		var assignment: Resource = assignments[player_id]
		assignment_data[player_id] = assignment.to_dict()
	return {
		"rotation_number": rotation_number,
		"plan_name": plan_name,
		"block_strategy": block_strategy,
		"floor_system": floor_system,
		"serve_target": serve_target,
		"serve_risk": serve_risk,
		"defender_positions": positions,
		"assignments": assignment_data,
	}


func load_dict(data: Dictionary) -> void:
	rotation_number = clampi(int(data.get("rotation_number", 1)), 1, 6)
	plan_name = str(data.get("plan_name", "Base Defense"))
	block_strategy = str(data.get("block_strategy", "Read Block"))
	floor_system = str(data.get("floor_system", "Perimeter"))
	serve_target = str(data.get("serve_target", "Zone 5"))
	serve_risk = clampf(float(data.get("serve_risk", 0.5)), 0.0, 1.0)
	defender_positions.clear()
	var saved_positions: Dictionary = data.get("defender_positions", {})
	for raw_player_id in saved_positions:
		var coordinates: Array = saved_positions[raw_player_id]
		if coordinates.size() >= 2:
			defender_positions[int(raw_player_id)] = Vector2(
				float(coordinates[0]), float(coordinates[1])
			)
	assignments.clear()
	var saved_assignments: Dictionary = data.get("assignments", {})
	for raw_player_id in saved_assignments:
		var assignment: Resource = DefensiveAssignmentModel.from_dict(
			saved_assignments[raw_player_id]
		)
		assignments[int(raw_player_id)] = assignment


func _default_assignment(player_id: int, slot_number: int) -> Resource:
	var assignment: Resource = DefensiveAssignmentModel.new()
	assignment.player_id = player_id
	if CourtConstants.is_front_row_slot(slot_number):
		assignment.base_responsibility = "Net defense"
		assignment.read_responsibility = "Read setter and hitter"
		assignment.seam_responsibility = "Close blocking seam"
		assignment.short_ball_responsibility = "Cover tip behind block"
		assignment.emergency_responsibility = "Release to emergency set"
	else:
		assignment.base_responsibility = "Perimeter defense"
		assignment.read_responsibility = "Read hitter shoulder"
		assignment.seam_responsibility = "Own inside seam"
		assignment.short_ball_responsibility = "Step into tip coverage"
		assignment.emergency_responsibility = "Pursue deep deflection"
	return assignment
