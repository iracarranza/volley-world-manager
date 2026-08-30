extends SceneTree

const Events := preload("res://scripts/models/rally_event.gd")
const FROM_SEED: int = 24000
const RALLIES: int = 600


func _initialize() -> void:
	var label := "current"
	var args := OS.get_cmdline_user_args()
	if not args.is_empty(): label = str(args[0]).validate_filename()
	var manager: Object = load("res://scripts/managers/game_manager.gd").new()
	manager.seed_vertical_slice_data()
	var rows: Array[String] = [
		"seed|serving|requested|achieved|release_progress|achieved_release_progress|duration|attack_success|terminal"
	]
	for seed_value in range(FROM_SEED, FROM_SEED + RALLIES):
		var serving_home := seed_value % 2 == 0
		manager.match_state.serving_home = serving_home
		var result: Resource = manager.resolve_active_rally(seed_value)
		for event in result.events:
			if int(event.event_type) != Events.EventType.ATTACK: continue
			var timing: Dictionary = event.metadata.get("tempo_coordination", {})
			if timing.is_empty(): continue
			rows.append("%d|%s|%d|%d|%.6f|%.6f|%.6f|%d|%s" % [
				seed_value, "home" if serving_home else "opponent",
				int(event.metadata.get("requested_tempo", event.metadata.get("tempo", 3))),
				int(timing.get("achieved_tempo", event.metadata.get("achieved_tempo", 3))),
				float(timing.get("release_progress", 0.0)),
				float(timing.get("achieved_release_progress", 0.0)),
				float(timing.get("delivered_flight_seconds", event.metadata.get("set_flight_time", 0.0))),
				1 if bool(event.success) else 0, str(result.terminal_outcome),
			])
	var path := "user://quick_outcomes_%s.csv" % label
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string("\n".join(rows))
	file.close()
	print("wrote %s (%d attacks)" % [ProjectSettings.globalize_path(path), rows.size() - 1])
	manager.free()
	quit()
