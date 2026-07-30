class_name RallyEvent
extends Resource

enum EventType {
	SERVE,
	RECEPTION,
	SET_DECISION,
	SET,
	ATTACK,
	BLOCK,
	DEFENSE,
	POINT,
}

@export var sequence: int = 0
@export var event_type: EventType = EventType.SERVE
@export var actor_id: int = -1
@export var secondary_actor_id: int = -1
@export var actor_name: String = ""
@export var start_position: Vector2 = Vector2(0.5, 0.1)
@export var end_position: Vector2 = Vector2(0.5, 0.9)
@export var success: bool = true
@export_range(0.0, 1.0) var quality: float = 0.5
@export var headline: String = ""
@export var detail: String = ""
@export var metadata: Dictionary = {}


func type_name() -> String:
	return EventType.keys()[event_type].capitalize()


func to_dict() -> Dictionary:
	return {
		"sequence": sequence,
		"event_type": event_type,
		"actor_id": actor_id,
		"secondary_actor_id": secondary_actor_id,
		"actor_name": actor_name,
		"start_position": start_position,
		"end_position": end_position,
		"success": success,
		"quality": quality,
		"headline": headline,
		"detail": detail,
		"metadata": metadata.duplicate(true),
	}
