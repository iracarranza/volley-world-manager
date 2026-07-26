class_name DefensivePlan
extends Resource

const DefensiveAssignmentModel := preload("res://scripts/models/defensive_assignment.gd")
const DefensiveZoneModel := preload("res://scripts/models/defensive_zone.gd")

@export_range(1, 6) var rotation_number: int = 1
@export var plan_name: String = "Base Defense"
@export var block_strategy: String = "Read Block"
@export var floor_system: String = "Perimeter"
@export var serve_target: String = "Zone 5"
@export_range(0.0, 1.0) var serve_risk: float = 0.5
@export var defender_positions: Dictionary = {}
@export var assignments: Dictionary = {}
@export var reception_zones: Dictionary = {}
@export var floor_defense_zones: Dictionary = {}


func ensure_defaults(lineup: RotationLineup) -> void:
	for slot_number in range(1, 7):
		var player_id := lineup.player_at_slot(slot_number)
		if player_id not in defender_positions:
			defender_positions[player_id] = CourtConstants.slot_position(slot_number)
		if player_id not in assignments:
			assignments[player_id] = _default_assignment(player_id, slot_number)
		if player_id not in reception_zones:
			reception_zones[player_id] = _default_zone(
				player_id, slot_number, DefensiveZoneModel.ZoneType.SERVE_RECEIVE
			)
		if player_id not in floor_defense_zones:
			floor_defense_zones[player_id] = _default_zone(
				player_id, slot_number, DefensiveZoneModel.ZoneType.FLOOR_DEFENSE
			)


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
	var floor_zone: Resource = floor_defense_zones.get(player_id) as Resource
	if floor_zone != null:
		floor_zone.center = defender_positions[player_id]


func defender_position(player_id: int, fallback: Vector2) -> Vector2:
	return defender_positions.get(player_id, fallback)


func zones_for(zone_type: int) -> Dictionary:
	return reception_zones if zone_type == DefensiveZoneModel.ZoneType.SERVE_RECEIVE \
		else floor_defense_zones


func zone_for(player_id: int, zone_type: int) -> Resource:
	return zones_for(zone_type).get(player_id) as Resource


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
		"reception_zones": _zones_to_dict(reception_zones),
		"floor_defense_zones": _zones_to_dict(floor_defense_zones),
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
	reception_zones = _zones_from_dict(data.get("reception_zones", {}))
	floor_defense_zones = _zones_from_dict(data.get("floor_defense_zones", {}))


func _default_assignment(player_id: int, slot_number: int) -> Resource:
	var assignment: Resource = DefensiveAssignmentModel.new()
	assignment.player_id = player_id
	if CourtConstants.is_front_row_slot(slot_number):
		assignment.base_responsibility = "Net defense"
		assignment.read_responsibility = "Read setter and hitter"
		assignment.seam_responsibility = "Close blocking seam"
		assignment.short_ball_responsibility = "Cover tip behind block"
		assignment.emergency_responsibility = "Release to emergency set"
		assignment.attack_coverage_responsibility = "Cover nearest attacker"
		assignment.second_contact_responsibility = (
			"Primary emergency setter" if slot_number == 2 else "No second-contact duty"
		)
	else:
		assignment.base_responsibility = "Perimeter defense"
		assignment.read_responsibility = "Read hitter shoulder"
		assignment.seam_responsibility = "Own inside seam"
		assignment.short_ball_responsibility = "Step into tip coverage"
		assignment.emergency_responsibility = "Pursue deep deflection"
		assignment.attack_coverage_responsibility = "Cover assigned hitter"
		assignment.second_contact_responsibility = (
			"Secondary emergency setter" if slot_number == 1 else "No second-contact duty"
		)
	return assignment


func set_zone(
	player_id: int,
	zone_type: int,
	radius_meters: float,
	priority: int,
	enabled: bool,
) -> void:
	var zone: Resource = zone_for(player_id, zone_type)
	if zone == null:
		return
	zone.radius_meters = clampf(radius_meters, 0.5, 6.0)
	zone.priority = clampi(priority, 0, 3)
	zone.enabled = enabled


func set_zone_center(player_id: int, zone_type: int, position: Vector2) -> void:
	var zone: Resource = zone_for(player_id, zone_type)
	if zone == null:
		return
	zone.center = Vector2(
		clampf(position.x, 0.06, 0.94),
		clampf(position.y, 0.53, 0.96),
	)
	if zone_type == DefensiveZoneModel.ZoneType.FLOOR_DEFENSE:
		defender_positions[player_id] = zone.center


func _default_zone(player_id: int, slot_number: int, zone_type: int) -> Resource:
	var zone: Resource = DefensiveZoneModel.new()
	zone.player_id = player_id
	zone.zone_type = zone_type
	zone.center = CourtConstants.slot_position(slot_number)
	var front_row := CourtConstants.is_front_row_slot(slot_number)
	if zone_type == DefensiveZoneModel.ZoneType.SERVE_RECEIVE:
		zone.enabled = not front_row
		zone.radius_meters = 3.2
		zone.priority = 2 if slot_number in [5, 6] else 1
	else:
		zone.enabled = true
		zone.radius_meters = 3.0 if not front_row else 2.2
		zone.priority = 2 if not front_row else 1
	return zone


func _zones_to_dict(zones: Dictionary) -> Dictionary:
	var result := {}
	for player_id in zones:
		result[player_id] = zones[player_id].to_dict()
	return result


func _zones_from_dict(data: Dictionary) -> Dictionary:
	var result := {}
	for raw_player_id in data:
		var zone: Resource = DefensiveZoneModel.from_dict(data[raw_player_id])
		result[int(raw_player_id)] = zone
	return result
