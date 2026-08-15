extends SceneTree

## Does a match actually reach the stages the fatigue model defines?
##
##     godot --headless --path . --script res://tools/run_fatigue_stage_probe.gd
##
## `FatigueModel` splits tiredness into three stages and puts the error channel
## behind the third one. That is only a model if a real match gets there. A
## `SPENT_ONSET` of 0.68 against a match that tops out at 0.40 is a stage that
## exists in a constant and never in a rally -- §0's exact shape, and the reason
## this probe exists before the thresholds are trusted rather than after.
##
## So the question is not what the curve looks like. It is **what fatigue a voli
## actually carries at the end of a set, a match, and a five-setter**, and how
## much of that time is spent in each stage.

const GameManagerScript := preload("res://scripts/managers/game_manager.gd")
const FatigueModelScript := preload("res://scripts/simulation/fatigue_model.gd")

## Rallies in a set and sets in a match, approximately. A set to 25 with rally
## scoring takes somewhere near 45 rallies; five of those is a long match.
const RALLIES_PER_SET: int = 45
const SETS: int = 5
const FIRST_SEED: int = 21000


func _initialize() -> void:
	var manager: Object = GameManagerScript.new()
	manager.seed_vertical_slice_data()
	var seed_value := FIRST_SEED
	print("%-8s %8s %8s %8s   %s" % [
		"after", "p10", "p50", "p90", "stage at the median",
	])
	for set_number in range(1, SETS + 1):
		for _rally in range(RALLIES_PER_SET):
			## **`record_rally`, not just `resolve_active_rally`.** Resolution is
			## pure -- it reads the squad and returns a result and writes nothing
			## back -- and every consequence of a rally, fatigue included, is
			## applied by `record_rally`. The first version of this probe resolved
			## 225 rallies and reported a fatigue of 0.000 across the board, which
			## looked exactly like a dead accumulator and was a dead probe.
			var result: Resource = manager.resolve_active_rally(seed_value)
			if result != null:
				manager.record_rally(result)
			seed_value += 1
		var fatigues := _fatigues(manager)
		if fatigues.is_empty():
			continue
		print("%-8s %8.3f %8.3f %8.3f   %s" % [
			"set %d" % set_number,
			_at(fatigues, 0.10), _at(fatigues, 0.50), _at(fatigues, 0.90),
			FatigueModelScript.stage_name(_at(fatigues, 0.50)),
		])
	print("")

	## And what that fatigue is worth, in the units the model spends it in.
	var final_fatigues := _fatigues(manager)
	var worst := _at(final_fatigues, 0.90)
	var median := _at(final_fatigues, 0.50)
	print("at the end of five sets")
	for label in [["median voli", median], ["most-worked voli", worst]]:
		var fatigue := float(label[1])
		print("  %-18s fatigue %.3f  stage %-9s mental x%.3f  physical x%.3f  error +%.3f" % [
			str(label[0]), fatigue,
			FatigueModelScript.stage_name(fatigue),
			FatigueModelScript.broad_scale(fatigue),
			FatigueModelScript.broad_scale(fatigue)
				* FatigueModelScript.range_scale(fatigue),
			FatigueModelScript.forced_error_bias(fatigue)
				+ FatigueModelScript.unforced_error_bias(fatigue),
		])
	print("")
	print("stage onsets are %.2f (laboured) and %.2f (spent)" % [
		FatigueModelScript.LABOURED_ONSET, FatigueModelScript.SPENT_ONSET,
	])
	print("")

	## **The claim the action-based accrual rests on.** If a middle blocker who
	## jumps on most balls finishes a match no more tired than a libero who never
	## leaves the floor, then itemising the work bought nothing and the old
	## per-rally figure was right. Split by role, it is checkable in one line.
	print("who actually tired, by role")
	var by_role := {}
	for player in manager.players:
		var role := str(player.position_role)
		if not by_role.has(role):
			by_role[role] = []
		by_role[role].append(float(player.fatigue))
	for role in by_role:
		var values: Array = by_role[role]
		var total := 0.0
		for value in values:
			total += float(value)
		print("  %-18s %d voli   mean fatigue %.3f" % [
			role, values.size(), total / float(maxi(values.size(), 1)),
		])
	print("")

	## And whether the regional curve reaches the same quantity. Landavol is 1.00
	## by definition, so the comparison is against it.
	print("regional fatigue_resistance, and what it is worth over this match")
	for region in ["Pāwa Hitō", "Lo-ong Ralī", "Landavol", "Spëddigh"]:
		var resistance := VolleyballRegions.fatigue_resistance(region)
		var scaled := median * resistance
		print("  %-14s x%.2f  ->  median voli would sit at %.3f (%s)" % [
			region, resistance, scaled, FatigueModelScript.stage_name(scaled),
		])
	print("A stage the ninetieth percentile never reaches is a stage that does")
	print("not exist, whatever the constant says.")
	manager.free()
	quit()


func _fatigues(manager: Object) -> Array[float]:
	var values: Array[float] = []
	for player in manager.players:
		values.append(float(player.fatigue))
	values.sort()
	return values


func _at(sorted_values: Array, quantile: float) -> float:
	if sorted_values.is_empty():
		return 0.0
	return float(sorted_values[clampi(
		int(floor(quantile * float(sorted_values.size() - 1))),
		0, sorted_values.size() - 1,
	)])
