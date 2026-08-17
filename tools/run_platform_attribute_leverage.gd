extends SceneTree

## Controlled attribute-leverage certification for the currently authoritative
## platform paths.
##
##     godot --headless --path . --script \
##       res://tools/run_platform_attribute_leverage.gd
##
## This is deliberately not a population balance probe. Every row holds the
## ball, body, platform intent, setter and RNG stream fixed, then changes only
## the named attribute bundle. That makes the question causal: does improving a
## voli still improve a feasible contact after physical circumstance is priced?
##
## Reception and floor defence do not yet share one transfer resolver. The
## reception row therefore follows production's two stages (quality, then pass
## result); the dig row follows its two stages (defence terms/contest, then the
## trajectory derived from surviving control). No GOOD/OK/SHANK label authors a
## flight in either fixture.

const RallySimulatorScript := preload(
	"res://scripts/simulation/rally_simulator.gd"
)
const VolleyballPlayerScript := preload(
	"res://scripts/models/volleyball_player.gd"
)
const CoverageCalculator := preload(
	"res://scripts/simulation/coverage_calculator.gd"
)
const SetterCapability := preload(
	"res://scripts/simulation/setter_capability_system.gd"
)

const LEVELS: Array[int] = [20, 40, 60, 80]
const SAMPLE_COUNT: int = 400
const FIRST_SAMPLE_SEED: int = 44000

const START := Vector2(0.23, 0.84)
const CONTACT := Vector2(0.36, 0.73)
const TARGET := Vector2(0.52, 0.64)
const SERVE_ORIGIN := Vector2(0.71, -0.04)


func _initialize() -> void:
	print("=".repeat(86))
	print("PLATFORM ATTRIBUTE LEVERAGE -- fixed circumstance, intent and RNG")
	print("=".repeat(86))
	_reception_bundle_sweep()
	_reception_single_attribute_sweep()
	_dig_bundle_sweep()
	_dig_single_attribute_sweep()
	_impossible_gate()
	quit()


func _voli() -> VolleyballPlayer:
	var voli := VolleyballPlayerScript.new() as VolleyballPlayer
	voli.id = 17
	voli.display_name = "Controlled platform"
	voli.height_cm = 188.0
	voli.wingspan_cm = 194.0
	voli.mass_kg = 82.0
	voli.fatigue = 0.0
	voli.current_form = 0.0
	voli.match_confidence = 0.0
	for property_name in VolleyballPlayer.ABILITY_ATTRIBUTES:
		voli.set(property_name, 50)
	return voli


func _setter() -> VolleyballPlayer:
	var setter := _voli()
	setter.id = 18
	setter.display_name = "Fixed setter"
	setter.tempo_control = 65
	setter.hand_control = 65
	setter.composure = 65
	return setter


func _set_bundle(voli: VolleyballPlayer, names: Array[String], value: int) -> void:
	for property_name in names:
		voli.set(property_name, value)


func _reception_bundle_sweep() -> void:
	print("\nRECEPTION BUNDLE")
	print("  reception + ball_control + composure + reception_balance + reception_stability")
	_print_header()
	for circumstance in ["easy", "difficult"]:
		for level in LEVELS:
			var voli := _voli()
			_set_bundle(voli, [
				"reception", "ball_control", "composure",
				"reception_balance", "reception_stability",
			], level)
			_print_row(circumstance, level, _reception_measure(voli, circumstance))


func _reception_single_attribute_sweep() -> void:
	print("\nRECEPTION DIFFICULT-CONTACT OWNERSHIP (all other ratings 50)")
	print("  attribute                low target  high target  low play  high play")
	for property_name in [
		"reception", "ball_control", "composure",
		"reception_balance", "reception_stability",
	]:
		var low := _voli()
		var high := _voli()
		low.set(property_name, 20)
		high.set(property_name, 80)
		var low_read := _reception_measure(low, "difficult")
		var high_read := _reception_measure(high, "difficult")
		print("  %-24s %8.3f m  %8.3f m    %6.1f%%   %6.1f%%" % [
			property_name,
			float(low_read.target_error), float(high_read.target_error),
			float(low_read.controlled_rate) * 100.0,
			float(high_read.controlled_rate) * 100.0,
		])


