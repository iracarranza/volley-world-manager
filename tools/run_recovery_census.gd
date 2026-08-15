extends SceneTree

## How often each recovery state actually happens, and what it costs.
##
## The design note on the bands says a state that fires on a third of contacts is
## wallpaper and one that fires on none is a pose nobody sees. That is a
## measurement, and nothing was measuring it -- the bands were tuned against four
## subjects standing in a preview, which cannot tell you a frequency.
##
## It also caught the scale error the composites shipped with: weights that summed
## to less than one moved every voli toward the floor, so an ordinary defender
## went down on every contact and the "knee" row read 100%.
##
## Run:
##   godot --headless --path . --script res://tools/run_recovery_census.gd

const GameManagerScript := preload("res://scripts/managers/game_manager.gd")
const ExecutionScale := preload(
	"res://scripts/simulation/execution_scale_calibration.gd"
)
const RallyEventScript := preload("res://scripts/models/rally_event.gd")

const PAIRINGS: int = 4
const RALLIES: int = 90
const HOME_PLAYBOOK_TEMPO: int = 3
const STATES: Array[String] = ["platform", "knee", "fall", "blown_away"]


func _initialize() -> void:
	var counts := {"reception": {}, "dig": {}}
	var controls := {}
	var forcing := {}
	var posturing := {}
	var inputs := {}
	var crosstab := {}
	var by_posture := {}
	var penalised := 0
	var contested := 0
	var penalty_total := 0.0
	for pairing_index in range(PAIRINGS):
		var roster_seed := 900006 + pairing_index * 1000
		for serving_home in [true, false]:
			var manager: Object = GameManagerScript.new()
			manager.seed_vertical_slice_data()
			ExecutionScale.apply_generated_attributes(manager.players, roster_seed)
			ExecutionScale.apply_generated_attributes(
				manager.opponent_team.players, roster_seed
			)
			manager.opponent_team.tendencies["tempo"] = HOME_PLAYBOOK_TEMPO
			manager.match_state.serving_home = serving_home
			for seed_value in range(5000, 5000 + RALLIES):
				var result: Resource = manager.resolve_active_rally(seed_value)
				if result == null:
					continue
				for event in result.events:
					var kind := int(event.event_type)
					var label := ""
					if kind == RallyEventScript.EventType.RECEPTION:
						label = "reception"
					elif kind == RallyEventScript.EventType.DIG:
						label = "dig"
					else:
						continue
					var state := str(
						event.metadata.get("contact_recovery", "platform")
					)
					var bucket: Dictionary = counts[label]
					bucket[state] = int(bucket.get(state, 0)) + 1
					var posture := str(
						event.metadata.get("contact_posture", "planted")
					)
					var postures: Dictionary = posturing.get(label, {})
					postures[posture] = int(postures.get(posture, 0)) + 1
					posturing[label] = postures
					## Two bands need a posture *and* a poor contact, so the
					## marginals cannot tell you whether a band is empty because
					## its posture is rare or because the two never coincide.
					var cell := "%s|%s" % [posture, state]
					crosstab[cell] = int(crosstab.get(cell, 0)) + 1
					## Control per posture, because the bands ask for a poor
					## contact *and* a posture, and the cross-tab showed those two
					## are near-duplicates: a reaching contact is almost always
					## poor and an off-axis one almost never is.
					var per_posture: Array = by_posture.get(posture, [])
					per_posture.append(
						float(event.metadata.get("contact_control", 0.5))
					)
					by_posture[posture] = per_posture
					for key in [
						"body_alignment", "reach_margin_meters", "movement_alignment"
					]:
						if event.metadata.has(key):
							var pool: Array = inputs.get(key, [])
							pool.append(float(event.metadata[key]))
							inputs[key] = pool
					var arrival: Dictionary = event.metadata.get("arrival", {})
					if arrival.has("edge_ratio"):
						var edges: Array = inputs.get("edge_ratio", [])
						edges.append(float(arrival["edge_ratio"]))
						inputs["edge_ratio"] = edges
					if event.metadata.has("contact_control"):
						var samples: Array = controls.get(label, [])
						samples.append(float(event.metadata["contact_control"]))
						controls[label] = samples
						var forces: Array = forcing.get(label, [])
						forces.append(float(event.metadata["incoming_speed_mps"]))
						forcing[label] = forces
					var terms: Dictionary = event.metadata.get("dig_terms", {})
					var recovery := float(terms.get("recovery", 1.0))
					if recovery < 0.999:
						penalised += 1
						penalty_total += recovery
					if int(event.metadata.get("recovering_count", 0)) > 0:
						contested += 1
			manager.free()

	print("Recovery census -- %d pairings x %d rallies, both service sides"
		% [PAIRINGS, RALLIES])
	print("")
	print("%-12s %10s %9s %9s %12s %8s" % [
		"contact", "platform", "knee", "fall", "blown_away", "n"
	])
	for label in ["reception", "dig"]:
		var bucket: Dictionary = counts[label]
		var total := 0
		for state in bucket:
			total += int(bucket[state])
		if total == 0:
			print("%-12s (none sampled)" % label)
			continue
		var row := "%-12s" % label
		for state in STATES:
			row += " %9.1f%%" % (float(bucket.get(state, 0)) / total * 100.0)
		print(row + " %8d" % total)
	print("")
	print("contacts made with somebody on the floor: %d" % contested)
	if penalised > 0:
		print("...of which the contact was made *by* them: %d, mean multiplier %.3f"
			% [penalised, penalty_total / penalised])
	else:
		print("...of which the contact was made *by* them: 0 -- the claim search")
		print("   excluded them instead, which is the stronger form of the cost")
	print("")
	print("%-12s %8s %8s %8s %8s %8s   %8s" % [
		"control", "p05", "p25", "p50", "p75", "p95", "speed p50/p95"
	])
	for label in ["reception", "dig"]:
		var samples: Array = controls.get(label, [])
		if samples.is_empty():
			print("%-12s (not reported)" % label)
			continue
		samples.sort()
		var forces: Array = forcing.get(label, [])
		forces.sort()
		print("%-12s %8.3f %8.3f %8.3f %8.3f %8.3f   %5.1f / %.1f m/s" % [
			label,
			_percentile(samples, 0.05), _percentile(samples, 0.25),
			_percentile(samples, 0.50), _percentile(samples, 0.75),
			_percentile(samples, 0.95),
			_percentile(forces, 0.50), _percentile(forces, 0.95),
		])
	print("")
	## Two of the four bands are gated on posture as well as control, so a band
	## that never fires may be a posture distribution rather than a threshold.
	print("%-12s %10s %9s %9s %11s" % [
		"posture", "planted", "moving", "reaching", "off-axis"
	])
	for label in ["reception", "dig"]:
		var postures: Dictionary = posturing.get(label, {})
		var total := 0
		for key in postures:
			total += int(postures[key])
		if total == 0:
			continue
		var row := "%-12s" % label
		for key in ["planted", "moving", "reaching", "off-axis"]:
			row += " %9.1f%%" % (float(postures.get(key, 0)) / total * 100.0)
		print(row)
	print("")
	## The posture classifier has four branches and two of them looked dead. These
	## are the three figures it switches on, pooled over both contact types, so a
	## dead branch can be told apart from a threshold sitting outside its own
	## distribution.
	print("%-20s %8s %8s %8s %8s %8s" % [
		"posture input", "p05", "p25", "p50", "p75", "p95"
	])
	for key in [
		"body_alignment", "movement_alignment", "reach_margin_meters", "edge_ratio"
	]:
		var pool: Array = inputs.get(key, [])
		if pool.is_empty():
			print("%-20s (not reported)" % key)
			continue
		pool.sort()
		print("%-20s %8.3f %8.3f %8.3f %8.3f %8.3f" % [
			key,
			_percentile(pool, 0.05), _percentile(pool, 0.25),
			_percentile(pool, 0.50), _percentile(pool, 0.75),
			_percentile(pool, 0.95),
		])
	print("")
	print("%-12s %10s %9s %9s %11s" % [
		"posture x", "platform", "knee", "fall", "blown_away"
	])
	for posture in ["planted", "moving", "reaching", "off-axis"]:
		var row := "%-12s" % posture
		var total := 0
		for state in STATES:
			total += int(crosstab.get("%s|%s" % [posture, state], 0))
		if total == 0:
			continue
		for state in STATES:
			row += " %9d" % int(crosstab.get("%s|%s" % [posture, state], 0))
		print(row)
	print("")
	print("%-12s %8s %8s %8s %8s   %6s" % [
		"control by", "p10", "p25", "p50", "p75", "n"
	])
	for posture in ["planted", "moving", "reaching", "off-axis"]:
		var pool: Array = by_posture.get(posture, [])
		if pool.is_empty():
			continue
		pool.sort()
		print("%-12s %8.3f %8.3f %8.3f %8.3f   %6d" % [
			posture,
			_percentile(pool, 0.10), _percentile(pool, 0.25),
			_percentile(pool, 0.50), _percentile(pool, 0.75), pool.size(),
		])
	print("")
	print("A state above ~25% of its contact type is wallpaper; one at 0% is")
	print("unreachable. `platform` is expected to dominate both rows.")
	quit()


## The bands are thresholds on `contact_control`, so the only way to know whether
## a band is reachable is to know where that distribution actually sits.
func _percentile(sorted_samples: Array, fraction: float) -> float:
	if sorted_samples.is_empty():
		return 0.0
	var index := clampi(
		int(round(fraction * float(sorted_samples.size() - 1))),
		0, sorted_samples.size() - 1,
	)
	return float(sorted_samples[index])
