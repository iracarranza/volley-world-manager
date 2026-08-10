extends SceneTree

## Whether the jump model preserves the reach Gate D calibrated.
##
## `BLOCKER_REACH_EFFORT` is a flat 0.62 of every blocker's leap. Replacing it
## with a timing-derived phase is only an honest change if the *population mean*
## comes out at 0.62 -- otherwise it is two changes wearing one name, adding
## timing and rebalancing the wall's strength at the same time, and no sweep read
## afterwards could tell them apart.
##
## So this reports the mean before anything else, and the spread beside it,
## because the spread is the entire point: the same average wall, but a
## well-timed blocker meeting the ball at full extension and a mistimed one
## already coming down.
##
## Run:
##   godot --headless --path . --script res://tools/run_block_jump_probe.gd

const PlayerGeneratorModel := preload("res://scripts/systems/player_generator.gd")
const BlockJumpModelRef := preload("res://scripts/simulation/block_jump_model.gd")
const SignatureMoveModelRef := preload(
	"res://scripts/simulation/signature_move_model.gd"
)
const PromotionScript := preload(
	"res://scripts/simulation/geometric_attack_promotion.gd"
)

const SAMPLES: int = 3000


func _initialize() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 20260805
	var squad: Array = []
	var roles := ["Middle Blocker", "Opposite", "Outside Hitter"]
	for index in range(30):
		squad.append(PlayerGeneratorModel.generate_prospect(
			"Landavol",
			str(roles[index % roles.size()]),
			"MB",
			rng.randi_range(22, 30),
			rng.randi_range(58, 84),
			index + 1,
			"Jump %d" % index,
			rng.randi(),
		))
	var phases: Array = []
	var hangs: Array = []
	var states := {}
	var effects: Array = []
	var timings: Array = []
	var monster_ready := 0
	var monster_candidates := 0
	for index in range(SAMPLES):
		var blocker: VolleyballPlayer = squad[rng.randi_range(0, squad.size() - 1)]
		var leap := maxf(
			(blocker.jumping_reach_cm() - blocker.standing_reach_cm()) / 100.0, 0.0
		)
		## The read and the close as the rally distributes them, not at their best.
		var jump: Dictionary = BlockJumpModelRef.resolve(
			leap,
			clampf(float(blocker.block_timing) / 100.0, 0.0, 1.0),
			rng.randf_range(0.25, 0.95),
			## Close fractions as live rallies distribute them -- p10 0.475,
			## p25 0.785, p50 and above 1.00. Sampling this uniformly over its
			## range is not the same distribution and inflates every state that
			## keys off it.
			_live_close(rng),
		)
		phases.append(float(jump.phase))
		hangs.append(float(jump.hang_seconds))
		effects.append(float(jump.effectiveness))
		timings.append(float(jump.timing_quality))
		var state := str(jump.arm_state)
		states[state] = int(states.get(state, 0)) + 1
		var monster_charge := SignatureMoveModelRef.charge(
			SignatureMoveModelRef.monster_block_capability(
				float(blocker.block_timing) / 100.0,
				float(blocker.anticipation) / 100.0,
				float(blocker.composure) / 100.0,
			),
			float(blocker.match_confidence), 0.0,
		)
		if SignatureMoveModelRef.is_available(monster_charge):
			monster_ready += 1
			if float(jump.timing_quality) \
				>= SignatureMoveModelRef.MONSTER_BLOCK_TIMING_THRESHOLD \
				and state == "extended":
				monster_candidates += 1

	phases.sort()
	hangs.sort()
	timings.sort()
	var total := 0.0
	for value in phases:
		total += float(value)
	var mean := total / float(phases.size())
	print("Block jump timing -- %d samples over a generated population" % SAMPLES)
	print("")
	print("phase (fraction of leap available at the ball)")
	print("   mean %.3f   <- must reproduce BLOCKER_REACH_EFFORT %.2f" % [
		mean, PromotionScript.BLOCKER_REACH_EFFORT])
	print("   p10 %.3f  p25 %.3f  p50 %.3f  p75 %.3f  p90 %.3f" % [
		_percentile(phases, 0.10), _percentile(phases, 0.25),
		_percentile(phases, 0.50), _percentile(phases, 0.75),
		_percentile(phases, 0.90),
	])
	print("")
	print("hang time, seconds   p10 %.3f  p50 %.3f  p90 %.3f" % [
		_percentile(hangs, 0.10), _percentile(hangs, 0.50),
		_percentile(hangs, 0.90),
	])
	var effect_total := 0.0
	for value in effects:
		effect_total += float(value)
	print("effectiveness   mean %.3f   <- REFERENCE_EFFECTIVENESS must match" % (
		effect_total / float(effects.size())))
	print("arm state at the ball")
	for state in ["extended", "descending", "rising"]:
		print("   %-12s %5.1f%%" % [
			state, float(int(states.get(state, 0))) / float(SAMPLES) * 100.0])
	print("timing quality   p90 %.3f  p95 %.3f  p99 %.3f" % [
		_percentile(timings, 0.90), _percentile(timings, 0.95),
		_percentile(timings, 0.99),
	])
	print("Monster Block availability %5.2f%%; apex candidates %5.2f%% of walls" % [
		float(monster_ready) / float(SAMPLES) * 100.0,
		float(monster_candidates) / float(SAMPLES) * 100.0,
	])
	print("")
	print("A mean at 0.62 with real spread either side is the whole objective.")
	print("A mean anywhere else means the wall got stronger or weaker, and any")
	print("sweep read afterwards would be measuring that instead of timing.")
	quit()


## The measured shape of `primary_close`/`assist_close` across live rallies,
## rather than a uniform draw over the same interval.
func _live_close(rng: RandomNumberGenerator) -> float:
	var roll := rng.randf()
	if roll < 0.10:
		return rng.randf_range(0.34, 0.475)
	if roll < 0.25:
		return rng.randf_range(0.475, 0.785)
	if roll < 0.50:
		return rng.randf_range(0.785, 1.0)
	return 1.0


func _percentile(sorted_samples: Array, fraction: float) -> float:
	if sorted_samples.is_empty():
		return 0.0
	var index := clampi(
		int(round(fraction * float(sorted_samples.size() - 1))),
		0, sorted_samples.size() - 1,
	)
	return float(sorted_samples[index])
