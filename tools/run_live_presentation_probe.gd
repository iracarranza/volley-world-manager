extends Node

## Focused regression gate for the venue/camera handoff used by MatchScreen.
##
## Run:
##   godot --headless --path . res://tools/live_presentation_probe.tscn

const SCREEN := preload("res://scenes/screens/match_screen.tscn")
const EXPECTED_VENUES := {
	"Landavol": "landavol",
	"Spëddigh": "speddigh",
	"Pāwa Hitō": "pawa",
	"Blôc du Larg": "bloc",
	"Xérvu": "xervu",
	"Taktikã": "taktika",
	"A'ace": "aace",
	"Ĭspayk": "ispayk",
}

var checks := 0
var failures := 0


func _ready() -> void:
	var screen := SCREEN.instantiate() as MatchScreen
	add_child(screen)
	await get_tree().process_frame

	for region in EXPECTED_VENUES:
		var details := screen.match_court_3d.configure_venue(str(region))
		_check(
			str(details.get("id", "")) == str(EXPECTED_VENUES[region]),
			"%s resolves to its reviewed venue" % region,
		)
		_check(
			screen.match_court_3d.get_node_or_null("VenueExtras") != null,
			"%s adds venue geometry to the live court" % region,
		)

	screen.configure_broadcast({
		"home_name": "HOME", "away_name": "A'ACE",
		"away_region": "A'ace", "venue_region": "A'ace",
	})
	_check(screen.match_court_3d.venue_id == "aace", "broadcast context selects A'ace")
	var court_surface := screen.match_court_3d.get_node("CourtSurface") as MeshInstance3D
	var floor_material := court_surface.material_override as StandardMaterial3D
	_check(
		floor_material != null
			and floor_material.albedo_color.is_equal_approx(Color(0.88, 0.75, 0.54)),
		"A'ace replaces the legacy orange playing surface",
	)

	var camera := screen.dynamic_camera
	camera.reset_free_view()
	## Reproduce the failure from the live viewer: orbit broadside, pull down to
	## a low angle and zoom all the way out. This used to put the lens behind the
	## opaque long wall and leave the presentation completely black.
	camera.orbit(Vector2(-102.0, 400.0))
	camera.zoom_steps(-100.0)
	var limits := screen.match_court_3d.free_camera_limits()
	var bounded_position := screen.match_court_3d.camera_3d.global_position
	_check(
		absf(bounded_position.x) <= float(limits.get("half_width", 0.0)) + 0.001
			and absf(bounded_position.z) <= float(limits.get("half_length", 0.0)) + 0.001
			and bounded_position.y <= float(limits.get("ceiling", 0.0)) + 0.001,
		"freecam cannot orbit or zoom behind A'ace's arena shell",
	)
	var saved := camera.capture_state()
	var saved_transform := screen.match_court_3d.camera_3d.global_transform

	var manager: Object = load("res://scripts/managers/game_manager.gd").new()
	manager.seed_vertical_slice_data()
	var result: RallyResult = manager.resolve_active_rally(76005)
	_check(result != null, "camera regression fixture resolves")
	if result != null:
		screen.load_and_play_rally(result, 4.0, true)
		await get_tree().process_frame
		var replay_state := camera.capture_state()
		_check(_same_free_view(saved, replay_state), "replay preserves freecam orbit and zoom")
		_check(
			screen.match_court_3d.camera_3d.global_transform.is_equal_approx(saved_transform),
			"replay preserves the exact freecam transform",
		)
		screen.skip_requested = true
		while screen.playback_active:
			await get_tree().process_frame

	screen._close()
	var closed_state := camera.capture_state()
	screen.visible = true
	await get_tree().process_frame
	_check(_same_free_view(saved, closed_state), "leaving and re-entering 3D preserves freecam")

	manager.free()
	screen.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame
	print("LIVE PRESENTATION PROBE: %d checks, %d failures" % [checks, failures])
	get_tree().quit(1 if failures > 0 else 0)


func _same_free_view(expected: Dictionary, actual: Dictionary) -> bool:
	return bool(actual.get("free_enabled", false)) \
		and Vector3(actual.get("orbit_target", Vector3.ZERO)).is_equal_approx(
			Vector3(expected.get("orbit_target", Vector3.ZERO))
		) \
		and is_equal_approx(
			float(actual.get("orbit_yaw", 0.0)), float(expected.get("orbit_yaw", 0.0))
		) \
		and is_equal_approx(
			float(actual.get("orbit_elevation", 0.0)),
			float(expected.get("orbit_elevation", 0.0))
		) \
		and is_equal_approx(
			float(actual.get("orbit_distance", 0.0)),
			float(expected.get("orbit_distance", 0.0))
		)


func _check(condition: bool, label: String) -> void:
	checks += 1
	if condition:
		print("PASS: %s" % label)
	else:
		failures += 1
		push_error("FAIL: %s" % label)
