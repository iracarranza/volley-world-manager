extends SceneTree

## Prints the attack and block execution scales without resolving a rally.
##
##   godot --headless --path . --script res://tools/run_execution_scale.gd
##
## Runs in well under a second. Use it to set the capability weights, the error
## threshold and the block margins; use `RallyReadinessReport` afterwards to
## confirm what the choice did to the sport.

const CalibrationModel := preload(
	"res://scripts/simulation/execution_scale_calibration.gd"
)
const RallySimulatorModel := preload("res://scripts/simulation/rally_simulator.gd")
const GameManagerModel := preload("res://scripts/managers/game_manager.gd")


func _row(label: String, summary: Dictionary) -> void:
	if int(summary.get("count", 0)) == 0:
		print("%-26s (none)" % label)
		return
	print("%-26s min=%.3f p25=%.3f med=%.3f p75=%.3f max=%.3f  spread=%.3f" % [
		label, float(summary["min"]), float(summary["p25"]),
		float(summary["median"]), float(summary["p75"]), float(summary["max"]),
		float(summary["spread"]),
	])


func _initialize() -> void:
	var manager := GameManagerModel.new()
	manager.seed_vertical_slice_data()
	var fixture: Array[VolleyballPlayer] = manager.players
	var population := CalibrationModel.generated_population(8)

	print("\n=== RATINGS AS THE RESOLVER SEES THEM (generated population, n=%d) ===" % population.size())
	print("raw = attribute/100. effective = after fatigue and form, which is what")
	print("every weight in the engine is actually multiplied against.\n")
	var spread: Dictionary = CalibrationModel.rating_spread(population)
	for attribute in spread:
		var row: Dictionary = spread[attribute]
		if row.has("raw"):
			_row("%s raw" % attribute, row["raw"])
		_row("%s effective" % attribute, row["effective"])

	print("\n=== SAME RATINGS, HAND-AUTHORED FIXTURE (n=%d) ===" % fixture.size())
	print("Every attribute a player's role does not name sits at the default 50.")
	print("The readiness sweeps now re-attribute this fixture before measuring.\n")
	var fixture_spread: Dictionary = CalibrationModel.rating_spread(fixture)
	for attribute in fixture_spread:
		var row: Dictionary = fixture_spread[attribute]
		if row.has("raw"):
			_row("%s raw" % attribute, row["raw"])
		_row("%s effective" % attribute, row["effective"])

	print("\n=== ATTACK SCALE BY SITUATION (generated population) ===")
	print("Before block pressure and before any overreach penalty.\n")
	var attack_rows: Dictionary = CalibrationModel.attack_scale(population)
	for situation in attack_rows:
		_row(situation, attack_rows[situation])

	print("\n=== BLOCK SCALE BY CLOSE (solo wall) ===\n")
	var block_rows: Dictionary = CalibrationModel.block_scale(population)
	for close in block_rows:
		_row(close, block_rows[close])

	print("\n=== ERROR THRESHOLD (%.2f) ===" % RallySimulatorModel.ATTACK_ERROR_THRESHOLD)
	var errors: Dictionary = CalibrationModel.error_shares(attack_rows)
	for situation in errors:
		var row: Dictionary = errors[situation]
		print("%-12s median above=%s  p25 above=%s  worst above=%s" % [
			situation, str(bool(row["median_above_threshold"])),
			str(bool(row["p25_above_threshold"])),
			str(bool(row["min_above_threshold"])),
		])

	print("\n=== CONTEST SHARES: typical swing vs sealed block ===")
	print("margins stuff=%+.2f touch=%+.2f funnel=%+.2f\n" % [
		RallySimulatorModel.BLOCK_STUFF_MARGIN,
		RallySimulatorModel.BLOCK_TOUCH_MARGIN,
		RallySimulatorModel.BLOCK_FUNNEL_MARGIN,
	])
	## Both arrays come from the calibration model, never from a copy of the
	## formula written out here. A copy is what made three different block
	## scales print byte-identical contest shares.
	var shares: Dictionary = CalibrationModel.contest_shares(
		CalibrationModel.attack_values(population, "typical"),
		CalibrationModel.block_values(population, 1.0),
	)
	for key in ["stuff", "touch", "funnel", "miss", "touched"]:
		print("%-10s %.3f" % [key, float(shares.get(key, 0.0))])

	print("\n=== DIG SHARE: typical swing vs a defender at each arrival ===")
	print("attacker advantage %+.2f\n" % RallySimulatorModel.DIG_ATTACKER_ADVANTAGE)
	var typical_swing: Array = CalibrationModel.attack_values(population, "typical")
	for margin in [0.20, 0.0, -0.20, -0.40]:
		var dig_values: Array = CalibrationModel.defense_values(population, margin)
		print("margin %+.2f  dig med=%.3f  dug=%.3f" % [
			margin,
			float(CalibrationModel.summarise(dig_values).get("median", 0.0)),
			CalibrationModel.dig_share(typical_swing, dig_values),
		])
	print("")
	quit()
