extends SceneTree

## The three second-contact postures, side by side, through the phase.
##
##     xvfb-run -a godot --path . --script res://tools/run_set_posture_shot.gd
##
## Three actions that were drawn identically until now: a standing push, a jump
## set, and a ball taken off the forearms because it never rose to hand height.
##
## Rendered as a grid rather than three separate images, because the failure
## this guards against is not "the pose looks wrong" -- it is "the pose is the
## same pose". A stack of three images that differ subtly is exactly what a
## posture argument that never arrives produces, and that has happened on this
## branch already with `block_jump_timing`.
##
## Numbers as well as pictures, for the same reason: two poses can look
## different in a still and be the same solve under a different camera.

const PHASES: Array[float] = [-0.55, -0.16, 0.0, 0.30, 0.70]
const POSTURES: Array[StringName] = [&"standing", &"jump", &"underhand"]


func _initialize() -> void:
	var Sets := load("res://scripts/data/set_biomechanics.gd")
	print("=== set postures, joint by joint")
	print("%-11s %6s %9s %8s %8s %8s %7s" % [
		"posture", "phase", "shoulder", "elbow", "knee", "split", "rise",
	])
	var signatures := {}
	for posture in POSTURES:
		var signature := ""
		for phase in PHASES:
			var joints: Dictionary = Sets.resolve(phase, 1.0, posture)
			print("%-11s %6.2f %9.1f %8.1f %8.1f %8.1f %7.3f" % [
				str(posture), phase,
				float(joints.shoulder_degrees), float(joints.elbow_degrees),
				float(joints.knee_degrees), float(joints.hip_split_degrees),
				float(joints.rise_metres),
			])
			signature += "%.1f|%.1f|%.1f|%.3f;" % [
				float(joints.shoulder_degrees), float(joints.elbow_degrees),
				float(joints.knee_degrees), float(joints.rise_metres),
			]
		signatures[str(posture)] = signature
		print("")

	## The check that matters. If two postures produce the same joint string
	## across the whole phase then the argument is not reaching the solve, and no
	## amount of looking at renders would tell you that reliably.
	var names: Array = signatures.keys()
	var identical := 0
	for first_index in range(names.size()):
		for second_index in range(first_index + 1, names.size()):
			var same: bool = signatures[names[first_index]] \
				== signatures[names[second_index]]
			print("%s vs %s: %s" % [
				names[first_index], names[second_index],
				"IDENTICAL -- the posture is not reaching the solve" if same \
					else "distinct",
			])
			identical += int(same)
	print("--- %d identical pairs (want 0)" % identical)

	## And the three claims the postures are supposed to make, stated as
	## assertions rather than left for a reader to eyeball off the table.
	var standing_peak := float(Sets.resolve(0.0, 1.0, &"standing").rise_metres)
	var jump_peak := float(Sets.resolve(0.0, 1.0, &"jump").rise_metres)
	print("jump leaves the floor: %.3f m against a standing push of %.3f m -- %s"
		% [jump_peak, standing_peak,
			"yes" if jump_peak > standing_peak * 3.0 else "NO"])
	var jump_split := absf(float(Sets.resolve(0.0, 1.0, &"jump").hip_split_degrees))
	var standing_split := absf(
		float(Sets.resolve(0.0, 1.0, &"standing").hip_split_degrees)
	)
	print("the stance closes in the air: %.1f deg against %.1f deg -- %s"
		% [jump_split, standing_split,
			"yes" if jump_split < standing_split else "NO"])
	var under_finish := float(Sets.resolve(0.45, 1.0, &"underhand").shoulder_degrees)
	var under_contact := float(Sets.resolve(0.0, 1.0, &"underhand").shoulder_degrees)
	print("the underhand finish points up: %.1f deg at the finish against %.1f at contact -- %s"
		% [under_finish, under_contact,
			"yes" if under_finish > under_contact + 30.0 else "NO"])
	var under_elbow := float(Sets.resolve(0.0, 1.0, &"underhand").elbow_degrees)
	print("the platform stays locked: elbow %.1f deg -- %s"
		% [under_elbow, "yes" if under_elbow < 10.0 else "NO"])
	quit()
