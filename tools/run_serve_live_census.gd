extends SceneTree

## Every live serve, with the execution draws that made it.
##
##     godot --headless --path . --script res://tools/run_serve_live_census.gd
##
## The ecological half of the certification. `run_serve_certification.gd` holds
## personnel fixed and varies one factor at a time; this one lets the vertical
## slice serve as itself, which is the only way to ask why the two sides differ.
##
## **The draws are reproduced, not published.** `_canonical_serve` seeds its
## private stream with `hash("<seed>|serve|<key>|<id>")` before pulling bearing,
## vertical and power, so the same three numbers can be regenerated here from the
## rally seed and the server's id without the simulator having to hand them over.
## Nothing in production changed to make this measurable, which is the point --
## an instrument that requires the subject to be modified is measuring the
## modification.
##
## A fresh `GameManager` per rally: rotation, fatigue and match flow otherwise
## carry between seeds and one divergence reads as a broad effect.

const GameManagerScript := preload("res://scripts/managers/game_manager.gd")
const RallyEventScript := preload("res://scripts/models/rally_event.gd")
const GeometricAttackPromotion := preload(
	"res://scripts/simulation/geometric_attack_promotion.gd"
)

const FIRST_SEED: int = 20000
const SEED_COUNT: int = 400


func _initialize() -> void:
	var rows: Array[String] = []
	rows.append(
		"side|seed|server|style|power|technique|consistency|placement|aggression"
		+ "|outcome|reason|ace|speed|angle|vx|vy|clear|contact_h|dur|mode"
		+ "|aim_x|aim_y|land_x|land_y|target_err|depth|recv_q|serve_mode"
		+ "|draw_power|draw_vertical|draw_bearing"
	)
	for serving_home in [false, true]:
		for seed_value in range(FIRST_SEED, FIRST_SEED + SEED_COUNT):
			var row := _row(serving_home, seed_value)
			if not row.is_empty():
				rows.append(row)
	var path := "user://serve_live_census.csv"
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string("\n".join(rows))
	file.close()
	print("wrote %s (%d serves)" % [
		ProjectSettings.globalize_path(path), rows.size() - 1])
	quit()


func _row(serving_home: bool, seed_value: int) -> String:
	var manager: Object = GameManagerScript.new()
	manager.seed_vertical_slice_data()
	manager.match_state.serving_home = serving_home
	var result: Resource = manager.resolve_active_rally(seed_value)
	if result == null:
		manager.free()
		return ""
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
		return ""
	var side := "home" if serving_home else "opp"
	var server_id := int(serve.metadata.get("server_id", -1))
	var server := _server_by_id(manager, server_id, serving_home)
	var trajectory: Dictionary = serve.metadata.get("outgoing_trajectory", {})
	var shadow: Dictionary = result.analysis.get(
		"geometric_serve_%s" % ("home" if serving_home else "opponent"), {}
	)
	## The same seed, the same key, the same order the resolver pulled them in.
	var draw_rng := RandomNumberGenerator.new()
	draw_rng.seed = hash("%d|serve|geometric_serve_%s|%d" % [
		seed_value, "home" if serving_home else "opponent", server_id,
	])
	var draws: Dictionary = GeometricAttackPromotion.serve_draws(draw_rng)
	var aim := Vector2(serve.metadata.get("aim_point", Vector2.ZERO))
	var landing: Vector2 = serve.end_position
	var depth := (CourtConstants.NET_Y - landing.y) / CourtConstants.NET_Y \
		if serving_home \
		else (landing.y - CourtConstants.NET_Y) / (1.0 - CourtConstants.NET_Y)
	var row := "%s|%d|%d|%s|%d|%d|%d|%d|%d|%s|%s|%s" % [
		side, seed_value, server_id,
		str(serve.metadata.get("serve_style", "?")),
		int(server.serve_power) if server != null else -1,
		int(server.serve_technique) if server != null else -1,
		int(server.serve_consistency) if server != null else -1,
		int(server.serve_placement) if server != null else -1,
		int(server.serve_aggression) if server != null else -1,
		"in" if str(result.terminal_outcome) != "serve_error" else "error",
		str(serve.metadata.get("serve_out_reason", "")),
		"1" if str(result.terminal_outcome) == "ace" else "0",
	]
	row += "|%.4f|%.3f|%.4f|%.4f|%.4f|%.4f|%.4f|%s" % [
		float(trajectory.get("launch_speed_mps", -1.0)),
		float(trajectory.get("launch_angle_degrees", -1.0)),
		float(trajectory.get("launch_horizontal_mps", -1.0)),
		float(trajectory.get("launch_vertical_mps", -1.0)),
		float(serve.metadata.get("net_clearance_meters", -99.0)),
		float(trajectory.get("start_height_meters", -1.0)),
		float(trajectory.get("duration", -1.0)),
		str(shadow.get("launch_mode", "-")),
	]
	row += "|%.5f|%.5f|%.5f|%.5f|%.4f|%.4f|%.6f|%s|%+.4f|%+.4f|%+.4f" % [
		aim.x, aim.y, landing.x, landing.y,
		_court_distance(landing, aim), depth, reception_quality,
		str(serve.metadata.get("serve_mode", "?")),
		float(draws.power), float(draws.vertical), float(draws.bearing),
	]
	manager.free()
	return row


func _server_by_id(
	manager: Object, server_id: int, serving_home: bool
) -> VolleyballPlayer:
	## The home squad is the manager's own player list -- `VolleyballTeam` carries
	## ids, not bodies -- while the opponent's is on the opponent team itself.
	var roster: Array = manager.players if serving_home \
		else manager.opponent_team.players
	for entry in roster:
		var player := entry as VolleyballPlayer
		if player != null and int(player.id) == server_id:
			return player
	return null


func _court_distance(from_point: Vector2, to_point: Vector2) -> float:
	return Vector2(
		(to_point.x - from_point.x) * CourtConstants.COURT_WIDTH_METERS,
		(to_point.y - from_point.y) * CourtConstants.COURT_LENGTH_METERS,
	).length()
