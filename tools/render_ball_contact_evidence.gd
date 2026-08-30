extends Node

## Captures real MatchScreen playback at named physical milestones. It accepts
## an explicit temporary serve-style fixture so a roster with no topspin server
## cannot be mistaken for a query failure.

const SCREEN := preload("res://scenes/screens/match_screen.tscn")
const Events := preload("res://scripts/models/rally_event.gd")


func _ready() -> void:
	var args := _parse(OS.get_cmdline_user_args())
	var mode := str(args.get("mode", "serve"))
	var style := str(args.get("style", "Jump Float"))
	var speed := float(args.get("speed", 0.25))
	var seed_value := int(args.get("seed", 24000))
	var label := str(args.get("label", "after")).validate_filename()
	var output := str(args.get("output", "res://artifacts/ball-contact-evidence"))
	get_window().size = Vector2i(1280, 720)
	var screen := SCREEN.instantiate() as MatchScreen
	add_child(screen)
	await get_tree().process_frame
	var manager: Object = load("res://scripts/managers/game_manager.gd").new()
	manager.seed_vertical_slice_data()
	manager.match_state.serving_home = seed_value % 2 == 0
	if mode == "serve": _force_serve_style(manager, style)
	var result: Resource = manager.resolve_active_rally(seed_value)
	if result == null:
		push_error("fixture did not resolve")
		get_tree().quit(1)
		return
	var event_index := 0
	var approach_event_index := -1
	var milestones := {0.08: "launch", 0.50: "midflight", 0.98: "contact"}
	if mode == "quick":
		event_index = _first_quick_set_index(result.events)
		if event_index < 0:
			push_error("seed %d contains no achieved T0/T1 set" % seed_value)
			get_tree().quit(1)
			return
		approach_event_index = _previous_physical_event_index(result.events, event_index)
		print("quick fixture seed %d uses set event index %d of %d" % [
			seed_value, event_index, result.events.size(),
		])
		milestones = {0.02: "setter_release", 0.50: "set_flight", 0.90: "hitter_contact"}
	var captured := {}
	var playback_arguments: Array = [result, speed]
	if not bool(args.get("legacy", false)):
		playback_arguments.append(true)
	screen.callv("load_and_play_rally", playback_arguments)
	while screen.playback_active:
		await get_tree().process_frame
		var raw_progress := float(screen.progress_bar.value) / 100.0
		var global_progress := raw_progress * float(result.events.size())
		var local_progress := global_progress - float(event_index)
		var visible_event := _visible_event_type(screen)
		if mode == "quick" and not captured.has("approach") \
			and approach_event_index >= 0 \
			and global_progress >= float(approach_event_index) + 0.75 \
			and global_progress < float(approach_event_index) + 1.0:
			await _capture(screen, output, "%s_%s_%s_approach" % [label, mode, _speed_label(speed)])
			captured["approach"] = true
		for threshold in milestones:
			var name := str(milestones[threshold])
			if not captured.has(name) \
				and (mode != "quick" or visible_event == "SET") \
				and local_progress >= float(threshold) \
				and local_progress < 1.05:
				await _capture(screen, output, "%s_%s_%s_%s" % [
					label, style.validate_filename() if mode == "serve" else mode,
					_speed_label(speed), name,
				])
				captured[name] = true
	manager.free()
	get_tree().quit()


func _force_serve_style(manager: Object, style: String) -> void:
	## Explicit diagnostic setup, restored by process exit. The query remains a
	## predicate over what the roster produced and never performs this override.
	for player in manager.players:
		player.primary_serve_style = style
	for player in manager.opponent_team.players:
		player.primary_serve_style = style


func _first_quick_set_index(events: Array) -> int:
	for index in range(events.size()):
		var event: Resource = events[index]
		if str(event.type_name()).to_lower() != "set": continue
		var timing: Dictionary = event.metadata.get("tempo_coordination", {})
		if int(timing.get("achieved_tempo", 3)) <= 1: return index
	return -1


func _previous_physical_event_index(events: Array, before_index: int) -> int:
	for index in range(before_index - 1, -1, -1):
		var event: Resource = events[index]
		if not event.metadata.get("outgoing_trajectory", {}).is_empty(): return index
	return -1


func _capture(screen: MatchScreen, output: String, file_name: String) -> void:
	screen.move_to_front()
	await get_tree().process_frame
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
	var path := "%s/%s.png" % [output.trim_suffix("/"), file_name]
	get_tree().root.get_texture().get_image().save_png(path)
	print("saved %s" % ProjectSettings.globalize_path(path))


func _visible_event_type(screen: MatchScreen) -> String:
	for node in screen.find_children("*", "Label", true, false):
		if not node.is_visible_in_tree(): continue
		var normalized := str(node.text).to_upper()
		for punctuation in ["/", "·", ":", "—", "-", "\n", "(", ")"]:
			normalized = normalized.replace(punctuation, " ")
		var tokens := normalized.split(" ", false)
		for event_type in ["SERVE", "RECEPTION", "SET", "ATTACK", "BLOCK", "DIG"]:
			if event_type in tokens: return event_type
	return ""


func _speed_label(speed: float) -> String:
	return ("%.2fx" % speed).replace(".", "_")


func _parse(raw: PackedStringArray) -> Dictionary:
	var parsed := {}
	for argument in raw:
		if not argument.begins_with("--"): continue
		var split := argument.substr(2).split("=", true, 1)
		parsed[split[0]] = split[1] if split.size() > 1 else true
	return parsed
