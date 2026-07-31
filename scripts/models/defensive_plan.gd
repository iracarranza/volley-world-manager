class_name DefensivePlan
extends Resource

const DefensiveAssignmentModel := preload("res://scripts/models/defensive_assignment.gd")
const DefensiveZoneModel := preload("res://scripts/models/defensive_zone.gd")

@export_range(1, 6) var rotation_number: int = 1
@export var plan_name: String = "Base Defense"
@export var block_strategy: String = "Read Block"
@export var floor_system: String = "Perimeter"
@export var preset_modified: bool = false
@export_enum("Balanced", "Defend Line", "Defend Cross") var block_defense_relationship := "Balanced"
@export_enum("Shallow", "Balanced", "Deep") var defensive_depth := "Balanced"
@export_enum("Standard", "Compress Short") var short_ball_posture := "Standard"
@export var serve_target: String = "Zone 5"
@export_range(0.0, 1.0) var serve_risk: float = 0.5
@export var defender_positions: Dictionary = {}
@export var assignments: Dictionary = {}
@export var reception_zones: Dictionary = {}
@export var floor_defense_zones: Dictionary = {}
@export var setter_release_targets: Dictionary = {}


func ensure_defaults(lineup: RotationLineup) -> void:
	for slot_number in range(1, 7):
		var player_id := lineup.player_at_slot(slot_number)
		if player_id not in defender_positions:
			defender_positions[player_id] = CourtConstants.slot_position(slot_number)
		if player_id not in assignments:
			assignments[player_id] = _default_assignment(player_id, slot_number)
		if player_id not in reception_zones:
			reception_zones[player_id] = _default_zone(
				player_id, slot_number, DefensiveZoneModel.ZoneType.SERVE_RECEIVE,
				lineup
			)
		if player_id not in floor_defense_zones:
			floor_defense_zones[player_id] = _default_zone(
				player_id, slot_number, DefensiveZoneModel.ZoneType.FLOOR_DEFENSE,
				lineup
			)
		if player_id == lineup.active_setter_id() and player_id not in setter_release_targets:
			setter_release_targets[player_id] = Vector2(0.50, 0.60)
	_normalize_row_assignments(lineup)


func setter_release_target(player_id: int) -> Vector2:
	return setter_release_targets.get(player_id, Vector2(0.50, 0.60))


func set_setter_release_target(player_id: int, position: Vector2) -> void:
	setter_release_targets[player_id] = Vector2(
		clampf(position.x, 0.12, 0.88), clampf(position.y, 0.52, 0.68)
	)
	preset_modified = true


func apply_floor_preset(preset_name: String, lineup: RotationLineup) -> void:
	floor_system = preset_name
	preset_modified = false
	var positions: Dictionary = {
		"Perimeter": {
			1: Vector2(0.80, 0.87), 2: Vector2(0.78, 0.60), 3: Vector2(0.50, 0.60),
			4: Vector2(0.22, 0.60), 5: Vector2(0.20, 0.87), 6: Vector2(0.50, 0.91),
		},
		"Middle-Up": {
			1: Vector2(0.80, 0.88), 2: Vector2(0.76, 0.60), 3: Vector2(0.50, 0.59),
			4: Vector2(0.24, 0.60), 5: Vector2(0.20, 0.88), 6: Vector2(0.50, 0.73),
		},
		"Rotation Defense": {
			1: Vector2(0.72, 0.86), 2: Vector2(0.78, 0.60), 3: Vector2(0.50, 0.59),
			4: Vector2(0.22, 0.60), 5: Vector2(0.15, 0.78), 6: Vector2(0.44, 0.89),
		},
	}.get(preset_name, {})
	for slot_number in range(1, 7):
		var player_id := lineup.player_at_slot(slot_number)
		var position: Vector2 = positions.get(slot_number, CourtConstants.slot_position(slot_number))
		defender_positions[player_id] = position
		var zone: Resource = floor_defense_zones.get(player_id) as Resource
		if zone != null:
			zone.center = position
			zone.priority = 3 if slot_number in [1, 5, 6] else 1
			zone.radius_meters = 3.3 if slot_number in [1, 5, 6] else 2.1
	_normalize_row_assignments(lineup)


