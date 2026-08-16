extends SceneTree

## Does a sampled gate's directional claim actually resolve at the sample size
## it asserts on?
##
##     godot --headless --path . --script res://tools/run_gate_power_audit.gd
##
## Twenty-two test functions in `test_runner.gd` compare two *sampled
## populations* and assert one is larger. Two of them failed this session for
## reasons that were not about the thing they test: Gate 10's tiers came back
## exactly equal at four pairs -- 0.2982 against 0.2982, a tie rather than an
## inversion -- and the identity gate's serve-error clause turned out to be
## converged-negative rather than noisy, which is the opposite diagnosis and
## needed the same instrument to tell apart.
##
## A directional claim is only worth asserting if its margin is large against
## the noise at the size it runs at. This runs each harness at its production
## sample size and at four times it, and prints the margin at both. Three
## readings are possible:
##
##   margin grows with sample, sign stable  -- real effect, possibly underpowered
##   margin shrinks toward zero             -- the gate is asserting noise
##   sign flips or converges negative       -- the claim is false, not weak
##
## No verdicts here, only margins. What counts as enough is a judgement about
## how much a gate is meant to protect.

const RECEPTION_PROGRESSION := preload(
	"res://scripts/simulation/reception_progression_calibration.gd"
)
const RECEPTION_DECISION := preload(
	"res://scripts/simulation/reception_decision_progression_calibration.gd"
)
const SETTER_PROGRESSION := preload(
	"res://scripts/simulation/setter_progression_calibration.gd"
)
const ATTACK_PROGRESSION := preload(
	"res://scripts/simulation/attack_progression_calibration.gd"
)
const BLOCKER_PROGRESSION := preload(
	"res://scripts/simulation/block_progression_calibration.gd"
)
const SETTER_HANDOFF := preload(
	"res://scripts/simulation/setter_handoff_calibration.gd"
)

## name, script, production sample size, start seed, the bucket the gate reads,
## and the two tiers it compares.
const CASES := [
	{
		"gate": "gate 4  reception progression",
		"which": "reception_progression", "n": 2, "seed": 15000,
		"bucket": "by_reader_tier", "high": "elite", "low": "weak",
		"fields": [],
	},
	{
		"gate": "gate 10 decision progression",
		"which": "reception_decision", "n": 8, "seed": 100000,
		"bucket": "by_player_tier", "high": "elite", "low": "developing",
		"fields": ["decision_rate", "contact_success_rate", "contact_choices_mean"],
	},
	{
		"gate": "gate 22 setter progression",
		"which": "setter_progression", "n": 8, "seed": 220000,
		"bucket": "by_setter_tier", "high": "elite", "low": "developing",
		"fields": [],
	},
	## **Bucket left blank on purpose below.** Naming it wrong is how this file
	## silently reported nothing for two of three gates on its first run, so
	## anything not already verified is discovered from the summary instead.
	##
	## `n` and `seed` are the production values read out of `test_runner.gd`, not
	## round numbers. The first extended run guessed 6/300000 and 6/310000 for the
	## two progression gates and so measured a population no gate ever asserts on
	## -- the same defect as guessing the bucket key, one column over.
	{
		"gate": "gate 39 attack progression", "which": "attack_progression",
		"n": 12, "seed": 420000, "bucket": "", "high": "", "low": "", "fields": [],
	},
	{
		"gate": "gate 46 blocker progression", "which": "blocker_progression",
		"n": 8, "seed": 520000, "bucket": "", "high": "", "low": "", "fields": [],
	},
	{
		"gate": "gate 21 setter handoff", "which": "setter_handoff",
		"n": 6, "seed": 210000, "bucket": "", "high": "", "low": "", "fields": [],
	},
]


