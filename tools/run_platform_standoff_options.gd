extends SceneTree

## The M3 decision, reduced as far as measurement can take it.
##
##     godot --headless --path . --script res://tools/run_platform_standoff_options.gd
##
## `BODY_CENTRE_SCOPE.md` located the gap -- `_reached_point` puts the body
## centre on the ball -- and named two ways to source the missing relation
## without taste: derive it from anatomy the body model already carries, or
## author it from reference. Naming two options is not the same as measuring
## them, so this measures them.
##
## Three questions, in the order that decides how much the choice matters:
##
##   1. what anatomy does the simulation already derive, and from what?
##   2. how big is a platform stand-off, per candidate basis, on the real roster?
##   3. how big is it **relative to the tolerance it has to live inside** --
##      because a stand-off well under `_base_reach_meters` barely moves who can
##      reach what, and one comparable to it moves the whole floor defence.

const CoverageCalculator := preload("res://scripts/simulation/coverage_calculator.gd")
const PlayerGenerator := preload("res://scripts/systems/player_generator.gd")

const COURT_WIDTH_METERS: float = 9.0
const COURT_LENGTH_METERS: float = 18.0


func _initialize() -> void:
	var roster := _roster()
	_what_anatomy_exists(roster)
	_candidate_standoffs(roster)
	_what_it_is_worth(roster)
	quit()


## The real generated population, not a fixture. A body proportion has to be
## judged against the roster it will actually be applied to.
func _roster() -> Array:
	var players: Array = []
	for index in range(6):
		var batch: Array[VolleyballPlayer] = PlayerGenerator.generate_roster(
			"Bloc", "Established", 9100 + index,
		)
		for player in batch:
			players.append(player)
	return players


func _stats(values: Array) -> Dictionary:
	if values.is_empty():
		return {"min": 0.0, "p50": 0.0, "max": 0.0, "mean": 0.0}
	var sorted := values.duplicate()
	sorted.sort()
	var total := 0.0
	for value in sorted:
		total += float(value)
	return {
		"min": float(sorted[0]),
		"p50": float(sorted[sorted.size() / 2]),
		"max": float(sorted[sorted.size() - 1]),
		"mean": total / sorted.size(),
	}


## ------------------------------------------------------------------ part one
func _what_anatomy_exists(roster: Array) -> void:
	print("=".repeat(78))
	print("PART 1 -- what the body model already derives, and from what")
	print("=".repeat(78))
	print("  `standing_reach_cm()` is already an authored anatomical derivation:")
	print("")
	print("      height_cm * 1.215 + (wingspan_cm - height_cm) * 0.32")
	print("")
	print("  Two ratios, both authored, both in the simulation rather than the")
	print("  rig. `default_stride_length_m()` is a third -- `height * 0.43`, with")
	print("  its basis stated in the comment. So a body proportion authored with")
	print("  a stated basis is an existing house pattern, not a new kind of thing.")
	print("")
	var heights: Array = []
	var wingspans: Array = []
	var overhead: Array = []
	for player in roster:
		heights.append(float(player.height_cm))
		wingspans.append(float(player.wingspan_cm))
		## What the arms add above standing height -- the one limb quantity the
		## simulation already computes.
		overhead.append(float(player.standing_reach_cm()) - float(player.height_cm))
	print("  %-28s %-9s %-9s %-9s %-9s" % ["quantity, cm", "min", "p50", "max", "mean"])
	for row in [["height_cm", heights], ["wingspan_cm", wingspans],
			["standing_reach - height", overhead]]:
		var stats := _stats(row[1])
		print("  %-28s %-9.1f %-9.1f %-9.1f %-9.1f" % [
			str(row[0]), stats.min, stats.p50, stats.max, stats.mean,
		])
	print("\n  The third row is the arms' overhead extension: %.1f cm at the" % (
		_stats(overhead).p50
	))
	print("  median. That is the vertical projection of the same limbs a platform")
	print("  contact puts in front of the body.")


## ------------------------------------------------------------------ part two
func _candidate_standoffs(roster: Array) -> void:
	print("\n" + "=".repeat(78))
	print("PART 2 -- what a platform stand-off would be, per candidate basis")
	print("=".repeat(78))
	print("  Every candidate is a *projection of an existing quantity*. None")
	print("  introduces a distance; each introduces one ratio, which is the same")
	print("  kind of thing `1.215`, `0.32` and `0.43` already are.\n")
	print("  %-40s %-9s %-9s %-9s" % ["basis", "min m", "p50 m", "max m"])
	var bases := {
		"overhead extension x 1.00": 1.00,
		"overhead extension x 0.75": 0.75,
		"overhead extension x 0.50": 0.50,
		"overhead extension x 0.35": 0.35,
	}
	for label in bases:
		var values: Array = []
		for player in roster:
			var extension := (
				float(player.standing_reach_cm()) - float(player.height_cm)
			) / 100.0
			values.append(extension * float(bases[label]))
		var stats := _stats(values)
		print("  %-40s %-9.3f %-9.3f %-9.3f" % [
			label, stats.min, stats.p50, stats.max,
		])
	var half_wing: Array = []
	for player in roster:
		half_wing.append(float(player.wingspan_cm) / 2.0 / 100.0)
	var half_stats := _stats(half_wing)
	print("  %-40s %-9.3f %-9.3f %-9.3f" % [
		"wingspan / 2 (arm + half shoulder)",
		half_stats.min, half_stats.p50, half_stats.max,
	])
	print("\n  The last row is an upper bound rather than a candidate: it is a")
	print("  fully extended arm plus half a shoulder width, which is a dive, not")
	print("  a platform pass taken in front of the waist.")


