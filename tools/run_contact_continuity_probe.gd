extends SceneTree

## Does the ball end up where the next contact happens?
##
## Reported from watching a rally: playback credited the libero with a
## reception while the libero's model was never in that position, the receive
## appeared to teleport to the setter, and the spike's trajectory ended at the
## setter's spot rather than tracing where the ball went.
##
## Those are three descriptions of one geometry, and it is checkable without
## running playback at all. Every contact draws a ball from its own
## `start_position` to its own `end_position`, and the *next* contact begins at
## its own `start_position`. If those two disagree, the ball visibly finishes
## somewhere nobody is standing, and the player credited with the next touch
## plays it from elsewhere.
##
## A second gap sits underneath it. Playback drives the next actor to
## `movement_target`, not to `start_position`. Where those disagree, the actor
## walks somewhere other than the point their own contact is recorded at.
##
## Run:
##   godot --headless --path . --script res://tools/run_contact_continuity_probe.gd

const GameManagerScript := preload("res://scripts/managers/game_manager.gd")
const RallyEventScript := preload("res://scripts/models/rally_event.gd")

const PAIRINGS: int = 1
const RALLIES: int = 90

## The court, for turning normalised gaps into metres.
const COURT_WIDTH_M: float = 9.0
const COURT_LENGTH_M: float = 18.0

## Below this the two points are the same point.
const NEGLIGIBLE_M: float = 0.15


func _initialize() -> void:
	var ball_gaps: Array[float] = []
	var target_gaps: Array[float] = []
	var by_pair := {}
	var worst := {}
	for pairing in range(PAIRINGS):
		for serving_home in [true, false]:
			var manager: Object = GameManagerScript.new()
			manager.seed_vertical_slice_data()
			manager.match_state.serving_home = serving_home
			for seed_value in range(7000, 7000 + RALLIES):
				var result: Resource = manager.resolve_active_rally(seed_value)
				if result == null:
					continue
				_collect(result, ball_gaps, target_gaps, by_pair, worst, seed_value)
			manager.free()

	print("contact pairs sampled: %d" % ball_gaps.size())
	print("")
	_report("ball lands vs next contact begins, metres", ball_gaps)
	print("")
	_report("contact point vs where the actor is driven, metres", target_gaps)
	print("")
	print("=== gap by which contact follows which, metres ===")
	print("%-26s %6s %8s %8s %8s" % ["pair", "n", "mean", "p90", "max"])
	for key in by_pair:
		var values: Array = by_pair[key]
		values.sort()
		var total := 0.0
		for value in values:
			total += float(value)
		print(
			"%-26s %6d %8.2f %8.2f %8.2f"
			% [
				key, values.size(), total / float(values.size()),
				float(values[int(values.size() * 0.9)]),
				float(values[values.size() - 1]),
			]
		)
	if not worst.is_empty():
		print("")
		print("=== worst single case ===")
		for key in worst:
			print("  %-22s %s" % [key, worst[key]])
	quit()


func _collect(
	result: Resource,
	ball_gaps: Array[float],
	target_gaps: Array[float],
	by_pair: Dictionary,
	worst: Dictionary,
	seed_value: int,
) -> void:
	var contacts: Array = []
	for raw_event in result.events:
		var event: Resource = raw_event
		if int(event.event_type) in [
			RallyEventScript.EventType.SET_DECISION,
			RallyEventScript.EventType.POINT,
		]:
			continue
		contacts.append(event)
	for index in range(contacts.size() - 1):
		var event: Resource = contacts[index]
		var next_event: Resource = contacts[index + 1]
		var gap := _metres(
			Vector2(event.end_position), Vector2(next_event.start_position)
		)
		ball_gaps.append(gap)
		var key := "%s -> %s" % [event.type_name(), next_event.type_name()]
		if not by_pair.has(key):
			by_pair[key] = []
		(by_pair[key] as Array).append(gap)
		if next_event.metadata.has("movement_target"):
			target_gaps.append(_metres(
				Vector2(next_event.start_position),
				Vector2(next_event.metadata["movement_target"]),
			))
		if gap > float(worst.get("distance_m", 0.0)):
			worst = worst
			worst["distance_m"] = gap
			worst["seed"] = seed_value
			worst["pair"] = key
			worst["ball_ends_at"] = str(Vector2(event.end_position))
			worst["next_begins_at"] = str(Vector2(next_event.start_position))
			worst["next_actor"] = str(next_event.actor_name)


## Normalised court coordinates into metres, so a gap is a distance somebody can
## picture rather than a fraction.
func _metres(a: Vector2, b: Vector2) -> float:
	return Vector2(
		(a.x - b.x) * COURT_WIDTH_M, (a.y - b.y) * COURT_LENGTH_M
	).length()


func _report(label: String, values: Array[float]) -> void:
	if values.is_empty():
		print("%s: no samples" % label)
		return
	values.sort()
	var total := 0.0
	var apart := 0
	for value in values:
		total += value
		if value > NEGLIGIBLE_M:
			apart += 1
	print("=== %s, n=%d ===" % [label, values.size()])
	print(
		"  mean %.2f   p50 %.2f   p90 %.2f   p99 %.2f   max %.2f"
		% [
			total / float(values.size()),
			values[values.size() / 2],
			values[int(values.size() * 0.9)],
			values[int(values.size() * 0.99)],
			values[values.size() - 1],
		]
	)
	print(
		"  %d of %d (%.0f%%) are more than %.2f m apart"
		% [apart, values.size(), 100.0 * float(apart) / float(values.size()), NEGLIGIBLE_M]
	)
