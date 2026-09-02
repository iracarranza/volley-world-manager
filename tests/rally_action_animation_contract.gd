extends SceneTree

const Serve := preload("res://scripts/data/serve_action_biomechanics.gd")
const Defense := preload("res://scripts/data/defense_action_biomechanics.gd")
const SetMotion := preload("res://scripts/data/set_biomechanics.gd")
const Attack := preload("res://scripts/data/attack_action_biomechanics.gd")
const Idle := preload("res://scripts/data/idle_biomechanics.gd")
const PlayerActor := preload("res://scenes/components/player_actor_3d.gd")
const PlayerActorScene := preload("res://scenes/components/player_actor_3d.tscn")
const RallyEventModel := preload("res://scripts/models/rally_event.gd")
const Spike := preload("res://scripts/data/spike_biomechanics.gd")
const CorePerformance := preload("res://scripts/data/core_voli_performance.gd")
const Arrival := preload("res://scripts/data/contact_arrival_biomechanics.gd")
const Block := preload("res://scripts/data/block_biomechanics.gd")

var checks := 0
var failures := 0


func _initialize() -> void:
	call_deferred("_run")


func _check(ok: bool, message: String) -> void:
	checks += 1
	if ok:
		return
	failures += 1
	push_error("RALLY ACTION ANIMATION: %s" % message)


func _finite_joints(joints: Dictionary, label: String) -> void:
	for key in [
		"striking_shoulder_degrees", "striking_elbow_degrees",
		"torso_pitch_radians", "lead_hip_degrees", "trail_hip_degrees",
		"knee_degrees", "rise_metres",
	]:
		_check(is_finite(float(joints.get(key, NAN))), "%s has invalid %s" % [label, key])


