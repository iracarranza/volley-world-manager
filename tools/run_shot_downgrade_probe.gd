extends SceneTree

## Where the shot-downgrade threshold sits in the set quality it cuts.
##
## `_compromised_shot_type` turns an intended swing into a roll or a tip below
## `ATTACK_COMPROMISE_SET_QUALITY`, and the legacy branch does the same below a
## literal 0.38. If either sits above the median of the set qualities actually
## delivered, the downgrade is not an exception -- it is the default, and the side
## it applies to essentially never spikes.
##
## That matters far outside shot selection. A side that rolls most balls gives its
## opponent a slow, lofted ball to dig, and every flight-time and dig-rate
## comparison between the two sides inherits it.
##
## Run:
##   godot --headless --path . --script res://tools/run_shot_downgrade_probe.gd

const GameManagerScript := preload("res://scripts/managers/game_manager.gd")
const ExecutionScale := preload(
	"res://scripts/simulation/execution_scale_calibration.gd"
)
const RallyEventScript := preload("res://scripts/models/rally_event.gd")
const SimScript := preload("res://scripts/simulation/rally_simulator.gd")

const RALLIES: int = 150


func _initialize() -> void:
	var manager: Object = GameManagerScript.new()
	manager.seed_vertical_slice_data()
	ExecutionScale.apply_generated_attributes(manager.players, 900006)
	ExecutionScale.apply_generated_attributes(
		manager.opponent_team.players, 900006
	)
	var sets := {"home": [], "opponent": []}
	## The distribution any quick-attack gate would cut. Measured before the
	## threshold is chosen, not after -- FAILURE_MODES.md section 2 is the most
	## common defect in this repository and a pass floor set above the median
	## would make the quick an outcome that never happens.
	var passes := {"home": [], "opponent": []}
	var kinds := {"home": {}, "opponent": {}}
	## `_hit_type` returns "High-ball swing" for any tempo 3 assignment, and 92% of
	## home swings come out as one. Either the tempo call never varies or the name
	## does -- and those want completely different fixes, so count the tempo
	## itself rather than inferring it from the label.
	var tempos := {"home": {}, "opponent": {}}
	## `_hit_type` returns "Quick attack" for a *lane* -- "Front Quick" or
	## "Right Quick" -- and never for a tempo. So tempo variation alone cannot
	## produce a quick, and whether the middle is ever called at all is a separate
	## question from whether the setter ever runs fast.
	var lanes := {"home": {}, "opponent": {}}
	for serving_home in [true, false]:
		manager.match_state.serving_home = serving_home
		for seed_value in range(5000, 5000 + RALLIES):
			var result: Resource = manager.resolve_active_rally(seed_value)
			if result == null:
				continue
			for raw in result.events:
				var event := raw as RallyEvent
				if event == null:
					continue
				var side := str(event.metadata.get("side", ""))
				if event.event_type == RallyEventScript.EventType.RECEPTION \
						and passes.has(side):
					passes[side].append(float(event.quality))
				elif event.event_type == RallyEventScript.EventType.SET \
						and sets.has(side):
					sets[side].append(float(event.quality))
				elif event.event_type == RallyEventScript.EventType.ATTACK \
						and kinds.has(side):
					var kind := str(event.metadata.get("attack_type", "?"))
					kinds[side][kind] = int(kinds[side].get(kind, 0)) + 1
					if event.metadata.has("lane"):
						var lane := str(event.metadata.lane)
						lanes[side][lane] = int(lanes[side].get(lane, 0)) + 1
					if event.metadata.has("tempo"):
						var tempo := int(event.metadata.tempo)
						tempos[side][tempo] = int(tempos[side].get(tempo, 0)) + 1
	manager.free()

	print("Shot downgrade -- %d rallies x 2 serving sides" % RALLIES)
	print("")
	print("compromise threshold %.3f   improvise threshold %.3f   legacy literal 0.380"
		% [SimScript.ATTACK_COMPROMISE_SET_QUALITY,
		   SimScript.ATTACK_IMPROVISE_SET_QUALITY])
	print("")
	print("%-10s %6s %8s %8s %8s %8s %8s   %s" % [
		"set qual", "n", "p10", "p25", "p50", "p75", "p90", "below compromise"])
	for side in ["home", "opponent"]:
		var pool: Array = sets[side]
		if pool.is_empty():
			print("%-10s (none)" % side)
			continue
		pool.sort()
		var below := 0
		for value in pool:
			if float(value) < SimScript.ATTACK_COMPROMISE_SET_QUALITY:
				below += 1
		print("%-10s %6d %8.3f %8.3f %8.3f %8.3f %8.3f   %d (%.0f%%)" % [
			side, pool.size(), _p(pool, 0.10), _p(pool, 0.25), _p(pool, 0.50),
			_p(pool, 0.75), _p(pool, 0.90), below,
			float(below) / float(pool.size()) * 100.0])
	print("")
	print("%-10s %6s %8s %8s %8s %8s %8s" % [
		"pass qual", "n", "p10", "p25", "p50", "p75", "p90"])
	for side in ["home", "opponent"]:
		var pool: Array = passes[side]
		if pool.is_empty():
			print("%-10s (none)" % side)
			continue
		pool.sort()
		print("%-10s %6d %8.3f %8.3f %8.3f %8.3f %8.3f" % [
			side, pool.size(), _p(pool, 0.10), _p(pool, 0.25), _p(pool, 0.50),
			_p(pool, 0.75), _p(pool, 0.90)])
	print("")
	print("attack types actually produced")
	for side in ["home", "opponent"]:
		var keys: Array = kinds[side].keys()
		keys.sort()
		var line := "  %-9s" % side
		for key in keys:
			line += " %s=%d" % [str(key), int(kinds[side][key])]
		print(line)
	print("")
	print("tempo actually called")
	for side in ["home", "opponent"]:
		var keys: Array = tempos[side].keys()
		keys.sort()
		var line := "  %-9s" % side
		var total := 0
		for key in keys:
			total += int(tempos[side][key])
		for key in keys:
			line += " T%d=%d (%.0f%%)" % [
				int(key), int(tempos[side][key]),
				float(tempos[side][key]) / maxf(float(total), 1.0) * 100.0,
			]
		print(line)
	print("")
	print("lane actually assigned")
	for side in ["home", "opponent"]:
		var keys: Array = lanes[side].keys()
		keys.sort()
		var line := "  %-9s" % side
		for key in keys:
			line += " %s=%d" % [str(key), int(lanes[side][key])]
		print(line)
	print("")
	print("A threshold above the median is not an exception branch, it is the")
	print("default path, and the side it applies to essentially never spikes.")
	quit()


func _p(sorted_values: Array, fraction: float) -> float:
	if sorted_values.is_empty():
		return 0.0
	return float(sorted_values[clampi(
		int(round(fraction * float(sorted_values.size() - 1))),
		0, sorted_values.size() - 1)])