func _normalize_row_assignments(lineup: RotationLineup) -> void:
	for slot_number in range(1, 7):
		var player_id := lineup.player_at_slot(slot_number)
		var assignment: Resource = assignments.get(player_id) as Resource
		if assignment != null:
			assignment.block_participation = CourtConstants.is_front_row_slot(slot_number)


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
	preset_modified = true


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
		"preset_modified": preset_modified,
		"block_defense_relationship": block_defense_relationship,
		"defensive_depth": defensive_depth,
		"short_ball_posture": short_ball_posture,
		"serve_target": serve_target,
		"serve_risk": serve_risk,
		"defender_positions": positions,
		"assignments": assignment_data,
		"reception_zones": _zones_to_dict(reception_zones),
		"floor_defense_zones": _zones_to_dict(floor_defense_zones),
		"setter_release_targets": _positions_to_dict(setter_release_targets),
	}


func load_dict(data: Dictionary) -> void:
	rotation_number = clampi(int(data.get("rotation_number", 1)), 1, 6)
	plan_name = str(data.get("plan_name", "Base Defense"))
	block_strategy = str(data.get("block_strategy", "Read Block"))
	floor_system = str(data.get("floor_system", "Perimeter"))
	preset_modified = bool(data.get("preset_modified", false))
	block_defense_relationship = str(data.get("block_defense_relationship", "Balanced"))
	defensive_depth = str(data.get("defensive_depth", "Balanced"))
	short_ball_posture = str(data.get("short_ball_posture", "Standard"))
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
	setter_release_targets = _positions_from_dict(data.get("setter_release_targets", {}))


func _positions_to_dict(positions: Dictionary) -> Dictionary:
	var result := {}
	for player_id in positions:
		var position: Vector2 = positions[player_id]
		result[player_id] = [position.x, position.y]
	return result


func _positions_from_dict(data: Dictionary) -> Dictionary:
	var result := {}
	for raw_player_id in data:
		var coordinates: Array = data[raw_player_id]
		if coordinates.size() >= 2:
			result[int(raw_player_id)] = Vector2(float(coordinates[0]), float(coordinates[1]))
	return result


func _default_assignment(player_id: int, slot_number: int) -> Resource:
	var assignment: Resource = DefensiveAssignmentModel.new()
	assignment.player_id = player_id
	if CourtConstants.is_front_row_slot(slot_number):
		assignment.base_responsibility = "Net defense"
		assignment.seam_responsibility = "Close blocking seam"
		assignment.short_ball_responsibility = "Cover tip behind block"
		assignment.emergency_responsibility = "Release to emergency set"
		assignment.attack_coverage_responsibility = "Cover nearest attacker"
		assignment.second_contact_responsibility = (
			"Primary emergency setter" if slot_number == 2 else "No second-contact duty"
		)
	else:
		assignment.base_responsibility = "Perimeter defense"
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


func _default_zone(
	player_id: int,
	slot_number: int,
	zone_type: int,
	lineup: RotationLineup = null,
) -> Resource:
	var zone: Resource = DefensiveZoneModel.new()
	zone.player_id = player_id
	zone.zone_type = zone_type
	zone.center = CourtConstants.slot_position(slot_number)
	var front_row := CourtConstants.is_front_row_slot(slot_number)
	if zone_type == DefensiveZoneModel.ZoneType.SERVE_RECEIVE:
		var setter_slot := -1
		var libero_slot := -1
		if lineup != null:
			setter_slot = lineup.slot_for_player(lineup.active_setter_id())
		var formation := CourtConstants.serve_receive_formation(
			setter_slot, CourtConstants.DEFAULT_SERVE_RECEIVE_FORMATION, libero_slot
		)
		zone.center = Vector2(formation.get(
			slot_number, CourtConstants.slot_position(slot_number)
		))
		## The setter is shielded, never a primary passer, in either row. This is
		## the whole point of the shield: previously a back-row setter was
		## enrolled as a passer purely because they were not front row.
		var is_setter := setter_slot >= 1 and slot_number == setter_slot
		var passer_slots := CourtConstants.serve_receive_passer_slots(
			setter_slot,
			int(CourtConstants.SERVE_RECEIVE_FORMATIONS[
				CourtConstants.DEFAULT_SERVE_RECEIVE_FORMATION
			]["passer_count"]),
			libero_slot,
		)
		zone.enabled = (not is_setter) and slot_number in passer_slots
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
