extends Node

## Review renderer for the presentation-only broadcast shell. The court is the
## real MatchScreen playing the resolver's seed-76005 RallyResult; the tool never
## invents a contact, trajectory, actor, or outcome.

const SCREEN := preload("res://scenes/screens/match_screen.tscn")

var screen: MatchScreen
var overlay: BroadcastOverlay
var captured := {}


func _ready() -> void:
	get_window().size = Vector2i(1280, 720)
	screen = SCREEN.instantiate() as MatchScreen
	add_child(screen)
	await get_tree().process_frame
	overlay = screen.broadcast_overlay
	screen.configure_broadcast({
		"home_name": "PĀWA HITŌ", "away_name": "XÉRVU",
		"home_score": 18, "away_score": 16,
		"home_sets": 1, "away_sets": 0, "serving_home": true,
	})
	overlay.set_commentary("A medium float asks for the passer's first step; the receiving line holds its depth.", 0)

	var manager: Object = load("res://scripts/managers/game_manager.gd").new()
	manager.seed_vertical_slice_data()
	manager.match_state.serving_home = true
	var result: RallyResult = manager.resolve_active_rally(76005)
	if result == null:
		push_error("seed 76005 did not resolve")
		get_tree().quit(1)
		return
	screen.load_and_play_rally(result, 1.0)
	overlay.set_live_rally(true, "SERVE")
	while screen.playback_active:
		await get_tree().process_frame
		var phase := screen.event_label.text.to_upper()
		if phase.contains("SERVE") and not captured.has("serve"):
			overlay.set_live_rally(true, "SERVE")
			await _capture("serve_live")
			captured["serve"] = true
		if phase.contains("ATTACK") and not captured.has("attack"):
			overlay.set_live_rally(true, "ATTACK → BLOCK / DIG")
			overlay.set_commentary("The outside arrives on time. Two blockers close while the cross-court defender stays behind the hands.", 1, true)
			await _capture("attack_block_dig_top_right")
			overlay.set_commentary_placement("bottom_right")
			await _capture("attack_block_dig_bottom_right")
			overlay.set_commentary_placement("top_right")
			captured["attack"] = true

	overlay.set_live_rally(false, "POINT COMPLETE")
	overlay.show_lower_third("POINT REVIEW", "Pāwa Hitō turn a block touch into a transition swing")
	overlay.set_commentary("The point is over; analysis can become louder while the court recedes behind the score and context.", 0)
	await _capture("dead_ball_lower_third")
	overlay.set_compact(true)
	await _capture("compact_score_bug")
	overlay.set_compact(false)
	overlay.set_replay_state(true)
	await _capture("announcers_replay_treatment")
	manager.free()
	get_tree().quit()


func _capture(file_name: String) -> void:
	overlay.move_to_front()
	await get_tree().process_frame
	await get_tree().process_frame
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://artifacts/broadcast-first-draft"))
	var path := "res://artifacts/broadcast-first-draft/%s.png" % file_name
	get_tree().root.get_texture().get_image().save_png(path)
	print("saved %s" % ProjectSettings.globalize_path(path))
