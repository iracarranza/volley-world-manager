extends SceneTree

## How long does the ball actually take, per action?
##
##     godot --headless --path . --script res://tools/run_ball_pace_probe.gd
##
## Asked for directly: an uncontested spike should reach the floor in about
## 0.20 s and an elite power hit in about 0.12, with the bump and the set reading
## as control against that. Before any of those becomes a target, the question is
## what the game does now -- and specifically whether the number a viewer
## perceives is the one the model thinks it is.
##
## Three separate things get printed because they are three separate claims:
##
##   **flight seconds** is what a viewer experiences. It is the whole of the
##   report, and it is a function of speed *and* of how far the ball is going --
##   a cut shot four metres in at 25 m/s is quick to arrive and a line shot eight
##   metres deep at the same pace is not. Reporting speed alone would answer a
##   question nobody asked.
##
##   **metres** is why two flights at the same pace feel different, and it is the
##   term that decides whether the 0.20 s target is even reachable: at 6.5 m it
##   needs 33 m/s, at 4 m it needs 20.
##
##   **m/s and km/h** so the ask can be checked against the sport. A men's
##   international spike is measured at 30-37 m/s; the fastest recorded is about
##   37 m/s / 134 km/h. Whatever the game chooses to be, it should choose it
##   knowing where the real number sits.
##
## Split by launch mode as well, because a roll shot is *supposed* to be slow and
## averaging it with a driven ball describes neither.

const GameManagerScript := preload("res://scripts/managers/game_manager.gd")
const RallyEventScript := preload("res://scripts/models/rally_event.gd")

const RALLIES: int = 200
const FIRST_SEED: int = 7000


func _initialize() -> void:
	var buckets := {}
	for serving_home in [true, false]:
		var manager: Object = GameManagerScript.new()
		manager.seed_vertical_slice_data()
		manager.match_state.serving_home = serving_home
		for seed_value in range(FIRST_SEED, FIRST_SEED + RALLIES):
			var result: Resource = manager.resolve_active_rally(seed_value)
			if result == null:
				continue
			_collect(result, buckets)
		manager.free()

	print("=== what the ball does now ===")
	print("")
	## Seconds and metres separately, then speed, because the ask is stated in
	## seconds and seconds are the product of the other two. A cut shot four
	## metres in and a line shot eight metres deep at the same pace are different
	## flight times and the same swing.
	print("%-34s %5s %7s %7s %7s %8s %7s %7s %7s" % [
		"action", "n", "p10 s", "p50 s", "p90 s", "metres",
		"p10 m/s", "p50", "p90",
	])
	var order := [
		"SPIKE untouched, to the floor",
		"  of those, 6 m or deeper",
		"  of those, driven",
		"  of those, lofted",
		"SPIKE untouched, never crossed the net",
		"SPIKE, all swings",
		"SERVE, to reception or floor",
		"SET, to the hitter",
		"BUMP or DIG, to the setter",
	]
	for key in order:
		var rows: Array = buckets.get(key, [])
		if rows.is_empty():
			print("%-34s %5d   --" % [key, 0])
			continue
		var seconds: Array = []
		var speeds: Array = []
		var metres := 0.0
		for row in rows:
			seconds.append(float(row.seconds))
			speeds.append(float(row.speed))
			metres += float(row.metres)
		seconds.sort()
		speeds.sort()
		print("%-34s %5d %7.3f %7.3f %7.3f %8.2f %7.1f %7.1f %7.1f" % [
			key, rows.size(), _at(seconds, 0.10), _at(seconds, 0.50),
			_at(seconds, 0.90), metres / float(rows.size()),
			_at(speeds, 0.10), _at(speeds, 0.50), _at(speeds, 0.90),
		])

	print("")
	print("The ask, against the above:")
	print("  uncontested spike ~0.20 s, elite power hit ~0.12 s.")
	var untouched: Array = buckets.get("SPIKE untouched, to the floor", [])
	if not untouched.is_empty():
		var metres := 0.0
		var quickest := INF
		for row in untouched:
			metres += float(row.metres)
			quickest = minf(quickest, float(row.seconds))
		var mean_metres := metres / float(untouched.size())
		quickest = maxf(quickest, 0.0)
		print("  at the %.2f m a spike currently travels, 0.20 s is %.1f m/s" % [
			mean_metres, mean_metres / 0.20,
		])
		print("  (%.0f km/h) and 0.12 s is %.1f m/s (%.0f km/h)." % [
			mean_metres / 0.20 * 3.6, mean_metres / 0.12,
			mean_metres / 0.12 * 3.6,
		])
		print("  The fastest swing in this sample already arrives in %.3f s." % quickest)
		print("  For reference, the fastest spike ever measured is ~37 m/s.")
	quit()


