extends SceneTree

## Which of the two downgrades turns a swing into a roll.
##
## Every attack in the game passes through two independent rewrites of its shot
## type, and until now only the second one's output was published:
##
##   1. the set-quality / improvisation gate, which picks the shot from what the
##      set gave the hitter;
##   2. `AttemptJudgmentModel.backs_off`, which rewrites it again from what the
##      run-up gave them.
##
## "The opponent never spikes" was attributed to (1) twice -- once by reading a
## threshold against a distribution, once by re-applying that threshold against
## the resolved set quality -- and neither attempt moved the mix. This separates
## the two so the attribution is measured rather than inferred.
##
## Run:
##   godot --headless --path . --script res://tools/run_downgrade_attribution_probe.gd

const GameManagerScript := preload("res://scripts/managers/game_manager.gd")
const ExecutionScale := preload(
	"res://scripts/simulation/execution_scale_calibration.gd"
)
const RallyEventScript := preload("res://scripts/models/rally_event.gd")

const RALLIES: int = 150

const POWER_TYPES: Array[String] = ["Power swing", "Quick attack", "Spike"]


func _initialize() -> void:
	var manager: Object = GameManagerScript.new()
	manager.seed_vertical_slice_data()
	ExecutionScale.apply_generated_attributes(manager.players, 900006)
	ExecutionScale.apply_generated_attributes(
		manager.opponent_team.players, 900006
	)
	var rows := {"home": [], "opponent": []}
	for serving_home in [true, false]:
		manager.match_state.serving_home = serving_home
		for seed_value in range(5000, 5000 + RALLIES):
			var result: Resource = manager.resolve_active_rally(seed_value)
			if result == null:
				continue
			for raw in result.events:
				var event := raw as RallyEvent
				if event == null \
						or event.event_type != RallyEventScript.EventType.ATTACK:
					continue
				var side := str(event.metadata.get("side", ""))
				if not rows.has(side):
					continue
				rows[side].append({
					"intended": str(event.metadata.get("intended_type", "?")),
					"chosen": str(event.metadata.get(
						"chosen_type", event.metadata.get("attack_type", "?")
					)),
					"final": str(event.metadata.get("attack_type", "?")),
					"backed_off": bool(event.metadata.get("swing_downgraded", false)),
				})
	manager.free()

	print("Downgrade attribution -- %d rallies x 2 serving sides" % RALLIES)
	print("")
	print("%-10s %6s %10s %10s %10s   %s" % [
		"side", "n", "intended", "after gate", "final", "lost to"])
	for side in ["home", "opponent"]:
		var pool: Array = rows[side]
		if pool.is_empty():
			print("%-10s (none)" % side)
			continue
		var power_intended := 0
		var power_after_gate := 0
		var power_final := 0
		var lost_to_gate := 0
		var lost_to_backoff := 0
		for row in pool:
			var was_power: bool = str(row.intended) in POWER_TYPES
			var still_power: bool = str(row.chosen) in POWER_TYPES
			var ends_power: bool = str(row.final) in POWER_TYPES
			if was_power:
				power_intended += 1
			if still_power:
				power_after_gate += 1
			if ends_power:
				power_final += 1
			if was_power and not still_power:
				lost_to_gate += 1
			if still_power and not ends_power:
				lost_to_backoff += 1
		print("%-10s %6d %10d %10d %10d   gate=%d backs_off=%d" % [
			side, pool.size(), power_intended, power_after_gate, power_final,
			lost_to_gate, lost_to_backoff])
	print("")
	print("backs_off rate, over all swings")
	for side in ["home", "opponent"]:
		var pool: Array = rows[side]
		if pool.is_empty():
			continue
		var backed := 0
		for row in pool:
			if bool(row.backed_off):
				backed += 1
		print("  %-9s %d/%d (%.0f%%)" % [
			side, backed, pool.size(),
			float(backed) / float(pool.size()) * 100.0])
	print("")
	print("Whichever column drops first is the one worth fixing. If `intended`")
	print("and `after gate` agree and `final` does not, the set-quality threshold")
	print("was never the cause.")
	quit()
