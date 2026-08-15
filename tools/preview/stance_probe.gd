extends Node

## Where a posed voli's feet, hips, head and forearms actually are, in metres.
##
## A stance is a geometric claim -- "the feet are apart", "the hips are low",
## "the platform is in front of and below the waist" -- and every one of those is
## a number the rig already knows. Judging them by eye off a 200px sticker is how
## the passer ended up reading as a forward lean: the trunk angle and the hip
## height were never separated, so a shallow squat and a deep bow looked alike.
##
## One line per posture and phase: foot separation across the body, the lower
## shoe's height off the floor (negative means through it), hip and head heights,
## and where the forearms finished relative to the hips.
##
## Run it:
##
##     xvfb-run -a godot --path . res://tools/preview/stance_probe.tscn

const ActorScene := preload("res://scenes/components/player_actor_3d.tscn")
const RallyEventModel := preload("res://scripts/models/rally_event.gd")

const POSTURES: Array[String] = ["planted", "moving", "reaching", "off-axis"]
const PHASES: Array[float] = [-0.34, -0.20, -0.08, 0.00, 0.16, 0.34]
const PROFILE := {
	"height_cm": 190.0, "wingspan_cm": 196.0, "stride_length_m": 0.86,
	"body_type": "Cani", "standing_reach_meters": 2.48,
	"jumping_reach_meters": 3.20,
}


func _ready() -> void:
	var actor := ActorScene.instantiate() as PlayerActor3D
	add_child(actor)
	actor.configure(1, true, "Probe", "Right", PROFILE)
	await get_tree().process_frame

	print("rig: hip_offset=%s legs=%s height_scale=%.3f leg_scale=%.3f rest_ankle=%.3f" % [
		actor.hip_offset, actor.leg_bone_lengths, actor.body_height_scale,
		actor.leg_length_scale,
		(actor.hip_offset.y - actor.leg_bone_lengths.x - actor.leg_bone_lengths.y)
			* actor.body_height_scale,
	])
	print("posture   phase  feet-apart  low-shoe    hip    head   arm-fwd  arm-up")
	for posture in POSTURES:
		for phase in PHASES:
			actor.contact_posture = posture
			actor.set_pose(
				RallyEventModel.EventType.DIG, 0.0, phase,
				Vector2(0.0, 1.0), true
			)
			await get_tree().process_frame
			var left_shoe := _at(actor, "BodyPivot/LeftLeg/Knee/Shoe")
			var right_shoe := _at(actor, "BodyPivot/RightLeg/Knee/Shoe")
			var hip := _at(actor, "BodyPivot/LeftLeg").lerp(
				_at(actor, "BodyPivot/RightLeg"), 0.5
			)
			var head := _at(actor, "BodyPivot/Head")
			## Mid-forearm, which is the surface a platform is made of. There is no
			## hand node on this rig, and the forearm is what a passer aims with.
			var arm := _at(actor, "BodyPivot/LeftArm/Elbow/Mesh").lerp(
				_at(actor, "BodyPivot/RightArm/Elbow/Mesh"), 0.5
			)
			print("%-9s %+.2f  %6.3f     %+.3f    %.3f  %.3f   %+.3f   %+.3f" % [
				posture, phase,
				## On the floor plane, not across x. An off-axis dig twists the whole
				## body, and measuring only x reported that stance as 20 cm narrower
				## than it is because the separation had rotated out of the axis.
				Vector2(
					left_shoe.x - right_shoe.x, left_shoe.z - right_shoe.z
				).length(),
				minf(left_shoe.y, right_shoe.y),
				hip.y, head.y,
				arm.z - hip.z, arm.y - hip.y,
			])
	get_tree().quit()


func _at(actor: PlayerActor3D, path: String) -> Vector3:
	var node := actor.get_node_or_null(path) as Node3D
	if node == null:
		return Vector3.ZERO
	return actor.to_local(node.global_position)
