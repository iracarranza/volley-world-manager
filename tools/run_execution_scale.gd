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
	print("This is the roster every calibration sweep actually runs on.\n")
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
	var simulator := RallySimulatorModel.new()
	var typical: Dictionary = CalibrationModel.SITUATIONS["typical"]
	var attack_values: Array[float] = []
	var block_values: Array[float] = []
	for player in population:
		attack_values.append(simulator._attack_execution(
			player, float(typical["set_quality"]), float(typical["approach_fit"]),
			float(typical["arrival_margin"]), 0.0, 0.0,
		))
		block_values.append(clampf(
			simulator._block_contact_skill(player, 1.0) * 0.78, 0.05, 0.98
		))
	var shares: Dictionary = CalibrationModel.contest_shares(
		attack_values, block_values
	)
	for key in ["stuff", "touch", "funnel", "miss", "touched"]:
		print("%-10s %.3f" % [key, float(shares.get(key, 0.0))])
	print("")
	quit()
