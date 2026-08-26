extends SceneTree

## Certifies the presentation contact-anchor contract against the real posed rig.
## Every row is silhouette x posture, and the reported error is ball centre to
## the anchor used by playback after body placement.

const Events := preload("res://scripts/models/rally_event.gd")
const BodyTypes := preload("res://scripts/data/body_type_models.gd")
const Promotion := preload("res://scripts/simulation/geometric_attack_promotion.gd")

const BALL_CENTRE := Vector3(1.35, 0.0, -2.10)
const CONTACT_ERROR_LIMIT_METERS := 0.003


func _initialize() -> void:
	var scene := load("res://scenes/components/player_actor_3d.tscn") as PackedScene
	var heights := [1.72, 1.88, 2.06]
	var worst := 0.0
	var worst_body_shift := 0.0
	var worst_body_shift_row := ""
	var rows := 0
	var postures := _postures()
	for body_index in range(BodyTypes.MODELLED.size()):
		var body_name := str(BodyTypes.MODELLED[body_index])
		var height := float(heights[body_index % heights.size()])
		var wingspan := height * 1.02
		var standing_reach := height * 1.215 + (wingspan - height) * 0.32
		var jumping_reach := standing_reach + 0.68
		for posture in postures:
			var actor := scene.instantiate() as PlayerActor3D
			get_root().add_child(actor)
			await process_frame
			actor.configure(body_index + 1, true, body_name, "Right", {
				"height_cm": height * 100.0,
				"wingspan_cm": wingspan * 100.0,
				"stride_length_m": height * 0.43,
				"body_type": body_name,
			})
			actor.block_arms = StringName(str(posture.get("block_arms", "two")))
			actor.contact_posture = "planted"
			actor.contact_recovery = "platform"
			actor.contact_platform_aim = {}
			var context := Dictionary(posture.context).duplicate(true)
			var target_height := _target_height(
				str(posture.name), height, standing_reach, jumping_reach
			)
			actor.set_pose(
				int(posture.event_type), float(posture.elevation), 0.0,
				Vector2(0.18, -0.92), true, context,
			)
			var body_before := (actor.get_node("BodyPivot") as Node3D).position.y
			actor.fit_contact_anchor_height(
				int(posture.event_type), target_height, context
			)
			var body_shift := absf(
				(actor.get_node("BodyPivot") as Node3D).position.y - body_before
			)
			if body_shift > worst_body_shift:
				worst_body_shift = body_shift
				worst_body_shift_row = "%s / %s" % [body_name, str(posture.name)]
			var before := actor.contact_anchor_world_position(
				int(posture.event_type), context
			)
			var ball := Vector3(BALL_CENTRE.x, target_height, BALL_CENTRE.z)
			actor.global_position += Vector3(
				ball.x - before.x, 0.0, ball.z - before.z
			)
			var after := actor.contact_anchor_world_position(
				int(posture.event_type), context
			)
			var error := after.distance_to(ball)
			worst = maxf(worst, error)
			rows += 1
			print("  %-5s %-22s %.6f m" % [body_name, str(posture.name), error])
			actor.queue_free()
			await process_frame
	print("\ncontact anchors -- %d silhouette/posture rows" % rows)
	print("  worst ball-centre-to-anchor error %.8f m" % worst)
	print("  limit                             %.8f m" % CONTACT_ERROR_LIMIT_METERS)
	print("  worst derived vertical body fit   %.6f m (%s)" % [
		worst_body_shift, worst_body_shift_row,
	])
	if rows == BodyTypes.MODELLED.size() * postures.size() \
			and worst <= CONTACT_ERROR_LIMIT_METERS:
		print("\nPASS: posed contact-anchor gates")
		quit(0)
		return
	push_error("FAIL: contact-anchor error %.6f m" % worst)
	quit(1)


func _postures() -> Array[Dictionary]:
	return [
		{"name": "reception platform", "event_type": Events.EventType.RECEPTION,
			"elevation": 0.0, "context": {}},
		{"name": "standing front set", "event_type": Events.EventType.SET,
			"elevation": 0.0, "context": {"set_posture": "standing"}},
		{"name": "standing back set", "event_type": Events.EventType.SET,
			"elevation": 0.0,
			"context": {"set_posture": "standing", "back_set": true}},
		{"name": "jump front set", "event_type": Events.EventType.SET,
			"elevation": 0.58, "context": {"set_posture": "jump"}},
		{"name": "jump back set", "event_type": Events.EventType.SET,
			"elevation": 0.58,
			"context": {"set_posture": "jump", "back_set": true}},
		{"name": "underhand set", "event_type": Events.EventType.SET,
			"elevation": 0.0,
			"context": {"set_posture": "standing",
				"set_posture_reason": "under the hands"}},
		{"name": "attack hand", "event_type": Events.EventType.ATTACK,
			"elevation": 1.0, "context": {"action_power": 0.8}},
		{"name": "serve hand", "event_type": Events.EventType.SERVE,
			"elevation": 0.92, "context": {"action_power": 0.8}},
		{"name": "two-hand block", "event_type": Events.EventType.BLOCK,
			"elevation": 0.62, "context": {}, "block_arms": "two"},
		{"name": "one-hand block", "event_type": Events.EventType.BLOCK,
			"elevation": 0.62, "context": {}, "block_arms": "right"},
	]


func _target_height(
	posture: String, height: float, standing_reach: float, jumping_reach: float
) -> float:
	if posture in ["reception platform", "underhand set"]:
		return Promotion.pass_contact_from_height(height)
	if posture.begins_with("standing"):
		return Promotion.set_contact_from_reach(standing_reach, jumping_reach, false)
	if posture.begins_with("jump"):
		return Promotion.set_contact_from_reach(standing_reach, jumping_reach, true)
	if posture == "serve hand":
		return Promotion.serve_contact_from_reach(
			standing_reach, jumping_reach, 0.92
		)
	if posture == "attack hand":
		return Promotion.hitter_contact_from_reach(
			standing_reach, jumping_reach, 1.0
		)
	return Promotion.block_contact_from_reach(jumping_reach)