func _initialize() -> void:
	for entry in CASES:
		var case := Dictionary(entry)
		print("\n=== %s   (production n=%d)" % [str(case.gate), int(case.n)])
		var small := _run(str(case.which), int(case.n), int(case.seed))
		var large := _run(str(case.which), int(case.n) * 4, int(case.seed))
		if small.is_empty() or large.is_empty():
			print("    harness returned nothing -- signature or seed wrong")
			continue
		var bucket := str(case.bucket)
		var high := str(case.high)
		var low := str(case.low)
		if bucket.is_empty():
			var found := _discover_bucket(small)
			if found.is_empty():
				print("    NO TIERED BUCKET -- summary keys are %s" % str(small.keys()))
				continue
			bucket = str(found[0])
			high = str(found[1])
			low = str(found[2])
			print("    discovered bucket %s, comparing %s against %s"
				% [bucket, high, low])
		## **The discovered bucket stays in a local.** `CASES` is a `const`, and a
		## `const` Dictionary in GDScript is read-only *through every reference to
		## it* -- `Dictionary(entry)` wraps, it does not copy -- so writing the
		## discovered key back into `case` aborted the run on its first entry.
		var fields: Array = case.fields
		if fields.is_empty():
			fields = _discover_fields(small, bucket, high)
		## **Say so rather than printing nothing.** The first run of this file
		## reported two of three cases as blank because the bucket keys were
		## guessed wrong, and a blank reads exactly like "no finding".
		if fields.is_empty():
			print("    NO FIELDS -- bucket %s / tier %s not in this summary; keys are %s"
				% [bucket, high, str(small.keys())])
			continue
		for raw_field in fields:
			var field := str(raw_field)
			var a := _margin(small, bucket, high, low, field)
			var b := _margin(large, bucket, high, low, field)
			if is_nan(a) or is_nan(b):
				continue
			## **Absolutes beside the margin.** A margin of zero can mean the two
			## tiers are equal and active, or that the metric is dead for both,
			## and those are completely different findings. The first version of
			## this printed only the difference and could not tell them apart.
			var hi := _value(large, bucket, high, field)
			var lo := _value(large, bucket, low, field)
			print("    %-30s n=%-4d %+8.4f   n=%-4d %+8.4f  [%.4f vs %.4f]  %s" % [
				field, int(case.n), a, int(case.n) * 4, b, hi, lo,
				_reading(a, b) + (" -- BOTH ZERO" if is_zero_approx(hi)
					and is_zero_approx(lo) else "")])
	quit()


func _run(which: String, samples: int, start_seed: int) -> Dictionary:
	match which:
		"reception_progression":
			return RECEPTION_PROGRESSION.run(samples, start_seed)
		"reception_decision":
			return RECEPTION_DECISION.run(samples, start_seed)
		"setter_progression":
			return SETTER_PROGRESSION.run(samples, start_seed)
		"attack_progression":
			return ATTACK_PROGRESSION.run(samples, start_seed)
		"blocker_progression":
			return BLOCKER_PROGRESSION.run(samples, start_seed)
		"setter_handoff":
			return SETTER_HANDOFF.run(samples, start_seed)
	return {}


## Which key holds the tiered comparison, and which two tiers sit at its ends.
##
## Discovered rather than declared, because a wrong guess here is how this file
## reported two blank gates and looked like it had found nothing. Any key whose
## value is a dictionary of dictionaries is a candidate bucket; the two tiers
## taken are the first and last in the harness's own order, which is the order
## the progression gates assert monotonicity along.
func _discover_bucket(summary: Dictionary) -> Array:
	for key in summary:
		if typeof(summary[key]) != TYPE_DICTIONARY:
			continue
		var group: Dictionary = summary[key]
		var tiers: Array = []
		for tier in group:
			if typeof(group[tier]) == TYPE_DICTIONARY \
					and not Dictionary(group[tier]).is_empty():
				tiers.append(str(tier))
		if tiers.size() >= 2:
			return [str(key), tiers[tiers.size() - 1], tiers[0]]
	return []


## Every numeric field both tiers publish, so a harness whose keys are not known
## in advance still reports something rather than nothing.
func _discover_fields(
	summary: Dictionary, bucket: String, tier: String
) -> Array:
	var group: Dictionary = summary.get(bucket, {})
	var values: Dictionary = group.get(tier, {})
	var found: Array = []
	for key in values:
		var value: Variant = values[key]
		if typeof(value) == TYPE_FLOAT or typeof(value) == TYPE_INT:
			found.append(str(key))
	found.sort()
	return found


func _value(
	summary: Dictionary, bucket: String, tier: String, field: String
) -> float:
	return float(Dictionary(
		Dictionary(summary.get(bucket, {})).get(tier, {})
	).get(field, NAN))


func _margin(
	summary: Dictionary, bucket: String, high: String, low: String, field: String
) -> float:
	var group: Dictionary = summary.get(bucket, {})
	var top: Dictionary = group.get(high, {})
	var bottom: Dictionary = group.get(low, {})
	if not top.has(field) or not bottom.has(field):
		return NAN
	return float(top[field]) - float(bottom[field])


## The three readings, named rather than scored.
func _reading(small: float, large: float) -> String:
	if is_zero_approx(small):
		return "TIE at production size"
	if signf(small) != signf(large):
		return "SIGN FLIPS"
	if absf(large) < absf(small) * 0.5:
		return "shrinks with sample"
	if absf(large) > absf(small) * 1.5:
		return "grows with sample"
	return "stable"
