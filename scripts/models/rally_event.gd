class_name RallyEvent
extends Resource

## **`DEFENSE` was two different contacts wearing one name.** A floor dig and
## attack coverage are opposite situations -- one is a defender reading a swing
## from across the net, the other is a hitter's own team picking up the rebound
## off the block a metre away -- and both were emitted as `DEFENSE` from six
## sites. Every consumer that wanted one of them silently got both: the balance
## probe's dig rate read 0.493 when the floor dig rate was 0.445, because
## coverage succeeds 38 times out of 38 and was being averaged in.
##
## **Ordinals are not persisted, and that was checked before touching this.**
## `to_dict()` writes the raw integer, but its only two callers are the playback
## adapter and a calibration fingerprint, both in-memory; no save file contains
## an event. So `DEFENSE` could be renamed in place, keeping ordinal 6, and
## `ATTACK_COVERAGE` appended rather than inserted -- appending costs nothing and
## keeps `POINT` where it is for anything reading a debug dump.
##
## *Names* are persisted, in one place: `MatchStatistics` keys itself on
## `type_name()`, and that dictionary is saved inside `match_state`. That is
## migrated in `MatchStatistics.load_dict`.
enum EventType {
	SERVE,
	RECEPTION,
	SET_DECISION,
	SET,
	ATTACK,
	BLOCK,
	DIG,
	POINT,
	ATTACK_COVERAGE,
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