func _reception_measure(voli: VolleyballPlayer, circumstance: String) -> Dictionary:
	var simulator := RallySimulatorScript.new() as RallySimulator
	var setter := _setter()
	var arrival := _reception_arrival(circumstance)
	var serve_quality := 0.12 if circumstance == "easy" else 0.68
	var serve_force := 0.10 if circumstance == "easy" else 0.82
	var support_bonus := 0.05 if circumstance == "easy" else 0.0
	var arrival_bonus := clampf(
		float(arrival.reach_margin_meters) * 0.07, -0.16, 0.12
	)
	var quality_total := 0.0
	var target_total := 0.0
	var angle_total := 0.0
	var apex_total := 0.0
	var option_total := 0.0
	var playable := 0
	var class_counts := {}
	for offset in range(SAMPLE_COUNT):
		## Reset for every rating at the same offset. Reception quality consumes
		## the first draw; the pass consumes the same subsequent normal draws.
		simulator.rng.seed = FIRST_SAMPLE_SEED + offset
		var noise: float = simulator.rng.randf_range(-0.14, 0.14)
		var quality := clampf(
			simulator._reception_skill(voli)
			- serve_quality * 0.48
			- CoverageCalculator.reception_body_penalty(
				voli, arrival, serve_quality
			)
			+ arrival_bonus + support_bonus + noise,
			0.0, 1.0,
		)
		quality_total += quality
		var quality_class: String = simulator._quality_phrase(quality)
		class_counts[quality_class] = int(class_counts.get(quality_class, 0)) + 1
		if quality < RallySimulatorScript.RECEPTION_PLAYABLE_FLOOR:
			continue
		playable += 1
		var result: Dictionary = simulator._reception_pass_result(
			voli, START, CONTACT, TARGET, SERVE_ORIGIN, serve_force,
			arrival, quality, 0.51, 0.98, _serve_flight(), setter,
		)
		var destination := Vector2(result.destination)
		target_total += CoverageCalculator.court_distance_meters(destination, TARGET)
		angle_total += _angle_error_degrees(CONTACT, TARGET, destination)
		apex_total += float(result.pass_apex_meters)
		option_total += SetterCapability.tempos_within_capability(
			setter, quality
		).size()
	return {
		"quality": quality_total / SAMPLE_COUNT,
		"target_error": target_total / playable if playable > 0 else NAN,
		"angle_error": angle_total / playable if playable > 0 else NAN,
		"apex": apex_total / playable if playable > 0 else NAN,
		"controlled_rate": float(playable) / SAMPLE_COUNT,
		"options": option_total / playable if playable > 0 else NAN,
		"class": _mode(class_counts),
	}


func _reception_arrival(circumstance: String) -> Dictionary:
	if circumstance == "easy":
		return {
			"reach_margin_meters": 1.30,
			"edge_ratio": 0.24,
			"assigned_reach_meters": 2.4,
			"distance_meters": 0.58,
		}
	return {
		"reach_margin_meters": -0.08,
		"edge_ratio": 1.04,
		"assigned_reach_meters": 2.1,
		"distance_meters": 2.18,
	}


func _serve_flight() -> Dictionary:
	return {
		"start_position": SERVE_ORIGIN,
		"end_position": CONTACT,
		"duration": 0.78,
		"start_time": 0.0,
	}


func _dig_bundle_sweep() -> void:
	print("\nFLOOR-DIG BUNDLE")
	print("  reception + anticipation + dig_control + lateral_speed")
	_print_header()
	for circumstance in ["easy", "difficult"]:
		for level in LEVELS:
			var voli := _voli()
			_set_bundle(voli, [
				"reception", "anticipation", "dig_control", "lateral_speed",
			], level)
			_print_row(circumstance, level, _dig_measure(voli, circumstance))


func _dig_single_attribute_sweep() -> void:
	print("\nDIG DIFFICULT-CONTACT OWNERSHIP (all other ratings 50)")
	print("  attribute                low target  high target  low dig   high dig")
	for property_name in [
		"reception", "anticipation", "dig_control", "lateral_speed",
	]:
		var low := _voli()
		var high := _voli()
		low.set(property_name, 20)
		high.set(property_name, 80)
		var low_read := _dig_measure(low, "difficult")
		var high_read := _dig_measure(high, "difficult")
		print("  %-24s %8.3f m  %8.3f m    %6.1f%%   %6.1f%%" % [
			property_name,
			float(low_read.target_error), float(high_read.target_error),
			float(low_read.controlled_rate) * 100.0,
			float(high_read.controlled_rate) * 100.0,
		])


