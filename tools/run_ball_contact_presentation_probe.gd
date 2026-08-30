extends SceneTree

## Deterministic certification for the serve-display and visible-platform seam.
##
##     godot --headless --path . \
##       --script res://tools/run_ball_contact_presentation_probe.gd

const GameManagerScript := preload("res://scripts/managers/game_manager.gd")
const RallyEventScript := preload("res://scripts/models/rally_event.gd")
const BodyTypes := preload("res://scripts/data/body_type_models.gd")

var failures := 0


func _initialize() -> void:
	var court_scene := load("res://scenes/components/match_court_3d.tscn") as PackedScene
	var court := court_scene.instantiate() as MatchCourt3D
	get_root().add_child(court)
	await process_frame

	var flights := 0
	var worst_gravity_error := 0.0
	var worst_handoff_error := 0.0
	var worst_sampler_error := 0.0
	for serving_home in [false, true]:
		for seed_value in range(76000, 76120):
			var manager := GameManagerScript.new()
			manager.seed_vertical_slice_data()
			manager.match_state.serving_home = serving_home
			var result: Resource = manager.resolve_active_rally(seed_value)
			var contacts := _serve_contacts(result)
			if contacts.size() < 2:
				manager.free()
				continue
			var serve: Resource = contacts[0]
			var reception: Resource = contacts[1]
			if not reception.success:
				manager.free()
				continue
			var incoming: Dictionary = reception.metadata.get("incoming_trajectory", {})
			var outgoing: Dictionary = reception.metadata.get("outgoing_trajectory", {})
			if incoming.is_empty() or outgoing.is_empty():
				manager.free()
				continue
			var next_contact: Resource = contacts[2] if contacts.size() > 2 else null
			var shown_in := BallPresentation.display_trajectory(
				serve, reception, incoming, result.player_physical_profiles
			)
			var shown_out := BallPresentation.display_trajectory(
				reception, next_contact, outgoing, result.player_physical_profiles
			)
			worst_gravity_error = maxf(worst_gravity_error, absf(
				float(shown_in.get("display_gravity_mps2", 0.0))
					- float(incoming.get("launch_gravity_mps2", 0.0))
			))
			var arrival := BallPresentation.sample(shown_in, 1.0)
			var departure := BallPresentation.sample(shown_out, 0.0)
			var horizontal_m := _court_distance(
				Vector2(arrival.court), Vector2(departure.court)
			)
			var vertical_m := absf(
				float(arrival.height_meters) - float(departure.height_meters)
			)
			worst_handoff_error = maxf(
				worst_handoff_error, Vector2(horizontal_m, vertical_m).length()
			)
			for progress in [0.0, 0.13, 0.5, 0.87, 1.0]:
				var sample := BallPresentation.sample(shown_in, progress)
				var expected := court.tactical_to_world(
					float(Vector2(sample.court).x), float(Vector2(sample.court).y),
					float(sample.height_meters),
				)
				worst_sampler_error = maxf(
					worst_sampler_error,
					expected.distance_to(court.trajectory_world_position(
						shown_in, progress
					)),
				)
			flights += 1
			manager.free()

	var comparable := _curvature_comparison()
	var platform := await _platform_silhouette_errors()
	print("\nball/contact presentation -- %d successful receptions" % flights)
	print("  worst published/display gravity error  %.8f m/s^2" % worst_gravity_error)
	print("  float curvature                         %.5f m" % float(comparable.float_drop))
	print("  topspin curvature                       %.5f m" % float(comparable.topspin_drop))
	print("  worst serve -> pass handoff error       %.8f m" % worst_handoff_error)
	print("  worst BallPresentation/court error      %.8f m" % worst_sampler_error)
	print("  platform silhouettes                    %d" % int(platform.count))
	print("  platform forward reach                  %.3f .. %.3f m" % [
		float(platform.min_reach), float(platform.max_reach),
	])
	print("  worst corrected horizontal error        %.8f m" % float(platform.worst_error))
	print("  platform height vs contact model        %.3f .. %.3f m error" % [
		float(platform.min_height_error), float(platform.max_height_error),
	])

	_gate(flights >= 150, "the sample contains successful serve receptions")
	_gate(worst_gravity_error < 0.000001, "display uses the published launch gravity")
	_gate(
		float(comparable.topspin_drop) > float(comparable.float_drop) * 1.8,
		"comparable topspin has materially stronger downward curvature",
	)
	_gate(worst_handoff_error < 0.00001, "serve and pass meet without a seam")
	_gate(worst_sampler_error < 0.000001, "court and BallPresentation sample identically")
	_gate(int(platform.count) == BodyTypes.MODELLED.size(), "every silhouette is measured")
	_gate(
		float(platform.worst_error) < 0.00001
			and float(platform.max_height_error) < 0.001,
		"the ball meets each posed platform in three dimensions",
	)

	if failures == 0:
		print("\nPASS: ball/contact presentation gates")
		quit(0)
		return
	push_error("FAIL: %d ball/contact presentation gates" % failures)
	quit(1)


