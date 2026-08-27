extends Node

## Render/geometry regression for the opponent-attack/home-double-block path.
## Seed 5012 deterministically produces a home wall with a primary and assist.
##
## Run with a real renderer:
##   godot --path . res://tools/double_block_regression.tscn

const SCREEN := preload("res://scenes/screens/match_screen.tscn")
const Events := preload("res://scripts/models/rally_event.gd")
const OUTPUT := "res://artifacts/blocker-overlap-regression"
const SEED := 5012


func _ready() -> void:
	get_window().size = Vector2i(1280, 720)
	var screen := SCREEN.instantiate() as MatchScreen
	add_child(screen)
	await get_tree().process_frame
	var manager: Object = load("res://scripts/managers/game_manager.gd").new()
	manager.seed_vertical_slice_data()
	manager.match_state.serving_home = true
	var result: RallyResult = manager.resolve_active_rally(SEED)
	var block_index := _home_double_block_index(result.events if result != null else [])
	if result == null or block_index < 0:
		push_error("seed %d no longer produces a home double block" % SEED)
		get_tree().quit(1)
		return
	var block := result.events[block_index] as RallyEvent
	var attack_index := _previous_attack_index(result.events, block_index)
	var primary_id := int(block.actor_id)
	var assist_id := int(block.metadata.get("assist_id", -1))
	if attack_index < 0 or primary_id < 0 or assist_id < 0:
		push_error("double-block fixture is missing its attack or blocker ids")
		get_tree().quit(1)
		return
	print("double-block seed %d: attack event %d, block event %d, %d total" % [
		SEED, attack_index, block_index, result.events.size(),
	])

	screen.configure_broadcast({
		"home_name": "MARAUDERS VC", "away_name": "PORT AZURE VC",
		"venue_region": "Landavol", "away_region": "Landavol",
	})
	var court_viewport := screen.get_node("SubViewportContainer/SubViewport") as SubViewport
	court_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	screen.load_and_play_rally(result, 0.35, true)
	## End-line inspection view: separation along court X is visible across the
	## frame, while the lens remains close enough to read torso and hand shapes.
	screen.dynamic_camera.restore_state({
		"free_enabled": true,
		"follow_player_id": -1,
		"orbit_target": Vector3(0.8, 2.15, 0.25),
		"orbit_yaw": 0.0,
		"orbit_elevation": deg_to_rad(14.0),
		"orbit_distance": 8.5,
	})

	var captured := {}
	var failed := false
	while screen.playback_active:
		await get_tree().process_frame
		var global_progress := float(screen.progress_bar.value) / 100.0 \
			* float(result.events.size())
		if not captured.has("late_close") \
				and global_progress >= float(attack_index) + 0.72 \
				and global_progress < float(block_index):
			failed = not await _capture_and_check(
				screen, primary_id, assist_id, "seed_5012_late_close",
				global_progress,
			) or failed
			captured["late_close"] = true
		if not captured.has("contact") \
				and global_progress >= float(block_index) + 0.10:
			failed = not await _capture_and_check(
				screen, primary_id, assist_id, "seed_5012_block_contact",
				global_progress,
			) or failed
			captured["contact"] = true

	if captured.size() != 2:
		push_error("double-block probe missed one or more capture milestones: %s" % captured)
		failed = true
	manager.free()
	screen.queue_free()
	await get_tree().process_frame
	get_tree().quit(1 if failed else 0)


func _capture_and_check(
	screen: MatchScreen, primary_id: int, assist_id: int, label: String,
	global_progress: float,
) -> bool:
	var primary := screen.match_court_3d.actor_for(primary_id)
	var assist := screen.match_court_3d.actor_for(assist_id)
	if primary == null or assist == null:
		push_error("%s cannot resolve both blocker actors" % label)
		return false
	var centre_gap := absf(primary.global_position.x - assist.global_position.x)
	var torso_gap := absf(primary.torso.global_position.x - assist.torso.global_position.x)
	var primary_half := _torso_half_width(primary)
	var assist_half := _torso_half_width(assist)
	var torso_clearance := torso_gap - primary_half - assist_half
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT))
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var path := "%s/%s.png" % [OUTPUT, label]
	var image := get_tree().root.get_texture().get_image()
	if image == null or image.is_empty():
		push_error("%s could not read the rendered viewport" % label)
		return false
	image.save_png(path)
	print("%s at %.3f (%s): centre %.3f m; torso clearance %.3f m; saved %s" % [
		label, global_progress, screen.event_label.text, centre_gap, torso_clearance,
		ProjectSettings.globalize_path(path),
	])
	if centre_gap < 0.84 or torso_clearance < -0.01:
		push_error("%s merges the two blocker bodies" % label)
		return false
	return true


func _torso_half_width(actor: PlayerActor3D) -> float:
	if actor.torso == null or actor.torso.mesh == null:
		return 0.36
	var local_width := actor.torso.mesh.get_aabb().size.x
	return local_width * actor.torso.global_basis.get_scale().x * 0.5


func _home_double_block_index(events: Array[Resource]) -> int:
	for index in range(events.size()):
		var event := events[index] as RallyEvent
		if event != null and event.event_type == Events.EventType.BLOCK \
				and str(event.metadata.get("side", "")) == "home" \
				and int(event.metadata.get("assist_id", -1)) >= 0:
			return index
	return -1


func _previous_attack_index(events: Array[Resource], before: int) -> int:
	for index in range(before - 1, -1, -1):
		var event := events[index] as RallyEvent
		if event != null and event.event_type == Events.EventType.ATTACK \
				and str(event.metadata.get("side", "")) == "opponent":
			return index
	return -1
