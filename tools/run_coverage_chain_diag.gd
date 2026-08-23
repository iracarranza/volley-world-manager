extends SceneTree

const GameManagerScript := preload("res://scripts/managers/game_manager.gd")
const RallyEventScript := preload("res://scripts/models/rally_event.gd")


func _same(first: Dictionary, second: Dictionary) -> bool:
	return Vector2(first.get("start_position", Vector2.ZERO)).is_equal_approx(
			Vector2(second.get("start_position", Vector2.ONE))
		) and Vector2(first.get("end_position", Vector2.ZERO)).is_equal_approx(
			Vector2(second.get("end_position", Vector2.ONE))
		) and is_equal_approx(
			float(first.get("duration", -1.0)), float(second.get("duration", -2.0))
		)


func _initialize() -> void:
	var shown := 0
	for serving_home in [false, true]:
		for seed_value in range(79000, 79040):
			var manager: Object = GameManagerScript.new()
			manager.seed_vertical_slice_data()
			manager.match_state.serving_home = serving_home
			var rally: Resource = manager.resolve_active_rally(seed_value)
			if rally != null:
				var last_ball := {}
				var last_kind := "-"
				for event in rally.events:
					var kind := int(event.event_type)
					if kind == RallyEventScript.EventType.SET:
						var incoming: Dictionary = event.metadata.get(
							"incoming_trajectory",
							event.metadata.get("incoming_pass_trajectory", {}),
						)
						if not last_ball.is_empty() and not incoming.is_empty():
							if not _same(last_ball, incoming) and shown < 12:
								shown += 1
								print("MISMATCH seed=%d side=%s prev=%s" % [
									seed_value, str(event.metadata.get("side", "?")),
									last_kind])
								print("  last_ball role=%s start=%s end=%s dur=%.4f" % [
									str(last_ball.get("trajectory_role", "-")),
									str(last_ball.get("start_position", "?")),
									str(last_ball.get("end_position", "?")),
									float(last_ball.get("duration", -1.0))])
								print("  incoming  role=%s start=%s end=%s dur=%.4f" % [
									str(incoming.get("trajectory_role", "-")),
									str(incoming.get("start_position", "?")),
									str(incoming.get("end_position", "?")),
									float(incoming.get("duration", -1.0))])
						last_ball = Dictionary(
							event.metadata.get("outgoing_trajectory", {})
						)
						last_kind = "SET"
						continue
					var published: Dictionary = event.metadata.get(
						"outgoing_trajectory", {}
					)
					if not published.is_empty():
						last_ball = published
						last_kind = str(RallyEventScript.EventType.keys()[kind])
			manager.free()
	print("shown %d mismatches" % shown)
	quit()