## ---------------------------------------------------------------- part three
func _what_it_is_worth(roster: Array) -> void:
	print("\n" + "=".repeat(78))
	print("PART 3 -- how much the choice actually moves")
	print("=".repeat(78))
	var tolerances: Array = []
	for player in roster:
		var arrival: Dictionary = CoverageCalculator.evaluate_arrival(
			player, null, Vector2(0.50, 0.60), 1.20, "reception",
			Vector2(0.50, 0.70), 3.0,
		)
		tolerances.append(float(arrival.get("base_reach_meters", 0.0)))
	var tolerance := _stats(tolerances)
	print("  `_base_reach_meters` (reception): min %.3f, p50 %.3f, max %.3f m\n" % [
		tolerance.min, tolerance.p50, tolerance.max,
	])
	print("  A stand-off moves the body *back* from the ball by that much, and the")
	print("  ball then has to be inside the tolerance from there. So what matters")
	print("  is the stand-off as a share of the tolerance -- how much of the")
	print("  reachable envelope it spends.\n")
	print("  %-40s %-12s %-16s" % ["basis", "p50 m", "share of reach"])
	var overhead_p50 := 0.0
	var extensions: Array = []
	for player in roster:
		extensions.append(
			(float(player.standing_reach_cm()) - float(player.height_cm)) / 100.0
		)
	overhead_p50 = _stats(extensions).p50
	for share in [1.00, 0.75, 0.50, 0.35]:
		var standoff := overhead_p50 * float(share)
		print("  %-40s %-12.3f %-16.1f%%" % [
			"overhead extension x %.2f" % share, standoff,
			standoff / maxf(tolerance.p50, 0.01) * 100.0,
		])
	print("\n  Read the right-hand column. Even the most generous candidate spends")
	print("  under half the reachable envelope, and the conservative one spends")
	print("  about a sixth. A stand-off is not a rebalance of the floor defence --")
	print("  it moves a body back by a fraction of the distance the same body was")
	print("  already allowed to reach.")
	print("")
	print("  What that means for the decision: the *choice between candidates* is")
	print("  worth roughly %.2f m at the extremes, against a tolerance of %.2f m." % [
		overhead_p50 * 0.65, tolerance.p50,
	])
	print("  Getting it wrong by one band is a smaller error than the shortfall")
	print("  term already applies for a misread, which runs to a metre and more.")
	_decided(roster)


## ----------------------------------------------------------------- decision
##
## An attempt that failed, kept because the failure is the finding.
##
## The candidates above each need one ratio. A geometric form appeared to need
## none: the arms are a segment of known length anchored at the shoulder, a ball
## met at a known height fixes the angle, and the horizontal offset is Pythagoras.
## It was implemented and measured, and it returns **zero across the entire
## platform range**, because `standing_reach - height` is not arm length. It is
## the ~0.45 m the arms add *above the head*, and a 0.45 m segment anchored at a
## 1.47 m shoulder cannot reach a ball at the waist at all.
##
## So the geometry needs the shoulder anchor, and the body model does not carry
## one. That is the whole of the remaining decision, and it is one number.
func _decided(roster: Array) -> void:
	print("\n" + "=".repeat(78))
	print("THE DECISION, REDUCED TO ONE NUMBER")
	print("=".repeat(78))
	var spans: Array = []
	for player in roster:
		spans.append((float(player.standing_reach_cm()) - float(player.height_cm)) / 100.0)
	var span := _stats(spans)
	print("  standing_reach - height, p50 %.3f m -- which is *not* arm length." % span.p50)
	print("  It is what raising the arms adds above the head: the arm minus the")
	print("  distance from shoulder to crown, plus the shoulder's own lift.\n")
	print("  A real arm is most of a metre. The quantity the model carries is")
	print("  less than half of one, so any geometry built on it concludes that a")
	print("  voli cannot reach their own waist. Measured, before it was believed.")
	print("")
	print("  What is missing is therefore **the shoulder anchor**: where the")
	print("  shoulder sits as a fraction of standing height. With it:")
	print("")
	print("      arm_length = standing_reach - shoulder_height")
	print("      drop       = shoulder_height - contact_height")
	print("      offset     = sqrt(arm_length^2 - drop^2)")
	print("")
	print("  -- and every contact family follows from the contact height it is")
	print("  already given, with nothing further authored. Net encroachment is the")
	print("  same relation read toward the tape.")
	print("")
	print("  One anthropometric ratio, of the same kind as the `1.215` and `0.32`")
	print("  already inside `standing_reach_cm()` and the `0.43` inside")
	print("  `default_stride_length_m()`. It is a body proportion with a stated")
	print("  basis, not a balance dial, and the tables above bound what it is")
	print("  worth: the whole plausible range of answers spans about 0.29 m")
	print("  against a reach tolerance of 1.23 m.")