func _at(sorted_values: Array, quantile: float) -> float:
	return float(sorted_values[clampi(
		int(floor(quantile * float(sorted_values.size() - 1))),
		0, sorted_values.size() - 1,
	)])


func _note(buckets: Dictionary, key: String, row: Dictionary) -> void:
	if not buckets.has(key):
		buckets[key] = []
	(buckets[key] as Array).append(row)


func _collect(result: Resource, buckets: Dictionary) -> void:
	var contacts: Array = []
	for raw_event in result.events:
		var event: Resource = raw_event
		if int(event.event_type) in [
			RallyEventScript.EventType.SET_DECISION,
			RallyEventScript.EventType.POINT,
		]:
			continue
		contacts.append(event)
	var profiles: Dictionary = result.player_physical_profiles
	for index in range(contacts.size()):
		var event: Resource = contacts[index]
		var trajectory: Dictionary = event.metadata.get("outgoing_trajectory", {})
		if trajectory.is_empty():
			continue
		var next_contact: Resource = contacts[index + 1] \
			if index + 1 < contacts.size() else null
		## The screen's own flight, not a reconstruction of it. What a viewer
		## times is the drawn leg, and for a ball nobody touches that is the
		## resolver's flight unchanged -- but saying so is the probe's job, not an
		## assumption it gets to make.
		var display: Dictionary = BallPresentation.display_trajectory(
			event, next_contact, trajectory, profiles
		)
		var seconds := maxf(float(display.get("duration", 0.0)), 0.001)
		var metres := RallyKinematics.court_distance_meters(
			Vector2(display.get("start_position", Vector2.ZERO)),
			Vector2(display.get("end_position", Vector2.ZERO)),
		)
		var row := {
			"seconds": seconds,
			"metres": metres,
			## The whole velocity, not the ground component. A spike is struck
			## downward, so its horizontal speed understates the ball.
			"speed": BallPresentation.launch_speed_mps(display),
		}
		match int(event.event_type):
			RallyEventScript.EventType.ATTACK:
				_note(buckets, "SPIKE, all swings", row)
				## Untouched: nothing played it next, or whatever tried, failed.
				## Both are a ball flying its whole shot to the floor.
				if next_contact == null or not next_contact.success:
					## **A ball that never crossed the net is not a spike to the
					## floor.** A netted swing lands on the hitter's own side about
					## 20 cm past the tape, so it flies a third of a metre and the
					## flight solver floors it at `MIN_FLIGHT_DURATION` -- which is
					## exactly the 0.020 s "fastest spike" the first run of this
					## probe reported, and 325 m/s if it is read as a spike. It is
					## a real event drawn correctly; it is not the thing being
					## measured, and averaging it in makes the fast tail a fiction.
					var start := Vector2(display.get("start_position", Vector2.ZERO))
					var end := Vector2(display.get("end_position", start))
					if (start.y - 0.5) * (end.y - 0.5) > 0.0:
						_note(buckets, "SPIKE untouched, never crossed the net", row)
						continue
					_note(buckets, "SPIKE untouched, to the floor", row)
					## Depth held fixed, so the seconds column is about pace alone.
					## This is the flight the 0.20 s target is really about: a swing
					## hit through the court, not a tip dropped over the tape.
					if metres >= 6.0:
						_note(buckets, "  of those, 6 m or deeper", row)
					var mode := str(event.metadata.get("launch_mode", ""))
					if mode == "driven":
						_note(buckets, "  of those, driven", row)
					elif mode == "lofted":
						_note(buckets, "  of those, lofted", row)
			RallyEventScript.EventType.SERVE:
				_note(buckets, "SERVE, to reception or floor", row)
			RallyEventScript.EventType.SET:
				_note(buckets, "SET, to the hitter", row)
			RallyEventScript.EventType.RECEPTION, RallyEventScript.EventType.DEFENSE:
				_note(buckets, "BUMP or DIG, to the setter", row)
