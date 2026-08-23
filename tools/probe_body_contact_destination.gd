extends SceneTree

## Why did publishing `body_contact_position` everywhere move a gate?
##
## `movement_timing_ratio_calibration` measures a leg as
## `movement_start -> body_contact_position`, falling back to the ball's
## `start_position` when the actor's body position is absent. Filling that key
## for reception, dig and coverage therefore changed the destination the gate
## measures to, without changing a single rally. This dumps both candidate
## destinations per event so the difference is read rather than reasoned about.

const MANAGER := preload("res://scripts/managers/game_manager.gd")

const WATCHED := [
	RallyEvent.EventType.RECEPTION,
	RallyEvent.EventType.DIG,
	RallyEvent.EventType.ATTACK_COVERAGE,
	RallyEvent.EventType.SET,
	RallyEvent.EventType.ATTACK,
]


func _initialize() -> void:
	var rows := {}
	for index in range(40):
		var manager = MANAGER.new()
		manager.seed_vertical_slice_data()
		manager.match_state.serving_home = false
		var result: Resource = manager.resolve_active_rally(300000 + index)
		if result == null:
			continue
		for raw_event in result.events:
			var event := raw_event as RallyEvent
			if event == null or int(event.actor_id) < 0:
				continue
			if not event.metadata.has("movement_duration"):
				continue
			if not (int(event.event_type) in WATCHED):
				continue
			var name := str(RallyEvent.EventType.keys()[int(event.event_type)])
			if not rows.has(name):
				rows[name] = {
					"n": 0, "to_ball": 0.0, "to_body": 0.0,
					"body_under_5cm": 0, "ball_under_5cm": 0,
					"body_equals_start": 0, "has_body": 0,
				}
			var row: Dictionary = rows[name]
			row["n"] = int(row["n"]) + 1
			var start := Vector2(event.metadata.get("movement_start", event.start_position))
			var ball := Vector2(event.start_position)
			var has_body: bool = event.metadata.has("body_contact_position")
			var body := Vector2(event.metadata.get("body_contact_position", ball))
			if has_body:
				row["has_body"] = int(row["has_body"]) + 1
			var to_ball := RallyKinematics.court_delta_meters(start, ball).length()
			var to_body := RallyKinematics.court_delta_meters(start, body).length()
			row["to_ball"] = float(row["to_ball"]) + to_ball
			row["to_body"] = float(row["to_body"]) + to_body
			if to_body < 0.05:
				row["body_under_5cm"] = int(row["body_under_5cm"]) + 1
			if to_ball < 0.05:
				row["ball_under_5cm"] = int(row["ball_under_5cm"]) + 1
			var target := Vector2(event.metadata.get("movement_target", body))
			if RallyKinematics.court_delta_meters(body, target).length() > 0.05:
				row["body_equals_start"] = int(row["body_equals_start"]) + 1
	print(
		"%-16s %5s %7s %10s %10s %10s %10s %10s"
		% [
			"phase", "n", "hasbody", "mean->ball", "mean->body",
			"ball<5cm", "body<5cm", "body!=tgt",
		]
	)
	for name in rows:
		var row: Dictionary = rows[name]
		var n := maxi(int(row["n"]), 1)
		print(
			"%-16s %5d %7d %10.3f %10.3f %10d %10d %10d"
			% [
				str(name), int(row["n"]), int(row["has_body"]),
				float(row["to_ball"]) / float(n),
				float(row["to_body"]) / float(n),
				int(row["ball_under_5cm"]), int(row["body_under_5cm"]),
				int(row["body_equals_start"]),
			]
		)
	quit(0)
