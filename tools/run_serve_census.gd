extends SceneTree

## Everything one serve is, on both sides of the net, for one seed range.
##
##     godot --headless --path . --script res://tools/run_serve_census.gd
##
## **A fresh manager per rally.** Rotation, fatigue and match flow carry between
## rallies on a reused `GameManager`, so a single early divergence cascades and
## reads as a broad effect -- the mistake the dig lineage probe made and this
## repository's process rule #9. Each seed here gets its own manager, so a
## before/after difference is that rally's own.
##
## The columns are the ones the serve pass has to report movement in: pace,
## launch angle, the two velocity components, net clearance, landing, duration,
## the error verdict and its reason, whether it was an ace, what the reception
## made of it, and how long the rally ran. The shadow's own verdict is carried
## alongside, because the whole question of this pass is which of the two was
## the authority.

const GameManagerScript := preload("res://scripts/managers/game_manager.gd")
const RallyEventScript := preload("res://scripts/models/rally_event.gd")

const FIRST_SEED: int = 20000
const SEED_COUNT: int = 160


func _initialize() -> void:
	var rows: Array[String] = []
	rows.append(
		"side|seed|outcome|events|pace|angle|vx|vy|clear|land_x|land_y|dur"
		+ "|err|err_reason|ace|recv_q|height_src|shadow_out|shadow_pace|shadow_mode"
		+ "|from_x|from_y|aim_x|aim_y|reach"
	)
	for serving_home in [false, true]:
		for seed_value in range(FIRST_SEED, FIRST_SEED + SEED_COUNT):
			rows.append(_census_row(serving_home, seed_value))
	var path := "user://serve_census.csv"
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string("\n".join(rows))
	file.close()
	print("wrote %s (%d rows)" % [
		ProjectSettings.globalize_path(path), rows.size() - 1])
	quit()


func _census_row(serving_home: bool, seed_value: int) -> String:
	var side := "home" if serving_home else "opp"
	var manager: Object = GameManagerScript.new()
	manager.seed_vertical_slice_data()
	manager.match_state.serving_home = serving_home
	var result: Resource = manager.resolve_active_rally(seed_value)
	if result == null:
		manager.free()
		return "%s|%d|null" % [side, seed_value]
	var serve: Resource = null
	var reception_quality := -1.0
	for raw in result.events:
		var event: Resource = raw
		if int(event.event_type) == RallyEventScript.EventType.SERVE and serve == null:
			serve = event
		elif int(event.event_type) == RallyEventScript.EventType.RECEPTION \
				and reception_quality < 0.0:
			reception_quality = float(event.quality)
	if serve == null:
		manager.free()
		return "%s|%d|noserve" % [side, seed_value]
	var trajectory: Dictionary = serve.metadata.get("outgoing_trajectory", {})
	var duration := float(trajectory.get("duration", -1.0))
	## Pace and the two components, from whatever the record actually carries.
	## Before the pass there is no published launch state, so they are derived
	## the only way a reader could derive them -- which is itself the finding.
	var pace := float(serve.metadata.get("launch_speed_mps", -1.0))
	var angle := float(serve.metadata.get("launch_angle_degrees", -1.0))
	var clearance := float(serve.metadata.get("net_clearance_meters", -1.0))
	var err_reason := str(serve.metadata.get("serve_out_reason", ""))
	var horizontal := -1.0
	var vertical := -1.0
	if duration > 0.0:
		horizontal = _court_distance(
			serve.start_position, serve.end_position
		) / duration
	if pace >= 0.0 and angle > -90.0:
		horizontal = pace * cos(deg_to_rad(angle))
		vertical = pace * sin(deg_to_rad(angle))
	var shadow: Dictionary = result.analysis.get(
		"geometric_serve_%s" % ("home" if serving_home else "opponent"), {}
	)
	var errored := str(result.terminal_outcome) == "serve_error"
	var aim := Vector2(serve.metadata.get("aim_point", Vector2.ZERO))
	var row := "%s|%d|%s|%d|%.4f|%.3f|%.4f|%.4f|%.4f|%.5f|%.5f|%.4f|%s|%s|%s|%.6f|%s|%s|%.4f|%s|%.5f|%.5f|%.5f|%.5f|%.4f" % [
		side, seed_value, str(result.terminal_outcome), result.events.size(),
		pace, angle, horizontal, vertical, clearance,
		serve.end_position.x, serve.end_position.y, duration,
		"1" if errored else "0", err_reason,
		"1" if str(result.terminal_outcome) == "ace" else "0",
		reception_quality,
		str(trajectory.get("height_source", "-")),
		str(shadow.get("outcome", "-")),
		float(shadow.get("speed_mps", -1.0)),
		str(shadow.get("launch_mode", "-")),
		serve.start_position.x, serve.start_position.y, aim.x, aim.y,
		_court_distance(serve.start_position, aim),
	]
	manager.free()
	return row


func _court_distance(from_point: Vector2, to_point: Vector2) -> float:
	return Vector2(
		(to_point.x - from_point.x) * CourtConstants.COURT_WIDTH_METERS,
		(to_point.y - from_point.y) * CourtConstants.COURT_LENGTH_METERS,
	).length()
