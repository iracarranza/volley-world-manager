extends SceneTree

const MANAGER := preload("res://scripts/managers/game_manager.gd")
const DRIVER := preload("res://scripts/simulation/scripted_rally_driver.gd")
const DEFAULT_SCRIPT := "res://tools/authored_rallies/probe_rally.json"


func _initialize() -> void:
	var arguments := OS.get_cmdline_user_args()
	var script_path := str(arguments[0]) if not arguments.is_empty() else DEFAULT_SCRIPT
	var loaded := DRIVER.load_script_file(script_path)
	if not bool(loaded.get("ok", false)):
		print("refusal: %s" % str(loaded.get("error", "unknown load error")))
		quit(1)
		return
	var script: Dictionary = loaded.script
	var manager = MANAGER.new()
	manager.seed_vertical_slice_data()
	var driver = DRIVER.new()
	var result = driver.resolve_script(
		script, manager.players, manager.current_lineup(), manager.opponent_team,
		manager.current_defensive_plan())
	print("file: %s" % script_path)
	print("seed: %d" % int(script.get("seed", 1)))
	print("refusal: %s" % driver.last_refusal)
	print("events: %d" % (result.events.size() if result != null else -1))
	if result != null:
		for event in result.events:
			print("  %s actor=%d intent=%.3f contact=%s height=%s" % [
				event.type_name(), event.actor_id,
				float(event.metadata.get("intent_time", NAN)),
				str(event.metadata.get("resolved_contact_time", "miss")),
				str(event.metadata.get("contact_height_meters", "miss")),
			])
		print("seam: %s" % DRIVER.seam_census(result.events))
		print("intents: %s" % str(result.analysis.get("scripted_intents", [])))
	manager.free()
	quit(0 if result != null and driver.last_refusal.is_empty() else 1)
