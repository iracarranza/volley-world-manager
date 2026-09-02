extends SceneTree

## Which contact derives a moment earlier than the one before it?
##
## `_stamp_physical_time` floors a derived moment to its predecessor and records
## the correction in `physical_time_floored`. The gate asserts that never has to
## happen. It fired once across the sample after the serve began being sliced at
## the reception, which moves that contact roughly 0.08 s earlier -- so the
## question is which event is now out of order and by how much, not whether the
## floor works.

const MANAGER := preload("res://scripts/managers/game_manager.gd")
const EVENT := preload("res://scripts/models/rally_event.gd")
const RALLIES: int = 60


func _initialize() -> void:
	var fired := 0
	## The gate's own sampling: one manager, both serving sides, seeds 5000-5059.
	var manager = MANAGER.new()
	manager.seed_vertical_slice_data()
	for serving_home in [true, false]:
		manager.match_state.serving_home = serving_home
		for index in range(RALLIES):
			var result: Resource = manager.resolve_active_rally(5000 + index)
			if result == null:
				continue
			_scan(result, 5000 + index)
	print("\n%d corrections found" % _fired)
	quit()


var _fired := 0


func _scan(result: Resource, seed_value: int) -> void:
	var previous_kind := "-"
	for raw in result.events:
		var event: Resource = raw
		if event == null:
			continue
		var kind := str(EVENT.EventType.keys()[int(event.event_type)])
		if event.metadata.has("physical_time_floored"):
			_fired += 1
			print("seed %d  %s after %s  floored by %.4f s  side=%s" % [
				seed_value, kind, previous_kind,
				float(event.metadata["physical_time_floored"]),
				str(event.metadata.get("side", "-")),
			])
			print("    event_time=%s  outgoing.start=%s" % [
				event.metadata.get("event_time", "-"),
				Dictionary(event.metadata.get("outgoing_trajectory", {})).get(
					"start_time", "-"),
			])
		previous_kind = kind
