extends SceneTree

## Which bodies does playback actually get to draw?
##
##     godot --headless --path . --script res://tools/run_contact_posture_probe.gd
##
## Every floor contact carries two independent classifications, and the actor
## draws a different body for each combination:
##
##   `contact_posture`  -- planted / reaching / off-axis / moving
##                         *how the ball was met*
##   `contact_recovery` -- platform / knee / fall / blown_away
##                         *what it cost to meet it*
##
## Reported from use: "I only get to see platform or blown back." Both of those
## are recoveries, so the question is really two questions -- whether the four
## recoveries are reachable, and whether the four postures are. A branch that
## never fires is indistinguishable from one that does not exist, and this
## repository has now found six of them by printing a distribution.
##
## The terms each threshold cuts are printed beside the rates, because §0 is
## specifically about a bound sitting outside the distribution it acts on and the
## rate alone cannot tell that from a genuinely rare event.

const GameManagerScript := preload("res://scripts/managers/game_manager.gd")
const RallyEventScript := preload("res://scripts/models/rally_event.gd")

const RALLIES: int = 400
const FIRST_SEED: int = 61000

const POSTURES := ["planted", "reaching", "off-axis", "moving"]
const RECOVERIES := ["platform", "knee", "fall", "blown_away"]
## Mirrors `RallySimulator.POSTURE_EXPECTED_CONTROL`. Duplicated deliberately and
## said so: a probe that imported the constant could not detect the constant
## drifting away from the population it describes, which is the whole reason to
## look.
const EXPECTED_CONTROL := {
	"planted": 0.54, "moving": 0.59, "reaching": 0.08, "off-axis": 0.61,
}


func _initialize() -> void:
	var by_contact := {
		"reception": _bucket(), "defense": _bucket(),
	}
	for serving_home in [true, false]:
		var manager: Object = GameManagerScript.new()
		manager.seed_vertical_slice_data()
		manager.match_state.serving_home = serving_home
		for seed_value in range(FIRST_SEED, FIRST_SEED + RALLIES):
			var result: Resource = manager.resolve_active_rally(seed_value)
			if result == null:
				continue
			for raw_event in result.events:
				var event: Resource = raw_event
				var kind := ""
				match int(event.event_type):
					RallyEventScript.EventType.RECEPTION:
						kind = "reception"
					RallyEventScript.EventType.DIG:
						kind = "defense"
					_:
						continue
				_collect(by_contact[kind], event.metadata)
		manager.free()

	for kind in ["reception", "defense"]:
		var bucket: Dictionary = by_contact[kind]
		var total := maxf(float(bucket.n), 1.0)
		print("=== %s (%d contacts) ===" % [kind, int(bucket.n)])
		print("")
		print("  posture")
		for posture in POSTURES:
			print("    %-12s %6d  %5.1f%%" % [
				posture, int(bucket.postures.get(posture, 0)),
				float(bucket.postures.get(posture, 0)) / total * 100.0,
			])
		print("  recovery")
		for recovery in RECOVERIES:
			print("    %-12s %6d  %5.1f%%" % [
				recovery, int(bucket.recoveries.get(recovery, 0)),
				float(bucket.recoveries.get(recovery, 0)) / total * 100.0,
			])
		print("")
		## The terms the thresholds cut, so a dead branch can be told from a rare
		## one without a second run.
		for term in bucket.terms.keys():
			var samples: Array = bucket.terms[term]
			if samples.is_empty():
				continue
			samples.sort()
			print("    %-24s p10 %7.3f  p50 %7.3f  p90 %7.3f  max %7.3f" % [
				term, _at(samples, 0.10), _at(samples, 0.50),
				_at(samples, 0.90), samples[samples.size() - 1],
			])
		print("")
	quit()


func _bucket() -> Dictionary:
	return {"n": 0, "postures": {}, "recoveries": {}, "terms": {}}


func _at(sorted_samples: Array, quantile: float) -> float:
	var index := clampi(
		int(floor(quantile * float(sorted_samples.size() - 1))),
		0, sorted_samples.size() - 1,
	)
	return float(sorted_samples[index])


func _note(bucket: Dictionary, term: String, value: float) -> void:
	if not bucket.terms.has(term):
		bucket.terms[term] = []
	(bucket.terms[term] as Array).append(value)


func _collect(bucket: Dictionary, metadata: Dictionary) -> void:
	bucket.n = int(bucket.n) + 1
	var posture := str(metadata.get("contact_posture", ""))
	var recovery := str(metadata.get("contact_recovery", ""))
	bucket.postures[posture] = int(bucket.postures.get(posture, 0)) + 1
	bucket.recoveries[recovery] = int(bucket.recoveries.get(recovery, 0)) + 1
	_note(bucket, "movement_alignment",
		float(metadata.get("movement_alignment", 0.0)))
	_note(bucket, "body_alignment", float(metadata.get("body_alignment", 0.0)))
	var arrival: Dictionary = metadata.get("arrival", {})
	_note(bucket, "edge_ratio", float(arrival.get("edge_ratio", 0.0)))
	_note(bucket, "reach_margin_meters",
		float(arrival.get("reach_margin_meters", 0.0)))
	## **The five terms the margin is made of**, which `CoverageCalculator`
	## publishes precisely so a total can be attributed. A margin of 3.7 m is a
	## fact about one of these and there is no way to tell which from the sum.
	for term in [
		"ball_time_seconds", "base_reach_meters", "movement_speed_mps",
		"acceleration_factor", "travel_distance_meters",
		"physical_reach_meters", "distance_meters", "reaction_delay",
	]:
		_note(bucket, term, float(arrival.get(term, 0.0)))
	_note(bucket, "incoming_force", float(metadata.get("incoming_force", 0.0)))
	_note(bucket, "incoming_speed_mps",
		float(metadata.get("incoming_speed_mps", 0.0)))
	_note(bucket, "movement_duration",
		float(metadata.get("movement_duration", 0.0)))
	## The number every recovery band actually cuts, reconstructed the way
	## `_contact_recovery_state` computes it. The bands are stated as a share of
	## the posture's own norm, so the raw control figure cannot be compared
	## against them and the rate alone cannot say whether a band is unreachable.
	var expected := float(EXPECTED_CONTROL.get(posture, 0.54))
	var control := float(metadata.get("contact_control", 0.0))
	_note(bucket, "shortfall_vs_posture_norm",
		1.0 - control / maxf(expected, 0.001))
	_note(bucket, "contact_control", control)
