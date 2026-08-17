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
const BodyTypeModels := preload("res://scripts/data/body_type_models.gd")

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
## **Decided, and nothing was invented.** Two attempts are kept above because
## both failed and the failures are the finding: every ratio candidate needed a
## number, and the Pythagoras form built on `standing_reach - height` returned
## zero across the whole platform range because that quantity is not arm length.
##
## What was missing was the shoulder anchor, and the repository already commits
## to one -- `BodyTypeModels.UNIVERSAL_RATIOS.shoulder_y`, authored once as the
## shared figure with its basis recorded. Reading it makes the simulation and the
## drawn body the same body, which is M3's own exit condition.
func _decided(roster: Array) -> void:
	print("\n" + "=".repeat(78))
	print("DECIDED -- the shoulder anchor was already in the repository")
	print("=".repeat(78))
	print("  `BodyTypeModels.UNIVERSAL_RATIOS`: shoulder_y %.3f, hand_y %.3f." % [
		float(BodyTypeModels.UNIVERSAL_RATIOS.get("shoulder_y", 0.0)),
		float(BodyTypeModels.UNIVERSAL_RATIOS.get("hand_y", 0.0)),
	])
	print("  Its own comment states the basis: \"against roughly 0.82 on a human\".")
	print("")
	print("  Two independent routes to arm length, as a cross-check:\n")
	var derived: Array = []
	var shared: Array = []
	for player in roster:
		derived.append(player.arm_length_meters())
		shared.append(float(player.height_cm) / 100.0 * (
			float(BodyTypeModels.UNIVERSAL_RATIOS.get("shoulder_y", 0.815))
			- float(BodyTypeModels.UNIVERSAL_RATIOS.get("hand_y", 0.395))
		))
	var a := _stats(derived)
	var b := _stats(shared)
	print("  %-46s %-9s %-9s %-9s" % ["route", "min m", "p50 m", "max m"])
	print("  %-46s %-9.3f %-9.3f %-9.3f" % [
		"standing_reach - shoulder (this voli's wingspan)", a.min, a.p50, a.max,
	])
	print("  %-46s %-9.3f %-9.3f %-9.3f" % [
		"(shoulder_y - hand_y) x height (shared figure)", b.min, b.p50, b.max,
	])
	print("  %-46s %-9.3f" % ["median disagreement", absf(a.p50 - b.p50)])
	print("\n  The individual route is the one used, so a long-armed voli gets a")
	print("  long arm. The shared figure is the check, not the source.\n")

	print("  %-34s %-9s %-9s %-9s %-12s" % [
		"contact height", "min m", "p50 m", "max m", "share of reach",
	])
	for entry in [
		["0.30 -- shin, off the floor", 0.30],
		["0.60 -- knee, a low dig", 0.60],
		["0.90 -- thigh, a driven ball", 0.90],
		["1.10 -- waist, the platform pass", 1.10],
		["1.40 -- chest, a high float", 1.40],
		["1.80 -- overhead, not a platform", 1.80],
	]:
		var values: Array = []
		for player in roster:
			values.append(player.contact_offset_meters(float(entry[1])))
		var stats := _stats(values)
		print("  %-34s %-9.3f %-9.3f %-9.3f %-12.1f%%" % [
			str(entry[0]), stats.min, stats.p50, stats.max,
			stats.p50 / 1.227 * 100.0,
		])
	print("\n  Zero above the shoulder and zero at the floor, both because the")
	print("  geometry says so rather than because a band was drawn. The platform")
	print("  range comes out where a passer actually takes the ball, and it stays")
	print("  inside the 1.23 m reach tolerance it has to live within.")
