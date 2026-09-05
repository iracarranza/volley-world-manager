extends Node

## Visible playback for a hand-authored rally file. Run with a renderer:
##
##   xvfb-run -a godot --path . --rendering-method gl_compatibility \
##       res://tools/authored_playback.tscn -- \
##       res://tools/authored_rallies/probe_rally.json

const MATCH_SCREEN := preload("res://scenes/screens/match_screen.tscn")
const MANAGER := preload("res://scripts/managers/game_manager.gd")
const DRIVER := preload("res://scripts/simulation/scripted_rally_driver.gd")
const DEFAULT_SCRIPT := "res://tools/authored_rallies/probe_rally.json"

var _feedback: Label
var _requested_speed: float = 1.0
var _replay_mode: bool = false


func _ready() -> void:
	get_window().size = Vector2i(1280, 800)
	var script_path := _parse_arguments()
	var loaded := DRIVER.load_script_file(script_path)
	_build_feedback_panel()
	if not bool(loaded.get("ok", false)):
		_show_refusal(script_path, str(loaded.get("error", "unknown load error")))
		await get_tree().create_timer(8.0).timeout
		get_tree().quit(1)
		return
	var script: Dictionary = loaded.script
	var manager = MANAGER.new()
	manager.seed_vertical_slice_data()
	var driver = DRIVER.new()
	var result: RallyResult = driver.resolve_script(
		script, manager.players, manager.current_lineup(), manager.opponent_team,
		manager.current_defensive_plan()) as RallyResult
	if result == null:
		_show_refusal(script_path, driver.last_refusal)
		manager.free()
		await get_tree().create_timer(8.0).timeout
		get_tree().quit(1)
		return
	var seam := DRIVER.seam_census(result.events)
	_show_resolution(script_path, script, result, seam)
	var screen := MATCH_SCREEN.instantiate() as MatchScreen
	add_child(screen)
	move_child(screen, 0)
	await get_tree().process_frame
	## The feedback CanvasLayer stays above the ordinary production playback.
	await screen.load_and_play_rally(result, _requested_speed, _replay_mode)
	await get_tree().create_timer(3.0).timeout
	manager.free()
	get_tree().quit(0 if seam.is_empty() else 1)


func _parse_arguments() -> String:
	var arguments := OS.get_cmdline_user_args()
	var script_path := DEFAULT_SCRIPT
	for argument in arguments:
		var value := str(argument)
		if value.begins_with("--speed="):
			_requested_speed = clampf(float(value.trim_prefix("--speed=")), 0.1, 4.0)
		elif value == "--replay":
			_replay_mode = true
		elif not value.begins_with("--"):
			script_path = value
	return script_path


func _build_feedback_panel() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 20
	add_child(layer)
	var panel := PanelContainer.new()
	panel.position = Vector2(18.0, 18.0)
	panel.size = Vector2(470.0, 250.0)
	layer.add_child(panel)
	_feedback = Label.new()
	_feedback.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_feedback.add_theme_font_size_override("font_size", 16)
	panel.add_child(_feedback)


func _show_refusal(path: String, reason: String) -> void:
	var message := "AUTHORED RALLY REFUSED\n%s\n\n%s" % [path, reason]
	_feedback.text = message
	print(message)


func _show_resolution(
	path: String, script: Dictionary, result: RallyResult, seam: String,
) -> void:
	var lines: Array[String] = [
		"AUTHORED RALLY  %s" % path.get_file(),
		"seed %d  |  seam %s" % [int(script.get("seed", 1)), "OK" if seam.is_empty() else seam],
		"",
	]
	for raw_record in Array(result.analysis.get("scripted_intents", [])):
		var record: Dictionary = raw_record
		var line := "%d  %-7s  %-9s" % [
			int(record.actor), str(record.action), str(record.status).to_upper(),
		]
		var reason := str(record.get("reason", ""))
		if not reason.is_empty():
			line += " — %s" % reason
		lines.append(line)
	_feedback.text = "\n".join(lines)
	print(_feedback.text)
