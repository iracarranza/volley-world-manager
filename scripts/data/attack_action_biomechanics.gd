class_name AttackActionBiomechanics
extends RefCounted

## Variant-specific striking chains. The approach and take-off remain the
## canonical SpikeBiomechanics sequence; only the late hand action diverges.

const Spike := preload("res://scripts/data/spike_biomechanics.gd")

const POWER := &"power"
const ROLL := &"roll"
const DINK := &"dink"


static func family(attack_type: String) -> StringName:
	var lowered := attack_type.to_lower()
	if "roll" in lowered:
		return ROLL
	for token in ["feint", "dink", "tip"]:
		if token in lowered:
			return DINK
	return POWER


static func resolve(
	phase: float,
	handedness_sign: float,
	action_power: float,
	attack_type: String,
) -> Dictionary:
	var joints := Spike.resolve(phase, handedness_sign, action_power)
	var variant := family(attack_type)
	if variant == POWER:
		joints["attack_family"] = POWER
		return joints

	var p := clampf(phase, -1.0, 1.0)
	## The sell remains intact through most of the cock. This late envelope is the
	## biomechanical fact both soft-shot families depend on.
	var change := smoothstep(-0.18, -0.01, p) \
		* (1.0 - smoothstep(0.42, 0.88, p))
	var hand := 1.0 if handedness_sign >= 0.0 else -1.0
	if variant == ROLL:
		joints["striking_shoulder_degrees"] = lerpf(
			float(joints.striking_shoulder_degrees), -196.0, 0.82 * change
		)
		joints["striking_elbow_degrees"] = lerpf(
			float(joints.striking_elbow_degrees), 22.0, 0.90 * change
		)
		joints["striking_abduction_degrees"] = lerpf(
			float(joints.striking_abduction_degrees), 28.0 * hand, 0.82 * change
		)
		joints["striking_internal_rotation_degrees"] = lerpf(
			float(joints.get("striking_internal_rotation_degrees", 0.0)),
			8.0 * hand, 0.72 * change
		)
		joints["torso_pitch_radians"] = lerpf(
			float(joints.torso_pitch_radians), -0.08, 0.58 * change
		)
		joints["torso_twist_degrees"] = lerpf(
			float(joints.torso_twist_degrees), -4.0 * hand, 0.60 * change
		)
		# The guide arm stays available for balance instead of being ripped down
		# as it is in the power chain. Together with the open striking shoulder,
		# this makes the late deceleration legible in silhouette.
		joints["guide_shoulder_degrees"] = lerpf(
			float(joints.guide_shoulder_degrees), 62.0, 0.72 * change
		)
		joints["guide_elbow_degrees"] = lerpf(
			float(joints.guide_elbow_degrees), 28.0, 0.68 * change
		)
	else:
		joints["striking_shoulder_degrees"] = lerpf(
			# Past vertical: the elbow remains compact, but the *upper arm* has
			# already carried the hand in front of the striking shoulder.
			float(joints.striking_shoulder_degrees), -225.0, 0.96 * change
		)
		joints["striking_elbow_degrees"] = lerpf(
			float(joints.striking_elbow_degrees), 62.0, 0.98 * change
		)
		joints["striking_abduction_degrees"] = lerpf(
			float(joints.striking_abduction_degrees), 14.0 * hand, 0.82 * change
		)
		joints["striking_internal_rotation_degrees"] = lerpf(
			float(joints.get("striking_internal_rotation_degrees", 0.0)),
			10.0 * hand, 0.90 * change
		)
		joints["torso_pitch_radians"] = lerpf(
			float(joints.torso_pitch_radians), -0.01, 0.82 * change
		)
		joints["torso_twist_degrees"] = lerpf(
			float(joints.torso_twist_degrees), 0.0, 0.88 * change
		)
		## Keep the guide hand high: a compact touch is balanced by the other arm,
		## not by the violent guide-arm pull of a power swing.
		joints["guide_shoulder_degrees"] = lerpf(
			float(joints.guide_shoulder_degrees), 92.0, 0.76 * change
		)
	joints["attack_family"] = variant
	joints["variant_weight"] = change
	return joints