func _serve_contacts(result: Resource) -> Array[Resource]:
	var contacts: Array[Resource] = []
	if result == null:
		return contacts
	for raw_event in result.events:
		var event: Resource = raw_event
		if int(event.event_type) in [
			RallyEventScript.EventType.SET_DECISION,
			RallyEventScript.EventType.POINT,
		]:
			continue
		contacts.append(event)
	return contacts


func _curvature_comparison() -> Dictionary:
	var float_spin := BallSpin.from_serve("Jump Float", 0.85, 0.90, true)
	var top_spin := BallSpin.from_serve("Jump Topspin", 0.85, 0.90, true)
	var duration := 0.85
	## With identical endpoints and duration, the amount the midpoint rises above
	## the endpoint chord is g*T^2/8. This isolates curvature from launch height,
	## pace and contact location.
	return {
		"float_drop": BallSpin.gravity_for(float_spin) * duration * duration / 8.0,
		"topspin_drop": BallSpin.gravity_for(top_spin) * duration * duration / 8.0,
	}


func _platform_silhouette_errors() -> Dictionary:
	var scene := load("res://scenes/components/player_actor_3d.tscn") as PackedScene
	var heights := [1.72, 1.88, 2.06]
	var reaches: Array[float] = []
	var height_errors: Array[float] = []
	var worst_error := 0.0
	for body_name in BodyTypes.MODELLED:
		var actor := scene.instantiate() as PlayerActor3D
		get_root().add_child(actor)
		await process_frame
		var height := float(heights[BodyTypes.MODELLED.find(body_name) % 3])
		actor.configure(1, true, str(body_name), "Right", {
			"height_cm": height * 100.0,
			"wingspan_cm": height * 102.0,
			"stride_length_m": height * 0.43,
			"body_type": body_name,
		})
		actor.contact_posture = "planted"
		actor.contact_recovery = "platform"
		actor.contact_platform_aim = {}
		actor.set_pose(
			RallyEventScript.EventType.RECEPTION, 0.0, 0.0,
			Vector2(0.0, -1.0), true,
		)
		actor.fit_platform_contact_height(
			GeometricAttackPromotion.pass_contact_from_height(height)
		)
		await process_frame
		var before := actor.platform_contact_world_position()
		var offset := before - actor.global_position
		reaches.append(Vector2(offset.x, offset.z).length())
		var ball_contact := Vector3(1.25, before.y, -2.0)
		actor.global_position += Vector3(
			ball_contact.x - before.x, 0.0, ball_contact.z - before.z
		)
		var after := actor.platform_contact_world_position()
		worst_error = maxf(worst_error, Vector2(
			after.x - ball_contact.x, after.z - ball_contact.z
		).length())
		height_errors.append(absf(
			after.y - GeometricAttackPromotion.pass_contact_from_height(height)
		))
		print("    %-6s platform_y=%.3f model_y=%.3f reach=%.3f" % [
			str(body_name), after.y,
			GeometricAttackPromotion.pass_contact_from_height(height),
			Vector2(offset.x, offset.z).length(),
		])
		actor.queue_free()
		await process_frame
	return {
		"count": reaches.size(),
		"min_reach": reaches.min(), "max_reach": reaches.max(),
		"worst_error": worst_error,
		"min_height_error": height_errors.min(),
		"max_height_error": height_errors.max(),
	}


func _court_distance(a: Vector2, b: Vector2) -> float:
	return Vector2(
		(a.x - b.x) * CourtConstants.COURT_WIDTH_METERS,
		(a.y - b.y) * CourtConstants.COURT_LENGTH_METERS,
	).length()


func _gate(condition: bool, label: String) -> void:
	if condition:
		print("  ok    %s" % label)
		return
	failures += 1
	print("  FAIL  %s" % label)