func _dig_measure(voli: VolleyballPlayer, circumstance: String) -> Dictionary:
	var simulator := RallySimulatorScript.new() as RallySimulator
	var setter := _setter()
	var reach_margin := 0.78 if circumstance == "easy" else 0.04
	var posture_penalty := 0.02 if circumstance == "easy" else 0.32
	var attack_pressure := 0.08 if circumstance == "easy" else 0.34
	var arrival := {
		"reach_margin_meters": reach_margin,
		"edge_ratio": 0.28 if circumstance == "easy" else 0.98,
		"assigned_reach_meters": 2.2,
		"distance_meters": 0.62 if circumstance == "easy" else 2.05,
	}
	var quality_total := 0.0
	var target_total := 0.0
	var angle_total := 0.0
	var apex_total := 0.0
	var option_total := 0.0
	var dug := 0
	for offset in range(SAMPLE_COUNT):
		simulator.rng.seed = FIRST_SAMPLE_SEED + offset
		var terms: Dictionary = simulator._defense_terms(
			voli, reach_margin, 0.0, posture_penalty, 0
		)
		var outcome: Dictionary = simulator._dig_outcome(
			voli, float(terms.quality), attack_pressure
		)
		quality_total += float(outcome.control)
		if not bool(outcome.dug):
			continue
		dug += 1
		var result: Dictionary = simulator._dig_pass_result(
			voli, CONTACT, TARGET, float(outcome.control), arrival,
			"planted" if circumstance == "easy" else "off-axis",
			_attack_flight(), 0.55 if circumstance == "easy" else 2.05,
			setter, 1.0,
		)
		var destination := Vector2(result.destination)
		target_total += CoverageCalculator.court_distance_meters(destination, TARGET)
		angle_total += _angle_error_degrees(CONTACT, TARGET, destination)
		apex_total += float(result.pass_apex_meters)
		option_total += SetterCapability.tempos_within_capability(
			setter, float(outcome.control)
		).size()
	return {
		"quality": quality_total / SAMPLE_COUNT,
		"target_error": target_total / dug if dug > 0 else NAN,
		"angle_error": angle_total / dug if dug > 0 else NAN,
		"apex": apex_total / dug if dug > 0 else NAN,
		"controlled_rate": float(dug) / SAMPLE_COUNT,
		"options": option_total / dug if dug > 0 else NAN,
		## No production dig-pass class exists. Keep that absence legible instead
		## of inventing one for the probe.
		"class": "unowned",
	}


func _attack_flight() -> Dictionary:
	return {
		"start_position": Vector2(0.58, 0.49),
		"end_position": CONTACT,
		"duration": 0.31,
		"start_time": 0.69,
	}


func _impossible_gate() -> void:
	print("\nPHYSICAL GATE")
	print("  A fixed non-arrival produces 0 platform attempts at every rating.")
	print("  This gate is upstream of both transfer helpers; attributes do not")
	print("  manufacture a trajectory for a body that cannot contact the ball.")


func _angle_error_degrees(
	contact: Vector2, desired: Vector2, actual: Vector2
) -> float:
	var intended := desired - contact
	var delivered := actual - contact
	if intended.length_squared() < 0.000001 or delivered.length_squared() < 0.000001:
		return 0.0
	return absf(rad_to_deg(intended.angle_to(delivered)))


func _mode(counts: Dictionary) -> String:
	var winner := "none"
	var count := -1
	for key in counts:
		if int(counts[key]) > count:
			winner = str(key)
			count = int(counts[key])
	return winner


func _print_header() -> void:
	print("  case       rating  survive  quality  target   angle    apex  options  class")


func _print_row(circumstance: String, level: int, row: Dictionary) -> void:
	print("  %-10s %3d   %6.1f%%   %5.3f  %5.3fm  %5.2f°  %5.2fm   %4.2f   %s" % [
		circumstance, level, float(row.controlled_rate) * 100.0,
		float(row.quality), float(row.target_error), float(row.angle_error),
		float(row.apex), float(row.options), str(row["class"]),
	])
