extends SceneTree

## Where the striking hand actually goes during a spike, in metres.
##
##     godot --headless --path . --script res://tools/measure_spike_swing.gd
##
## `SpikeBiomechanics` is a table of joint angles and every correction it has
## ever taken was argued in degrees. Degrees are not what anybody watches. A
## shoulder at -204 and an elbow at 7 could be a hitter reaching over the ball or
## a hitter shoving forward at chest height, and the two are told apart by where
## the hand is -- which nothing in the pipeline has ever printed.
##
## So this drives a real `PlayerActor3D` through the real attack pose and reads
## the end of the striking forearm off the rig, relative to the striking
## shoulder. Three numbers per sample:
##
##   up      metres above the shoulder. A spike is struck above it. A swing that
##           peaks near zero here is the reported "joust/push against the block"
##           however good the angles look on paper.
##   ahead   metres in front of the chest, along the direction of the hit.
##   out     metres to the striking side. Zero all the way through means the arm
##           is swinging in one plane, which is the windmill this model exists to
##           avoid.
##
## Plus the speed of the hand between samples, converted to metres per second
## against the real duration of each half of the phase, because "snappy" is a
## speed and speeds are the thing to argue about.
##
## The guide arm gets its own column for the same reason: it was tuned to reach
## and pull, and the report is that it does nothing. Either its hand moves or it
## does not.
const SAMPLES: int = 41

## What one unit of phase is worth in seconds.
##
## The current playback has two negative-phase clocks. The legacy approach owns
## -1 through the plant; the resolved takeoff-to-contact interval owns the rest.
## Keeping those clocks separate prevents a long approach from making the real
## overhead swing appear artificially slow in this report.
const APPROACH_SECONDS: float = 1.04
const TAKEOFF_TO_CONTACT_SECONDS: float = 0.22
const SWING_SECONDS: float = 0.81


func _initialize() -> void:
	var Events := load("res://scripts/models/rally_event.gd")
	var attack_type := "Power swing"
	var scan_dink := false
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--attack-type="):
			attack_type = argument.trim_prefix("--attack-type=")
		elif argument == "--scan-dink":
			scan_dink = true
	var actor: Node3D = load("res://scenes/components/player_actor_3d.tscn").instantiate()
	get_root().add_child(actor)
	await process_frame
	actor.configure(1, true, "Probe", "Right", {"height_cm": 196.0})
	await process_frame
	if scan_dink:
		await _scan_dink_contact(actor, Events)
		quit()
		return

	print("%s; phase is signed: -1 wind-up, 0 contact, +1 landing" % attack_type)
	print("%7s %-14s %7s %7s %7s %9s %8s" % [
		"phase", "name", "up m", "ahead m", "out m", "hand m/s", "guide m",
	])
	var previous_hand := Vector3.ZERO
	var previous_phase := -1.0
	var fastest := 0.0
	var fastest_phase := 0.0
	var contact_hand := Vector3.ZERO
	var guide_travel := 0.0
	var previous_guide := Vector3.ZERO
	for step in range(SAMPLES):
		var phase := lerpf(-1.0, 1.0, float(step) / float(SAMPLES - 1))
		actor.set_pose(
			Events.EventType.ATTACK, 1.0, phase, Vector2(0.0, -1.0), true,
			{"attack_type": attack_type, "action_power": 0.82},
		)
		await process_frame
		var hand := _hand(actor, "RightArm")
		var guide := _hand(actor, "LeftArm")
		var speed := 0.0
		if step > 0:
			var seconds := _phase_seconds(previous_phase, phase)
			speed = hand.distance_to(previous_hand) / maxf(seconds, 0.0001)
			guide_travel += guide.distance_to(previous_guide)
			if speed > fastest:
				fastest = speed
				fastest_phase = phase
		if absf(phase) < 0.03:
			contact_hand = hand
		print("%7.3f %-14s %7.2f %7.2f %7.2f %9.1f %8.2f" % [
			phase, SpikeBiomechanics.phase_name(phase),
			hand.y, hand.z, hand.x, speed, guide.y,
		])
		previous_hand = hand
		previous_guide = guide
		previous_phase = phase
	print("")
	print("contact hand: %.2f m above the shoulder, %.2f m ahead, %.2f m out" % [
		contact_hand.y, contact_hand.z, contact_hand.x,
	])
	print("fastest hand: %.1f m/s at phase %.3f" % [fastest, fastest_phase])
	print("guide hand travelled %.2f m over the whole action" % guide_travel)
	quit()


func _scan_dink_contact(actor: Node3D, Events: Script) -> void:
	print("dink contact scan: hand metres relative to striking shoulder")
	for shoulder in [-195.0, -205.0, -215.0, -225.0, -235.0]:
		for elbow in [42.0, 52.0, 62.0]:
			actor.set_pose(
				Events.EventType.ATTACK, 1.0, 0.0, Vector2(0.0, -1.0), true,
				{"attack_type": "Dink", "action_power": 0.38},
			)
			var arm := actor.get_node("BodyPivot/RightArm") as Node3D
			arm.rotation_degrees = Vector3(shoulder, 10.0, 14.0)
			actor._set_elbow(arm, elbow)
			await process_frame
			var hand := _hand(actor, "RightArm")
			print("shoulder %6.1f elbow %4.1f -> up %.2f ahead %.2f out %.2f" % [
				shoulder, elbow, hand.y, hand.z, hand.x,
			])


func _phase_seconds(from_phase: float, to_phase: float) -> float:
	var seconds := 0.0
	var cursor := from_phase
	if cursor < SpikeBiomechanics.PLANT_END:
		var approach_end := minf(to_phase, SpikeBiomechanics.PLANT_END)
		seconds += (approach_end - cursor) \
			/ (SpikeBiomechanics.PLANT_END + 1.0) * APPROACH_SECONDS
		cursor = approach_end
	if cursor < 0.0 and to_phase > cursor:
		var takeoff_end := minf(to_phase, 0.0)
		seconds += (takeoff_end - cursor) \
			/ -SpikeBiomechanics.PLANT_END * TAKEOFF_TO_CONTACT_SECONDS
		cursor = takeoff_end
	if to_phase > cursor:
		seconds += (to_phase - cursor) * SWING_SECONDS
	return maxf(seconds, 0.0001)


## The end of the striking forearm, in the body's own frame.
##
## Built from the two joint rotations rather than read off a node, because the
## rig has no hand node -- the forearm mesh carries the hand. Returned as
## (out, up, ahead) with `ahead` positive toward the net the hitter faces.
func _hand(actor: Node3D, arm_name: String) -> Vector3:
	var arm := actor.get_node("BodyPivot/%s" % arm_name) as Node3D
	var elbow := arm.get_node("Elbow") as Node3D
	var tip: Vector3 = elbow.global_transform * Vector3(0.0, -_forearm_length(elbow), 0.0)
	var shoulder: Vector3 = arm.global_position
	var local: Vector3 = actor.global_transform.basis.inverse() * (tip - shoulder)
	return Vector3(local.x, local.y, -local.z)


## How long the forearm segment is, taken from its own mesh rather than assumed.
func _forearm_length(elbow: Node3D) -> float:
	var mesh := elbow.get_node_or_null("Mesh") as MeshInstance3D
	if mesh == null or mesh.mesh == null:
		return 0.32
	return mesh.mesh.get_aabb().size.y * elbow.scale.y
