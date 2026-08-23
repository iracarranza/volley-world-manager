extends SceneTree

## Does a manager's block-hands call actually reach the court, and does
## `tactical_discipline` move a voli *toward the call* rather than toward one
## fixed action?
##
##     godot --headless --path . --script res://tools/run_block_instruction_probe.gd
##
## **Part A is the acceptance gate and it is bidirectional on purpose.** An
## attribute that pushes the same way under both calls is temperament wearing an
## instruction's name. The gate is:
##
##     call = soft   discipline up  -> soft attempts up
##     call = kill   discipline up  -> kill attempts up
##
## Both, or the wiring is wrong. `_block_hands_intent` is driven directly with a
## synthetic blocker and a fixed contest, so the only thing varying is the call
## and one attribute -- no rally, no physics, no sampling of anything else.
## `_identity_roll` keys off `rally_seed`, so sweeping seeds turns a
## deterministic decision into a rate.
##
## **Part B is the same decision in situ**, over isolated rallies, reporting what
## the home side's hands actually did and what the scoreboard did. The scoreboard
## is a regression check, never a target.

const GameManagerScript := preload("res://scripts/managers/game_manager.gd")
const RallySimulatorScript := preload("res://scripts/simulation/rally_simulator.gd")
const RallyEventScript := preload("res://scripts/models/rally_event.gd")

const FIRST_SEED: int = 41000
const SEED_COUNT: int = 400

## Enough seeds that a rate is a rate. `_identity_roll` is a hash, not an RNG, so
## this is a deterministic sweep rather than a sample.
const GATE_SEEDS: int = 600
const CALLS: Array[String] = ["", "soft block", "kill block"]
const DISCIPLINES: Array[int] = [10, 50, 90]

## A contest the blocker is losing by enough to notice, and a close they did not
## finish -- the state in which the voli's own read says "soft" often enough for
## a call to have something to disagree with. Held fixed across the whole sweep.
## **Two fixtures, because one cannot test both directions.** The gate asks
## whether discipline moves a voli *toward the call*, and a voli only has
## somewhere to move when they disagree with it. The first version of this probe
## used one fixture whose own verdict was "soft" at every discipline, so a soft
## call agreed with them and the soft direction was untestable by construction.
##
## `beaten` loses the contest and has not finished closing, so the voli's own
## read is soft and a KILL call is the disagreement.
## `winning` is on the ball with a positive margin, so `deficit <= 0` makes their
## own read kill and a SOFT call is the disagreement.
const GATE_FIXTURES := {
	"beaten": {"margin": -0.10, "close": 0.55},
	"winning": {"margin": 0.10, "close": 1.0},
}


func _initialize() -> void:
	_part_a()
	_part_b()
	quit()


func _part_a() -> void:
	print("=".repeat(78))
	print("PART A -- the gate: does discipline move toward the CALL?")
	print("=".repeat(78))
	print("  fixed blocker, fixed contest, %d seeds per cell" % GATE_SEEDS)
	print("  the voli's own read is soft under `beaten`, kill under `winning`\n")
	for fixture_name in GATE_FIXTURES:
		var fixture: Dictionary = GATE_FIXTURES[fixture_name]
		print("  fixture %s  (margin %+.2f, close %.2f)"
			% [fixture_name, float(fixture.margin), float(fixture.close)])
		print("      %-12s %-6s %-8s %-8s %-8s"
			% ["call", "disc", "soft", "kill", "followed"])
		for call in CALLS:
			for discipline in DISCIPLINES:
				var soft := 0
				var kill := 0
				var followed := 0
				for seed_value in range(GATE_SEEDS):
					var simulator: Object = RallySimulatorScript.new()
					simulator.rally_seed = seed_value
					var verdict: Dictionary = simulator._block_hands_intent(
						_gate_blocker(discipline), float(fixture.margin),
						float(fixture.close), call
					)
					match str(verdict.hands):
						"soft": soft += 1
						"kill": kill += 1
					if bool(verdict.followed):
						followed += 1
				print("      %-12s %-6d %-8.4f %-8.4f %-8.4f" % [
					"(none)" if call.is_empty() else call, discipline,
					float(soft) / float(GATE_SEEDS),
					float(kill) / float(GATE_SEEDS),
					float(followed) / float(GATE_SEEDS),
				])
			print("")


