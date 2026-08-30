extends SceneTree

## Seed-for-seed gameplay census for the serve/contact semantics correction.
## Pass a label after `--`; it becomes part of the user-data CSV filename.

const GameManagerScript := preload("res://scripts/managers/game_manager.gd")
const RallyEventScript := preload("res://scripts/models/rally_event.gd")


func _initialize() -> void:
	var label := "current"
	var args := OS.get_cmdline_user_args()
	if not args.is_empty():
		label = str(args[0]).validate_filename()
	var rows: Array[String] = [
		"side|seed|style|serve_error|reason|clearance|natural_duration"
		+ "|played_duration|reception_time|receiver|terminal|home_won"
	]
	for serving_home in [false, true]:
		for seed_value in range(20000, 20400):
			var manager := GameManagerScript.new()
			manager.seed_vertical_slice_data()
			manager.match_state.serving_home = serving_home
			var result: Resource = manager.resolve_active_rally(seed_value)
			rows.append(_row(result, serving_home, seed_value))
			manager.free()
	var path := "user://ball_contact_outcomes_%s.csv" % label
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string("\n".join(rows))
	file.close()
	print("wrote %s (%d rallies)" % [
		ProjectSettings.globalize_path(path), rows.size() - 1,
	])
	quit()


func _row(result: Resource, serving_home: bool, seed_value: int) -> String:
	var serve: Resource = null
	var reception: Resource = null
	for raw_event in result.events:
		var event: Resource = raw_event
		if serve == null and int(event.event_type) == RallyEventScript.EventType.SERVE:
			serve = event
		elif reception == null \
				and int(event.event_type) == RallyEventScript.EventType.RECEPTION:
			reception = event
	var metadata: Dictionary = serve.metadata
	var trajectory: Dictionary = metadata.get("outgoing_trajectory", {})
	var played := float(trajectory.get("duration", metadata.get("flight_time", 0.0)))
	var natural := float(metadata.get("natural_flight_time", played))
	return "%s|%d|%s|%d|%s|%.6f|%.6f|%.6f|%.6f|%d|%s|%d" % [
		"home" if serving_home else "opp", seed_value,
		str(metadata.get("serve_style", "")),
		1 if str(result.terminal_outcome) == "serve_error" else 0,
		str(metadata.get("serve_out_reason", "")),
		float(metadata.get("net_clearance_meters", 0.0)),
		natural, played,
		float(reception.metadata.get("event_time", -1.0)) if reception != null else -1.0,
		int(reception.actor_id) if reception != null else -1,
		str(result.terminal_outcome), 1 if bool(result.home_team_won) else 0,
	]