func _run() -> void:
	var contact_shapes := {}
	for style in Serve.STYLES:
		var contact := Serve.resolve(0.0, 1.0, 0.78, style, 1)
		_finite_joints(contact, style)
		contact_shapes[style] = "%s|%.1f|%.1f|%.3f" % [
			contact.support,
			float(contact.striking_shoulder_degrees),
			float(contact.striking_elbow_degrees),
			float(contact.rise_metres),
		]
	var unique_contact_shapes: Array = []
	for shape in contact_shapes.values():
		if shape not in unique_contact_shapes:
			unique_contact_shapes.append(shape)
	_check(unique_contact_shapes.size() == Serve.STYLES.size(),
		"every serve style needs a distinct contact silhouette")
	_check(float(Serve.resolve(0.0, 1.0, 0.7, Serve.JUMP_TOPSPIN).rise_metres) > 0.45,
		"jump topspin must be airborne at contact")
	_check(float(Serve.resolve(0.0, 1.0, 0.7, Serve.JUMP_FLOAT).rise_metres) > 0.24,
		"jump float must be airborne at contact")
	_check(is_zero_approx(float(Serve.resolve(0.0, 1.0, 0.7, Serve.STANDING).rise_metres)),
		"standing serve must remain grounded")
	var sky := Serve.resolve(0.0, 1.0, 0.7, Serve.SKY_BALL)
	_check(bool(sky.underhand) and is_zero_approx(float(sky.rise_metres)),
		"sky ball must use a grounded underhand chain")
	_check(Serve.routine_variant(42) == Serve.routine_variant(42),
		"serve routine must be stable per actor")

	var no_dive := Defense.resolve(0.0, false)
	var dive_commit := Defense.resolve(-0.16, true)
	var dive_floor := Defense.resolve(0.24, true)
	_check(is_zero_approx(float(no_dive.forward_metres)), "ordinary reception gained dive travel")
	_check(float(dive_commit.forward_metres) > 0.0 and float(dive_commit.drop_metres) > 0.0,
		"diving receive must travel toward and down to the ball before contact")
	_check(float(dive_floor.drop_metres) > float(dive_commit.drop_metres),
		"diving receive must arrive on the floor after contact")
	_check(Defense.is_diving("reaching", "fall") and not Defense.is_diving("planted", "platform"),
		"published posture/recovery must select diving without inventing a new verdict")
	var slide_impact := PlayerActor.recovery_motion(
		"fall", "reaching", 0.82, Vector2.UP
	)
	var slide_finish := PlayerActor.recovery_motion(
		"fall", "reaching", 1.0, Vector2.UP
	)
	_check(-Vector3(slide_impact.offset).z > 0.30,
		"dive recovery must preserve its established forward slide through impact")
	_check(absf(Vector3(slide_finish.offset).z) < 0.01 \
		and absf(float(slide_finish.pitch_radians)) < 0.01,
		"dive recovery must hand back a neutral local transform at phase end")

	for posture in [SetMotion.POSTURE_STANDING, SetMotion.POSTURE_JUMP, SetMotion.POSTURE_UNDERHAND]:
		var front := SetMotion.resolve(0.0, 1.0, posture, false)
		var back := SetMotion.resolve(0.0, 1.0, posture, true)
		_check(back.posture == front.posture, "back set changed support posture")
		_check(float(back.torso_pitch_radians) > float(front.torso_pitch_radians),
			"back set must arch farther than its front-set counterpart")
		_check(float(back.shoulder_degrees) > float(front.shoulder_degrees),
			"back set must carry the hands behind the crown")

	var settled_arrival := Arrival.resolve(-0.18, 0.0, 0.25)
	var moving_arrival := Arrival.resolve(-0.18, 3.2, 0.25, "moving")
	_check(float(Arrival.resolve(-0.06, 3.2, 0.25, "moving").upper_body_weight) > 0.99,
		"late arrival must still complete the contact apparatus before contact")
	_check(float(moving_arrival.lower_body_weight) < float(settled_arrival.lower_body_weight),
		"moving arrival must retain its active step longer than a settled arrival")
	_check(bool(moving_arrival.active_left),
		"arrival handoff must preserve the active foot from stride phase")
	_check(Arrival.resolve(-0.18, 3.2, 0.75, "moving").active_left == false,
		"opposite stride phase must preserve the opposite active foot")

	var power_sell := Attack.resolve(-0.36, 1.0, 0.8, "Power swing")
	var roll_sell := Attack.resolve(-0.36, 1.0, 0.8, "Roll shot")
	var dink_sell := Attack.resolve(-0.36, 1.0, 0.8, "Dink")
	for key in [
		"striking_shoulder_degrees", "striking_elbow_degrees",
		"guide_shoulder_degrees", "torso_pitch_radians", "knee_degrees",
	]:
		_check(is_equal_approx(float(power_sell[key]), float(roll_sell[key])) \
			and is_equal_approx(float(power_sell[key]), float(dink_sell[key])),
			"soft shots changed the sold approach at %s" % key)
	var power_contact := Attack.resolve(0.0, 1.0, 0.8, "Power swing")
	var roll_contact := Attack.resolve(0.0, 1.0, 0.8, "Controlled roll")
	var dink_contact := Attack.resolve(0.0, 1.0, 0.8, "Short tip")
	_check(roll_contact.attack_family == Attack.ROLL and dink_contact.attack_family == Attack.DINK,
		"resolved attack vocabulary did not select roll/dink families")
	_check(float(roll_contact.striking_elbow_degrees) > float(power_contact.striking_elbow_degrees),
		"roll shot must soften the elbow at contact")
	_check(float(dink_contact.striking_elbow_degrees) > float(roll_contact.striking_elbow_degrees),
		"dink must retain the most compact striking elbow")
	for adjustment in [
		Attack.ADJUSTMENT_REACHING, Attack.ADJUSTMENT_MISTIMED,
		Attack.ADJUSTMENT_MISSED,
	]:
		var clean_sell := Attack.resolve(-0.36, 1.0, 0.8, "Power swing")
		var adjusted_sell := Attack.resolve(
			-0.36, 1.0, 0.8, "Power swing", adjustment
		)
		_check(is_equal_approx(
			float(clean_sell.striking_shoulder_degrees),
			float(adjusted_sell.striking_shoulder_degrees),
		), "%s adjustment changed the canonical sold approach" % adjustment)
	var reaching_attack := Attack.resolve(
		0.12, 1.0, 0.8, "Power swing", Attack.ADJUSTMENT_REACHING
	)
	var cramped_attack := Attack.resolve(
		0.12, 1.0, 0.8, "Power swing", Attack.ADJUSTMENT_MISTIMED
	)
	_check(absf(float(reaching_attack.adjustment_roll_degrees)) > 1.0,
		"reaching attack must counterbalance the extended striking side")
	_check(float(cramped_attack.striking_elbow_degrees) \
		> float(reaching_attack.striking_elbow_degrees),
		"mistimed attack must retain a more compromised elbow")

	for response in [Block.RESPONSE_IMPACT, Block.RESPONSE_TOOL, Block.RESPONSE_BEATEN]:
		var plain_before := Block.resolve(-0.08)
		var response_before := Block.resolve(-0.08, response, 1.0)
		_check(is_equal_approx(
			float(plain_before.shoulder_degrees),
			float(response_before.shoulder_degrees),
		), "%s block response anticipated the outcome before contact" % response)
	var impact_wall := Block.resolve(0.12, Block.RESPONSE_IMPACT, 1.0)
	var tool_wall := Block.resolve(0.12, Block.RESPONSE_TOOL, 1.0)
	_check(float(impact_wall.elbow_degrees) > float(Block.resolve(0.12).elbow_degrees),
		"hard block impact must yield through the elbows")
	_check(float(tool_wall.right_elbow_delta_degrees) \
		> float(tool_wall.left_elbow_delta_degrees),
		"tool response must yield on the contacted hand only")
	_check(Spike.elevation_at(Spike.PLANT_END - 0.001) == 0.0 \
		and Spike.elevation_at(Spike.PLANT_END) == 0.0 \
		and Spike.elevation_at(Spike.PLANT_END + 0.08) > 0.0,
		"attack launch must begin after, not during, the canonical approach")
	var epsilon := 0.001
	var before := Spike.resolve(-epsilon, 1.0, 0.82)
	var at_contact := Spike.resolve(0.0, 1.0, 0.82)
	var after := Spike.resolve(epsilon, 1.0, 0.82)
	for key in ["striking_shoulder_degrees", "striking_elbow_degrees"]:
		var incoming_velocity := (float(at_contact[key]) - float(before[key])) / epsilon
		var outgoing_velocity := (float(after[key]) - float(at_contact[key])) / epsilon
		_check(absf(incoming_velocity - outgoing_velocity) < 12.0,
			"%s velocity must continue through overhead contact" % key)

	await _test_rig_geometry()

	var idle := Idle.resolve(1.75, 12, "watching")
	_check(absf(float(idle.rise_metres)) <= 0.0061, "idle breathing exceeds its vertical bound")
	_check(absf(float(idle.lateral_metres)) <= 0.0121, "idle sway exceeds its lateral bound")
	_check(Idle.blink_weight(1.0, 9, true) == 0.0, "blink must be suppressed at contact")
	var blink_seen := false
	for sample in range(0, 800):
		if Idle.blink_weight(float(sample) * 0.01, 9, false) > 0.95:
			blink_seen = true
			break
	_check(blink_seen, "deterministic blink schedule never closes the eyes")
	_check(Idle.blink_weight(0.37, 9, false) == Idle.blink_weight(0.37, 9, false),
		"blink schedule must repeat exactly for inspection")

	_test_core_performance_contract()

	if failures == 0:
		print("Rally action animation contract: %d checks, 0 failures" % checks)
		quit(0)
		return
	push_error("Rally action animation contract: %d checks, %d failures" % [checks, failures])
	quit(1)


