extends SceneTree

## Which cogniticon is actually on screen, and for how long?
##
##     godot --headless --path . --script res://tools/run_cogniticon_screen_probe.gd
##
## `run_intent_progress_probe.gd` established what the resolver *publishes*.
## This is the other half and it is the half the report was about: what a viewer
## sees. It drives the real `MatchScreen` through real rallies and reads
## `text` and `visible` off each voli's own billboard node every frame -- the
## same distinction `measure_offball_travel.gd` insists on, where the dictionary
## is what playback intends and the node is what is drawn.
##
## The question in a form the data can answer: of the frames where a billboard
## is visible, which tier is it in, and which glyph? The ambient tier is the
## shield-and-blade vocabulary; the badge tier is the older shape/face/trend
## string. If the badge tier dominates, the vocabulary is built and not being
## reached, which looks from a chair exactly like it was never built.
func _initialize() -> void:
	Engine.max_fps = 60
	var Billboard := load("res://scenes/components/cognition_billboard_3d.gd")
	var manager: Object = load("res://scripts/managers/game_manager.gd").new()
	manager.seed_vertical_slice_data()
	manager.match_state.serving_home = false

	var screen: Control = load("res://scenes/screens/match_screen.tscn").instantiate()
	get_root().add_child(screen)
	await process_frame
	var court = screen.match_court_3d

	## Which glyphs belong to which tier, so a drawn mark can be attributed
	## without guessing from its shape.
	var ambient := {}
	for key in Billboard.INTENT_GLYPHS:
		ambient[str(Billboard.INTENT_GLYPHS[key])] = str(key)

	var seen := {}
	var visible_frames := 0
	var body_frames := 0
	var rallies := 0
	for rally_seed in [12007, 12011, 12019, 12023, 12029, 12031, 12037, 12041]:
		var result: Resource = manager.resolve_active_rally(rally_seed)
		if result == null:
			continue
		rallies += 1
		screen.load_and_play_rally(result, 1.0)
		await process_frame
		var guard := 0
		while screen.playback_active and guard < 200000:
			guard += 1
			await process_frame
			for raw_id in court.player_actors:
				var actor = court.player_actors[raw_id]
				body_frames += 1
				var badge = actor.cognition_billboard
				if badge == null or not badge.visible:
					continue
				visible_frames += 1
				var drawn := str(badge.text)
				var label := "ambient: %s" % str(ambient[drawn]) \
					if ambient.has(drawn) else "badge: %s" % drawn
				seen[label] = int(seen.get(label, 0)) + 1

	print("%d rallies, %d voli-frames\n" % [rallies, body_frames])
	print("%d of them (%.1f%%) had a cogniticon on screen\n" % [
		visible_frames, 100.0 * float(visible_frames) / maxf(float(body_frames), 1.0),
	])
	print("%-28s %10s %9s" % ["what was drawn", "frames", "share"])
	var keys := seen.keys()
	keys.sort_custom(func(a: String, b: String) -> bool:
		return int(seen[a]) > int(seen[b]))
	var ambient_total := 0
	for key in keys:
		if str(key).begins_with("ambient"):
			ambient_total += int(seen[key])
		print("%-28s %10d %8.1f%%" % [
			key, int(seen[key]),
			100.0 * float(seen[key]) / maxf(float(visible_frames), 1.0),
		])
	print("\nthe shield-and-blade vocabulary is %.1f%% of what is drawn" % [
		100.0 * float(ambient_total) / maxf(float(visible_frames), 1.0),
	])
	manager.free()
	quit()
