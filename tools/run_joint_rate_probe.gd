extends SceneTree

## How fast a joint legitimately moves, so a smoother can be set above it.
##
## The question this answers: can one global rate limit both preserve the
## spike's whip and visibly slow a block's arms coming up? A limit has to sit
## *above* the fastest motion that is supposed to happen, or it damages it -- so
## if the fastest legitimate motion is already faster than the speed a snap
## should be smoothed at, one ceiling cannot do both jobs and the answer is
## decomposition rather than smoothing.

const SpikeBiomechanicsScript := preload("res://scripts/data/spike_biomechanics.gd")
const GaitBiomechanicsScript := preload("res://scripts/data/gait_biomechanics.gd")

## Phase spans 1.0 across one ball flight, so degrees-per-phase becomes
## degrees-per-second by dividing by the flight's duration. A quick set is about
## the shortest window playback ever runs a pose across.
const SHORTEST_FLIGHT_SECONDS: float = 0.45
const TYPICAL_FLIGHT_SECONDS: float = 0.90


func _initialize() -> void:
	print("=== fastest spike joints, in degrees per unit phase ===")
	var keys := [
		"striking_shoulder_degrees", "striking_elbow_degrees",
		"guide_shoulder_degrees", "guide_elbow_degrees",
		"knee_degrees", "lead_hip_degrees", "trail_hip_degrees",
	]
	var step := 0.002
	var worst := 0.0
	var worst_key := ""
	for key in keys:
		var peak := 0.0
		var peak_at := 0.0
		var previous: Dictionary = SpikeBiomechanicsScript.resolve(-1.0, 1.0)
		for index in range(1, int(2.0 / step) + 1):
			var phase := -1.0 + float(index) * step
			var current: Dictionary = SpikeBiomechanicsScript.resolve(phase, 1.0)
			var rate := absf(float(current[key]) - float(previous[key])) / step
			if rate > peak:
				peak = rate
				peak_at = phase
			previous = current
		print(
			"%-28s %7.0f deg/phase at %+.2f  -> %6.0f deg/s quick, %5.0f deg/s typical"
			% [
				key, peak, peak_at,
				peak / SHORTEST_FLIGHT_SECONDS, peak / TYPICAL_FLIGHT_SECONDS,
			]
		)
		if peak > worst:
			worst = peak
			worst_key = key

	print("")
	print("=== fastest gait joints, at a sprint ===")
	## A stride is driven by distance, so its rate depends on how fast the voli
	## is going: one full cycle per stride length at the running speed.
	var speed := 5.2
	var stride_length := 0.95
	var cycles_per_second := speed / stride_length
	var gait_peak := 0.0
	var gait_key := ""
	for key in ["right_hip_degrees", "right_knee_degrees", "right_arm_degrees"]:
		var peak := 0.0
		var previous: Dictionary = GaitBiomechanicsScript.resolve(0.0, speed)
		for index in range(1, 1001):
			var cycle := float(index) / 1000.0
			var current: Dictionary = GaitBiomechanicsScript.resolve(cycle, speed)
			peak = maxf(
				peak, absf(float(current[key]) - float(previous[key])) * 1000.0
			)
			previous = current
		print(
			"%-28s %7.0f deg/cycle-unit -> %6.0f deg/s at %.1f m/s"
			% [key, peak, peak * cycles_per_second, speed]
		)
		if peak * cycles_per_second > gait_peak:
			gait_peak = peak * cycles_per_second
			gait_key = key

	print("")
	var spike_quick := worst / SHORTEST_FLIGHT_SECONDS
	print("fastest legitimate motion: %s at %.0f deg/s (spike, quick set)"
		% [worst_key, spike_quick])
	print("fastest gait motion:       %s at %.0f deg/s" % [gait_key, gait_peak])
	print("")
	## The block's arms go from a neutral hang to 158 degrees in one frame. What
	## a limit set above the spike would do to that snap:
	var snap := 158.0
	print("a 158-degree block snap, under a ceiling set above the spike:")
	for headroom: float in [1.0, 1.25, 1.5]:
		var ceiling := spike_quick * headroom
		print(
			"  ceiling %6.0f deg/s (%.2fx spike) -> snap resolves in %.3f s"
			% [ceiling, headroom, snap / ceiling]
		)
	print("")
	print("for the arms to take a readable %.2f s, the ceiling would be %.0f deg/s"
		% [0.22, snap / 0.22])
	quit()