func _test_core_performance_contract() -> void:
	var load := CorePerformance.resolve(
		RallyEventModel.EventType.ATTACK, -0.55, "Cani", "Right",
		Vector2.UP, {"attack_type": "Power swing"},
	)
	var contact := CorePerformance.resolve(
		RallyEventModel.EventType.ATTACK, 0.0, "Cani", "Right",
		Vector2.UP, {"attack_type": "Power swing"},
	)
	var finish := CorePerformance.resolve(
		RallyEventModel.EventType.ATTACK, 0.38, "Cani", "Right",
		Vector2.UP, {"attack_type": "Power swing"},
	)
	_check(float(load.anticipation) > 0.55,
		"core performance must publish a readable pre-contact load")
	_check(float(contact.force) > float(load.force) \
		and float(contact.force) > float(finish.force),
		"force accent must peak at the authoritative contact phase")
	_check(float(finish.continuation) > float(load.continuation),
		"follow-through must continue beyond contact rather than freeze there")

	var target := Vector2(0.72, -0.24)
	var first_head := CorePerformance.attention_step(
		Vector2.ZERO, target, 1.0 / 60.0
	)
	var pupil_lead := CorePerformance.pupil_attention_offset(first_head, target)
	_check(first_head.length() > 0.0 and first_head.length() < target.length(),
		"head attention must pursue the target without snapping to it")
	_check(pupil_lead.length() > 0.0,
		"eyes must visibly lead a head that is still catching the target")

	var tail := CorePerformance.passive_response(
		"Cani", "Tail", finish, "Right"
	)
	var compact_ear := CorePerformance.passive_response(
		"Ursi", "EarLeft", finish, "Right"
	)
	_check(tail.length() > 0.1 and tail.length() < 12.0,
		"a hanging tail needs restrained passive follow-through")
	_check(compact_ear.is_zero_approx(),
		"compact attached anatomy must not gain arbitrary floppy motion")
	_check(is_equal_approx(CorePerformance.handoff_weight(0.0), 1.0) \
		and is_equal_approx(CorePerformance.handoff_weight(1.0), 0.0),
		"ordinary action handoff must meet both endpoint poses exactly")


