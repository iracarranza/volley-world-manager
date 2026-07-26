class_name DefensiveZone
extends Resource

enum ZoneType {
	SERVE_RECEIVE,
	FLOOR_DEFENSE,
}

@export var player_id: int = -1
@export var zone_type: ZoneType = ZoneType.FLOOR_DEFENSE
@export var center: Vector2 = Vector2(0.5, 0.82)
@export_range(0.5, 6.0, 0.1) var radius_meters: float = 3.0
@export_range(0, 3) var priority: int = 1
@export var enabled: bool = true


func to_dict() -> Dictionary:
	return {
		"player_id": player_id,
		"zone_type": int(zone_type),
		"center": [center.x, center.y],
		"radius_meters": radius_meters,
		"priority": priority,
		"enabled": enabled,
	}


static func from_dict(data: Dictionary) -> DefensiveZone:
	var zone := DefensiveZone.new()
	zone.player_id = int(data.get("player_id", -1))
	zone.zone_type = clampi(int(data.get("zone_type", ZoneType.FLOOR_DEFENSE)), 0, 1) as ZoneType
	var saved_center: Array = data.get("center", [0.5, 0.82])
	if saved_center.size() >= 2:
		zone.center = Vector2(float(saved_center[0]), float(saved_center[1]))
	zone.radius_meters = clampf(float(data.get("radius_meters", 3.0)), 0.5, 6.0)
	zone.priority = clampi(int(data.get("priority", 1)), 0, 3)
	zone.enabled = bool(data.get("enabled", true))
	return zone
