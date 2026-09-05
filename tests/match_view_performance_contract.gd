extends SceneTree

const CourtScene := preload("res://scenes/components/match_court_3d.tscn")
const MatchScreenScene := preload("res://scenes/screens/match_screen.tscn")
const MatchScreenScript := preload("res://scenes/screens/match_screen.gd")

var checks := 0
var failures := 0


func _initialize() -> void:
	call_deferred("_run")


func _check(ok: bool, message: String) -> void:
	checks += 1
	if ok:
		return
	failures += 1
	push_error("MATCH VIEW PERFORMANCE: %s" % message)


func _run() -> void:
	var court := CourtScene.instantiate() as MatchCourt3D
	get_root().add_child(court)
	await process_frame
	var home := {}
	var away := {}
	var names := {}
	for index in range(6):
		home[index + 1] = Vector2(0.18 + index * 0.12, 0.68 + (index % 2) * 0.12)
		away[index + 101] = Vector2(0.18 + index * 0.12, 0.32 - (index % 2) * 0.12)
		names[index + 1] = "HOME %d" % (index + 1)
		names[index + 101] = "AWAY %d" % (index + 1)
	var build_started := Time.get_ticks_usec()
	court.setup_players(home, away, names)
	var build_usec := Time.get_ticks_usec() - build_started
	var first_instances := {}
	for player_id in court.player_actors:
		first_instances[player_id] = court.player_actors[player_id].get_instance_id()
		var renderer: Node = court.player_actors[player_id].get_node(
			"SurfaceMarkRenderer3D"
		)
		_check(not renderer.is_processing(),
			"surface marks must not inspect an invariant actor every frame")
		for raw_node in court.player_actors[player_id].find_children(
			"*", "MeshInstance3D", true, false
		):
			var node := raw_node as MeshInstance3D
			_check(node.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF,
				"match actors use their blob shadow, not articulated shadow casters")

	## Contact-anchor measurement calls this exact setup a second time. Matching
	## rigs must be reset and reused rather than destroyed and rebuilt.
	var reuse_started := Time.get_ticks_usec()
	court.setup_players(home, away, names)
	var reuse_usec := Time.get_ticks_usec() - reuse_started
	_check(court.player_actors.size() == 12, "the canonical roster remains twelve actors")
	for player_id in first_instances:
		_check(court.player_actors[player_id].get_instance_id() == first_instances[player_id],
			"unchanged rally setup must reuse actor %s" % player_id)
	var venue_details := court.configure_venue("Landavol")
	var venue_extras := court.get_node_or_null("VenueExtras")
	var venue_instance := venue_extras.get_instance_id() if venue_extras != null else 0
	var repeated_details := court.configure_venue("Landavol")
	_check(not venue_details.is_empty() and repeated_details == venue_details,
		"repeated broadcast context preserves canonical venue details")
	_check(court.get_node_or_null("VenueExtras").get_instance_id() == venue_instance,
		"unchanged broadcast context must reuse venue geometry")

	var screen := MatchScreenScene.instantiate()
	var viewport := screen.get_node("SubViewportContainer/SubViewport") as SubViewport
	_check(viewport.size == Vector2i(960, 540),
		"match rendering uses the reduced internal pixel budget")
	_check(not MatchScreenScript.COGNITICONS_ENABLED,
		"player-facing cogniticons remain disabled during performance work")
	screen.free()
	court.free()
	print("Match roster setup: first %.1f ms; unchanged reuse %.1f ms" % [
		float(build_usec) / 1000.0, float(reuse_usec) / 1000.0,
	])
	print("Match view performance contract: %d checks, %d failures" % [checks, failures])
	quit(1 if failures > 0 else 0)