func _test_rig_geometry() -> void:
	var actor: Node3D = PlayerActorScene.instantiate()
	get_root().add_child(actor)
	await process_frame
	actor.configure(901, true, "Contract", "Right", {
		"height_cm": 191.0,
		"body_type": "Cani",
	})
	await process_frame
	actor.look_toward(0.72, -12.0)
	actor.set_pose(-1, 0.0, 0.0, Vector2.RIGHT, false)
	_check(actor.look_yaw > 0.0 and actor.look_yaw < 0.72,
		"real rig head must follow rally attention without snapping")
	actor.contact_posture = "reaching"
	actor.contact_recovery = "fall"
	actor.set_pose(
		RallyEventModel.EventType.RECEPTION, 0.0, -1.0,
		Vector2.RIGHT, true,
	)
	await process_frame
	var court_floor: float = actor._lowest_body_point()
	var lowest := INF
	var lowest_phase := 0.0
	for sample in range(41):
		var phase := lerpf(-1.0, 1.0, float(sample) / 40.0)
		actor.set_pose(
			RallyEventModel.EventType.RECEPTION, 0.0, phase,
			Vector2.RIGHT, true,
		)
		await process_frame
		var sample_lowest: float = actor._lowest_body_point()
		if sample_lowest < lowest:
			lowest = sample_lowest
			lowest_phase = phase
	_check(lowest >= court_floor - 0.002,
		"diving receive must remain above the court (lowest %.4f m at phase %.2f)"
			% [lowest, lowest_phase])

	actor.set_pose(
		RallyEventModel.EventType.ATTACK, 1.0, 0.0, Vector2.UP, true,
		{"attack_type": "Dink", "action_power": 0.38},
	)
	await process_frame
	var hand := _rig_hand(actor, "RightArm")
	_check(hand.z > 0.10 and hand.y > 0.50,
		"dink hand must be above and ahead of its shoulder (up %.2f, ahead %.2f)"
			% [hand.y, hand.z])

	var tail := actor.find_child("Tail", true, false) as MeshInstance3D
	_check(tail != null, "Cani contract rig must expose its authored tail")
	if tail != null:
		var root := Vector3(tail.get_meta("performance_root_local", Vector3.ZERO))
		var rest_rotation := Vector3(tail.get_meta("performance_rest_rotation"))
		var rest_position := Vector3(tail.get_meta("performance_rest_position"))
		var scaled_root := root * tail.scale
		var rest_attachment := rest_position \
			+ Basis.from_euler(rest_rotation) * scaled_root
		actor.set_pose(
			RallyEventModel.EventType.ATTACK, Spike.elevation_at(0.38), 0.38,
			Vector2.UP, true,
			{"attack_type": "Power swing", "action_power": 0.82},
		)
		var moved_attachment := tail.position \
			+ Basis.from_euler(tail.rotation) * scaled_root
		_check(not tail.rotation.is_equal_approx(rest_rotation),
			"attached tail must respond passively during follow-through")
		_check(moved_attachment.distance_to(rest_attachment) < 0.0001,
			"passive anatomy must flex without detaching from the body")
		# A jump attack correctly hands to the landing system. Use a grounded set
		# to exercise the ordinary action-to-ready continuity seam.
		actor._was_airborne = false
		actor._landing_remaining = 0.0
		actor.set_pose(
			RallyEventModel.EventType.SET, 0.0, 0.80, Vector2.UP, true,
			{"set_posture": "standing", "back_set": false},
		)
		actor.set_pose(-1, 0.0, 0.0, Vector2.UP, false)
		_check(actor._handoff_remaining > 0.0,
			"grounded completed action must continue into a timed ready handoff")
	actor.queue_free()
	await process_frame


func _rig_hand(actor: Node3D, arm_name: String) -> Vector3:
	var arm := actor.get_node("BodyPivot/%s" % arm_name) as Node3D
	var elbow := arm.get_node("Elbow") as Node3D
	var mesh := elbow.get_node("Mesh") as MeshInstance3D
	var length := mesh.mesh.get_aabb().size.y * elbow.scale.y
	var tip: Vector3 = elbow.global_transform * Vector3(0.0, -length, 0.0)
	var local: Vector3 = actor.global_transform.basis.inverse() \
		* (tip - arm.global_position)
	return Vector3(local.x, local.y, -local.z)
