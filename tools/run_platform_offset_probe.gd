extends SceneTree

## How far in front of a passer is the platform?
##
##     godot --headless --path . --script res://tools/run_platform_offset_probe.gd
##
## Reported: receivers and their positioning are centred on the body's centre
## rather than on the centre of the platform.
##
## They are. `_build_movement_plan` sends the upcoming contact's actor to
## `next_contact.start_position` -- the point where the resolver says the ball
## was played -- and playback places the *body origin* there. But a pass is not
## struck at the sternum. It is struck on two joined forearms held out in front,
## and drawing the body at the ball puts the ball somewhere behind the arms and
## inside the chest.
##
## The size of the correction is a rig fact, not a number to choose, so it is
## measured off the rig rather than written down: pose a real actor in a real
## dig and read where the forearms actually end up relative to the body. That
## also means the answer tracks the body -- a tall voli reaches further than a
## short one, and both are drawn from the same silhouette machinery.
##
## Reported per body type, because if the spread across bodies is small the
## correction can be one constant, and if it is large it has to be derived per
## voli. That is the question the fix depends on, and guessing it either way is
## how a threshold ends up outside its own distribution.
func _initialize() -> void:
	var scene := load("res://scenes/components/player_actor_3d.tscn") as PackedScene
	var Events := load("res://scripts/models/rally_event.gd")
	var BodyTypes := load("res://scripts/data/body_type_models.gd")

	print("%-16s %8s %10s %12s %12s" % [
		"body", "height", "shoulder", "platform m", "vs body"])
	var reaches: Array[float] = []
	## Every modelled silhouette, at the height range the generator actually
	## produces, so the spread below is the spread on a real court rather than
	## across two invented extremes.
	var heights := [1.72, 1.88, 2.06]
	for body_name in BodyTypes.MODELLED:
		var actor = scene.instantiate()
		get_root().add_child(actor)
		var profile := {
			"height_meters": float(heights[BodyTypes.MODELLED.find(body_name) % 3]),
			"body_type": body_name,
		}
		actor.configure(1, true, body_name, "Right", profile)
		## A square, planted pass with the platform aimed straight ahead. The
		## posture with the *least* reach in it, deliberately: an off-axis or
		## reaching dig extends further, so this is the floor of the correction
		## rather than a flattering middle.
		actor.contact_posture = "planted"
		actor.contact_recovery = "platform"
		actor.contact_platform_aim = {}
		actor.set_pose(
			Events.EventType.RECEPTION, 0.0, 0.0, Vector2(0.0, -1.0), true
		)
		await process_frame
		## Where the two forearms meet, in the actor's own frame. The elbow node
		## is the top of the forearm and the platform is the surface below it, so
		## the contact point is a forearm's length past the elbow along the arm.
		var platform := _platform_point(actor)
		var forward := absf(platform.z)
		reaches.append(forward)
		print("%-16s %8.2f %10.2f %12.2f %12s" % [
			body_name, float(profile["height_meters"]),
			actor.shoulder_offset.y, forward,
			"%.0f cm ahead" % (forward * 100.0),
		])
		actor.queue_free()
		await process_frame

	var lowest := 99.0
	var highest := 0.0
	var sum := 0.0
	for value in reaches:
		lowest = minf(lowest, value)
		highest = maxf(highest, value)
		sum += value
	print("\nrange %.2f to %.2f m, mean %.2f, spread %.0f cm" % [
		lowest, highest, sum / maxf(float(reaches.size()), 1.0),
		(highest - lowest) * 100.0,
	])
	quit()


## Where the platform's contact point sits relative to the body origin.
##
## Taken from the rendered transforms rather than recomputed from the pose's own
## angles: the pose is written as shoulder pitch, yaw and roll composed through
## three nested bases plus a trunk pitch, and reimplementing that composition out
## here to predict where it lands is precisely the second opinion this repository
## keeps having to delete. The nodes know where they are; ask them.
func _platform_point(actor) -> Vector3:
	var mid := Vector3.ZERO
	var arms := 0
	for arm_name in ["LeftArm", "RightArm"]:
		var arm := actor.get_node_or_null("BodyPivot/%s" % arm_name) as Node3D
		if arm == null:
			continue
		var elbow := arm.get_node_or_null("Elbow") as Node3D
		if elbow == null:
			continue
		## A forearm's length below the elbow, along the forearm's own down axis,
		## which is where a platform's contact surface is.
		var fore_length: float = float(actor.arm_bone_lengths.y) \
			* float(actor.arm_length_scale)
		var hand := elbow.global_transform * Vector3(0.0, -fore_length, 0.0)
		mid += actor.global_transform.affine_inverse() * hand
		arms += 1
	return mid / maxf(float(arms), 1.0)
