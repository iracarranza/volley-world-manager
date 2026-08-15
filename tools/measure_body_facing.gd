extends SceneTree

## Does a voli's body actually point at the ball during a flight?
##
##     godot --headless --path . --script res://tools/measure_body_facing.gd
##
## **Run this by hand after touching anything that turns a body.** The suite
## gates the *rule* -- `PlayerActor3D.should_open_up` -- but it cannot gate the
## *call order*, because asserting that the ball pass runs before the movement
## plan needs real frames and `tests/test_runner.gd` has no awaits. That gap is
## exactly where two wrong facing fixes both passed 1049 checks and were caught
## by a screenshot instead.
##
## Reference reading, taken when the ball-facing default landed:
##
##     SERVE->RECEPTION      40.9 deg mean   145.2 worst   1 of 12 back-turned
##     RECEPTION->SET         7.0 deg mean    75.2 worst   0 of 12
##     SET->ATTACK            0.0 deg mean     0.0 worst   0 of 12
##
## The opening flight lags because a body turns at a finite rate and the serve
## crosses the court quickly, and the single back-turned voli is the server, who
## genuinely does have the ball behind them for a moment after striking it. A
## *later* flight reading much above ten degrees, or any back-turned voli who is
## not the actor, is the regression this file exists to catch.
##
## Reasoned about twice and got it wrong twice, so this drives the real court
## through a real rally and reads `facing_yaw` off the actors, exactly as the
## renderer would leave it. Reported as the angle between where the body points
## and where the ball is: 0 degrees is square to it, 180 is back turned.
func _initialize() -> void:
	var GameManagerScript := load("res://scripts/managers/game_manager.gd")
	var CourtScene := load("res://scenes/components/match_court_3d.tscn")
	var m: Object = GameManagerScript.new()
	m.seed_vertical_slice_data()
	m.match_state.serving_home = false
	var r: Resource = m.resolve_active_rally(12007)
	if r == null:
		print("no rally"); quit(); return
	var court = CourtScene.instantiate()
	get_root().add_child(court)
	## `@onready` bindings resolve during _ready, which runs on the next frame.
	await process_frame
	court.setup_players(r.initial_home_positions, r.initial_opponent_positions)

	var E := load("res://scripts/models/rally_event.gd")
	var contacts := [E.EventType.SERVE, E.EventType.RECEPTION, E.EventType.SET,
		E.EventType.ATTACK, E.EventType.BLOCK, E.EventType.DIG]
	var chain: Array = []
	for e in r.events:
		if int(e.event_type) in contacts: chain.append(e)

	print("%-22s %10s %10s %10s" % ["flight", "mean deg", "worst deg", "back-turned"])
	var samples := 40
	for i in range(chain.size() - 1):
		var a = chain[i]
		var b = chain[i + 1]
		var traj: Dictionary = a.metadata.get("outgoing_trajectory", {})
		if traj.is_empty(): continue
		var plan := {}
		for key in ["home_phase_targets", "opponent_phase_targets"]:
			var t: Dictionary = b.metadata.get(key, {})
			for raw in t:
				var pid := int(raw)
				if court.live_positions.has(pid):
					plan[pid] = {"start": Vector2(court.live_positions[pid]),
						"target": Vector2(t[raw])}
		var total := 0.0; var worst := 0.0; var backs := 0; var n := 0
		for step in range(samples):
			var p := float(step) / float(samples - 1)
			court.set_ball_trajectory_sample(traj, p)
			court.apply_movement_plan(plan, p, 0.6)
			await process_frame
		var ball: Vector3 = court.ball_actor.global_position
		for raw_id in court.player_actors:
			var actor = court.player_actors[raw_id]
			var off: Vector3 = ball - actor.global_position
			var want := atan2(-off.x, -off.z)
			var err := absf(rad_to_deg(angle_difference(actor.facing_yaw, want)))
			total += err; worst = maxf(worst, err); n += 1
			if err > 100.0: backs += 1
		print("%-22s %10.1f %10.1f %10d of %d" % [
			"%s->%s" % [E.EventType.keys()[int(a.event_type)],
				E.EventType.keys()[int(b.event_type)]],
			total / float(n), worst, backs, n])
	m.free()
	quit()
