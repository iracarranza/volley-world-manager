extends SceneTree

## What the gait and landing models actually produce, as numbers.
##
## The claim that separates a walk from a run in `GaitBiomechanics` is that the
## hips are highest at midstance in one and lowest in the other. That is a claim
## about a sign, and a sign is checkable without looking at anything.

const GaitBiomechanics := preload("res://scripts/data/gait_biomechanics.gd")
const LandingBiomechanics := preload("res://scripts/data/landing_biomechanics.gd")


func _initialize() -> void:
	print("=== gait across speed, sampled through one stride ===")
	for speed in [0.0, 0.8, 1.8, 3.0, 5.0]:
		var named := GaitBiomechanics.gait_name(speed)
		var sample := GaitBiomechanics.resolve(0.0, speed)
		print(
			"%4.1f m/s  %-6s run_blend %.2f  gait %.2f  elbow %5.1f  torso %+.3f"
			% [
				speed, named, sample.run_blend, sample.gait_blend,
				sample.elbow_degrees, sample.torso_pitch_radians,
			]
		)
		var knee_extremes := Vector2(999.0, -999.0)
		var bob_at_midstance := 0.0
		var stance_share: float = lerpf(
			GaitBiomechanics.WALK_STANCE_SHARE,
			GaitBiomechanics.RUN_STANCE_SHARE,
			float(sample.run_blend),
		)
		for step in range(64):
			var cycle := float(step) / 64.0
			var frame := GaitBiomechanics.resolve(cycle, speed)
			knee_extremes.x = minf(knee_extremes.x, float(frame.right_knee_degrees))
			knee_extremes.y = maxf(knee_extremes.y, float(frame.right_knee_degrees))
			if absf(cycle - stance_share * 0.5) < 1.0 / 128.0:
				bob_at_midstance = float(frame.bob_meters)
		print(
			"          knee %6.1f .. %5.1f   bob at midstance %+.4f m (%s)"
			% [
				knee_extremes.x, knee_extremes.y, bob_at_midstance,
				"HIGH -- vaulting" if bob_at_midstance > 0.0 else "LOW -- springing",
			]
		)

	print("")
	print("=== landing, per action ===")
	for action in ["attack", "block", "serve", "default"]:
		var deepest := 0.0
		var deepest_at := 0.0
		for step in range(41):
			var progress := float(step) / 40.0
			var frame := LandingBiomechanics.resolve(progress, action)
			if float(frame.knee_degrees) < deepest:
				deepest = float(frame.knee_degrees)
				deepest_at = progress
		var touchdown := LandingBiomechanics.resolve(0.0, action)
		var finished := LandingBiomechanics.resolve(1.0, action)
		print(
			"%-8s %.2fs  deepest %6.1f at %.2f  touchdown knee %5.1f arm %5.1f"
			% [
				action, LandingBiomechanics.duration_seconds(action),
				deepest, deepest_at,
				touchdown.knee_degrees, touchdown.arm_degrees,
			]
		)
		print(
			"          finishes at knee %5.1f torso %+.3f drop %+.3f -- %s"
			% [
				finished.knee_degrees, finished.torso_pitch_radians,
				finished.drop_meters,
				"neutral" if absf(float(finished.knee_degrees)) < 0.01 else "RESIDUAL",
			]
		)
	quit()
