extends Node

## Production Match View proof: real GameManager/RallySimulator results are
## played by MatchScreen, paused on live attack/block/dig frames and captured.
## No event, pose, player location or ball trajectory is staged here.

const MATCH_SCREEN := preload("res://scenes/screens/match_screen.tscn")
const RallyEventModel := preload("res://scripts/models/rally_event.gd")

var screen: MatchScreen
var output_dir: String
var capture_prefix: String = ""
var wanted: Dictionary = {}
var saved: Dictionary = {}
var capture_busy: bool = false


func _ready() -> void:
	get_window().size = Vector2i(1280, 720)
	output_dir = _argument("output-dir")
	if output_dir.is_empty():
		output_dir = ProjectSettings.globalize_path("user://gameplay-broadcast")
	DirAccess.make_dir_recursive_absolute(output_dir)
	screen = MATCH_SCREEN.instantiate() as MatchScreen
	add_child(screen)
	screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	screen.playback_frame_available.connect(_capture_live_frame)
	await get_tree().process_frame
	await _run_case("pawa_hito", "Pāwa Hitō", "Spëddigh", 7001)
	await _run_case("taktika", "Taktikã", "Xérvu", 7001)
	print("GAMEPLAY_BROADCAST_OUTPUT=%s" % output_dir)
	get_tree().quit()


func _run_case(prefix: String, home_region: String, opponent_region: String, seed: int) -> void:
	for player_resource in GameManager.players:
		var player := player_resource as VolleyballPlayer
		if player != null:
			player.club_region = home_region
	GameManager.set_opponent_region(opponent_region, 0)
	GameManager.start_new_match(VolleyballMatchFormat.new())
	GameManager.match_state.home_score = 17
	GameManager.match_state.opponent_score = 16
	GameManager.match_state.home_sets = 1
	GameManager.match_state.opponent_sets = 0
	GameManager.match_state.set_number = 2
	var result: RallyResult = _rally_with_action_chain(seed)
	if result == null:
		push_error("No attack/block/dig rally found for %s" % prefix)
		return
	GameManager.record_rally(result)
	capture_prefix = prefix
	wanted = {
		RallyEventModel.EventType.ATTACK: "attack",
		RallyEventModel.EventType.BLOCK: "block",
		RallyEventModel.EventType.DIG: "dig",
	}
	saved.clear()
	screen.configure_match_presentation(home_region, opponent_region, home_region)
	await screen.load_and_play_rally(result, 2.0)
	while capture_busy:
		await get_tree().process_frame
	for event_type in wanted:
		if not saved.has(event_type):
			push_error("Missing %s capture for %s" % [str(wanted[event_type]), prefix])


func _rally_with_action_chain(seed_start: int) -> RallyResult:
	for seed in range(seed_start, seed_start + 120):
		var result := GameManager.resolve_active_rally(seed) as RallyResult
		var present := {}
		for event_resource in result.events:
			var event := event_resource as RallyEvent
			if event != null:
				present[int(event.event_type)] = true
		if present.has(RallyEventModel.EventType.ATTACK) \
				and present.has(RallyEventModel.EventType.BLOCK) \
				and present.has(RallyEventModel.EventType.DIG):
			return result
	return null


func _capture_live_frame(event_type: int, _event_index: int, _progress: float) -> void:
	if capture_busy or not wanted.has(event_type) or saved.has(event_type):
		return
	capture_busy = true
	var filename := "%s_%s.png" % [capture_prefix, str(wanted[event_type])]
	var image := get_tree().root.get_texture().get_image()
	var error := image.save_png(output_dir.path_join(filename))
	if error != OK:
		push_error("Could not save %s: %s" % [filename, error_string(error)])
	else:
		saved[event_type] = true
		print("saved %s" % output_dir.path_join(filename))
	capture_busy = false


func _argument(key: String) -> String:
	var prefix := "--%s=" % key
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with(prefix):
			return argument.trim_prefix(prefix)
	return ""