## Everything pinned except discipline. Aggression and the recognition pair sit
## at 50 so the voli's own verdict is the same in every row and the only thing
## that can move the result is adherence.
func _gate_blocker(discipline: int) -> VolleyballPlayer:
	var blocker := VolleyballPlayer.new()
	blocker.decision_making = 50
	blocker.composure = 50
	blocker.aggression = 50
	blocker.tactical_discipline = discipline
	return blocker


func _part_b() -> void:
	print("\n" + "=".repeat(78))
	print("PART B -- in situ, %d isolated rallies per side" % SEED_COUNT)
	print("=".repeat(78))
	var counts := {
		"rallies": 0, "home_points": 0,
		"blocks": 0, "soft": 0, "kill": 0, "neutral": 0,
		"called": 0, "followed": 0, "deviated": 0,
	}
	var by_side := {
		"home": {"blocks": 0, "soft": 0},
		"opponent": {"blocks": 0, "soft": 0},
	}
	var outcomes := {}
	for serving_home in [false, true]:
		for seed_value in range(FIRST_SEED, FIRST_SEED + SEED_COUNT):
			var manager: Object = GameManagerScript.new()
			manager.seed_vertical_slice_data()
			manager.match_state.serving_home = serving_home
			var rally: Resource = manager.resolve_active_rally(seed_value)
			counts["rallies"] = int(counts.rallies) + 1
			if rally != null:
				for event in rally.events:
					if int(event.event_type) != RallyEventScript.EventType.BLOCK:
						continue
					_read_block(event, counts, by_side)
				var outcome := str(rally.terminal_outcome)
				outcomes[outcome] = int(outcomes.get(outcome, 0)) + 1
				if bool(rally.home_team_won):
					counts["home_points"] = int(counts.home_points) + 1
			manager.free()

	print("  rallies %d, blocks %d" % [int(counts.rallies), int(counts.blocks)])
	print("      soft %d, kill %d, neutral %d, soft rate %.4f" % [
		int(counts.soft), int(counts.kill), int(counts.neutral),
		float(counts.soft) / maxf(float(counts.blocks), 1.0),
	])
	for side in ["home", "opponent"]:
		var cell: Dictionary = by_side[side]
		print("      %-9s blocks %-5d soft %-5d rate %.4f" % [
			side, int(cell.blocks), int(cell.soft),
			float(cell.soft) / maxf(float(cell.blocks), 1.0),
		])
	## Zero called blocks before the wiring lands is the finding, not a bug in
	## the probe. The vertical slice ships no drawn tactic sheet either, so this
	## stays at zero until somebody writes an instruction on the clipboard.
	print("\n  INSTRUCTION")
	print("      blocks with a hands call %d, followed %d, deviated %d" % [
		int(counts.called), int(counts.followed), int(counts.deviated),
	])
	if int(counts.called) > 0:
		print("      follow rate %.4f"
			% (float(counts.followed) / float(counts.called)))

	print("\n  RALLY OUTCOMES  (regression check, not a target)")
	print("      home points %d of %d (%.4f)" % [
		int(counts.home_points), int(counts.rallies),
		float(counts.home_points) / maxf(float(counts.rallies), 1.0),
	])
	var names: Array = outcomes.keys()
	names.sort()
	for name in names:
		print("      %-28s %-5d %.4f" % [
			name, int(outcomes[name]),
			float(outcomes[name]) / maxf(float(counts.rallies), 1.0),
		])


func _read_block(
	event: Resource, counts: Dictionary, by_side: Dictionary
) -> void:
	var metadata: Dictionary = event.metadata
	counts["blocks"] = int(counts.blocks) + 1
	var hands := str(metadata.get("block_hands", "neutral"))
	match hands:
		"soft": counts["soft"] = int(counts.soft) + 1
		"kill": counts["kill"] = int(counts.kill) + 1
		_: counts["neutral"] = int(counts.neutral) + 1
	var side := str(metadata.get("side", "home"))
	var cell: Dictionary = by_side.get(side, by_side["home"])
	cell["blocks"] = int(cell.blocks) + 1
	if hands == "soft":
		cell["soft"] = int(cell.soft) + 1
	var call := str(metadata.get("block_hands_call", ""))
	if call.is_empty():
		return
	counts["called"] = int(counts.called) + 1
	if bool(metadata.get("block_hands_followed", false)):
		counts["followed"] = int(counts.followed) + 1
	else:
		counts["deviated"] = int(counts.deviated) + 1
