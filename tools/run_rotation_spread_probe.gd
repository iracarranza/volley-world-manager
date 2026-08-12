extends SceneTree

## How much does a lineup actually vary across its own six rotations?
##
##     godot --headless --path . --script res://tools/run_rotation_spread_probe.gd
##
## `RotationStrength` claims that a six is six teams and that the gap between the
## best and worst of them is worth printing. Both halves of that are testable and
## neither is obvious:
##
## 1. **Is the spread big enough to matter?** If reordering the six moves a
##    rotation's block by two points, the whole idea is a rounding error dressed
##    as a tactic, and no threshold set on it could ever mean anything.
## 2. **Does the *order* move it, or only the roster?** This is the one that
##    decides whether the feature is a decision or a readout. If every ordering
##    of the same six produces the same spread, then spread is a fact about who
##    you signed and there is nothing to think about at lock-in.
##
## Measured against the seeded lineup and against random reorderings of the same
## six, which isolates order from personnel: same players, different slots.
const Strength := preload("res://scripts/data/rotation_strength.gd")
const Profiles := preload("res://scripts/systems/attribute_profile_system.gd")


func _initialize() -> void:
	var manager: Object = load("res://scripts/managers/game_manager.gd").new()
	get_root().add_child(manager)
	manager.seed_vertical_slice_data()

	var players_by_id := {}
	for player in manager.players:
		players_by_id[int(player.id)] = player

	var seeded: Dictionary = Strength.across(manager.rotations, players_by_id)
	print("The seeded lineup, rotation by rotation\n")
	var axes: Array = Strength.ROTATION_AXES
	var header := "%-20s" % "axis"
	for number in range(1, 7):
		header += "%8s" % ("R%d" % number)
	header += "%9s%9s%7s" % ["mean", "spread", "worst"]
	print(header)
	for axis in axes:
		var line := "%-20s" % axis
		for number in range(1, 7):
			var row: Dictionary = Dictionary(seeded["rotations"]).get(number, {})
			line += "%8.1f" % float(row.get(axis, 0.0))
		line += "%9.1f%9.1f%7d" % [
			float(Dictionary(seeded["mean"]).get(axis, 0.0)),
			float(Dictionary(seeded["spread"]).get(axis, 0.0)),
			int(Dictionary(seeded["weakest"]).get(axis, -1)),
		]
		print(line)
	print("\nExposure (mean spread across axes): %.1f" % Strength.exposure(seeded))

	## **Same six, different order.** Personnel held fixed and the slot
	## assignment shuffled, which is the only way to tell a decision from a
	## readout.
	var ids: Array[int] = []
	for slot in range(1, 7):
		ids.append(int(manager.rotations[1].player_at_slot(slot)))
	var rng := RandomNumberGenerator.new()
	rng.seed = 5150
	var exposures: Array[float] = []
	var best := INF
	var worst := -INF
	for attempt in range(400):
		var order := ids.duplicate()
		for index in range(order.size() - 1, 0, -1):
			var swap := rng.randi_range(0, index)
			var held: int = order[index]
			order[index] = order[swap]
			order[swap] = held
		var rotations := {}
		for number in range(1, 7):
			var lineup: Resource = load("res://scripts/models/rotation_lineup.gd").new()
			lineup.rotation_number = number
			## Rotation n is the base order cycled by n, which is what rotating
			## actually is: everybody moves one slot clockwise when you win a
			## point on serve receive.
			for slot in range(1, 7):
				lineup.slot_player_ids[slot] = order[posmod(slot - number, 6)]
			rotations[number] = lineup
		var value: float = Strength.exposure(Strength.across(rotations, players_by_id))
		exposures.append(value)
		best = minf(best, value)
		worst = maxf(worst, value)

	exposures.sort()
	print("\n400 orderings of the SAME six volis:")
	print("  best  %.1f" % best)
	print("  p25   %.1f" % exposures[int(float(exposures.size()) * 0.25)])
	print("  median%.1f" % exposures[exposures.size() / 2])
	print("  p75   %.1f" % exposures[int(float(exposures.size()) * 0.75)])
	print("  worst %.1f" % worst)
	print("\nA manager who reorders the same six can move exposure by %.1f points."
		% (worst - best))
	print("If that number is small, spread is a fact about the roster and not a")
	print("decision at lock-in, and the panel should say so rather than imply a")
	print("choice that does not exist.")
	## **Is the metric flat, or is the roster?**
	##
	## The seeded six is one club's core from one region and they are alike. A
	## spread that never moves could mean the model cannot see a difference, or
	## that it is looking at a squad which does not have one -- and those want
	## opposite responses. So: a deliberately lopsided six, built from a
	## generated roster by taking the extremes of each axis.
	var Generator := load("res://scripts/systems/player_generator.gd")
	var pool: Array = Generator.generate_roster("Landavol", "established", 424242)
	var by_axis := {}
	for player in pool:
		players_by_id[int(player.id)] = player
	var ranked: Array = pool.duplicate()
	var physical := {}
	for player in pool:
		physical[int(player.id)] = float(Profiles.summary_profile(player)["Physical"])
	ranked.sort_custom(
		func(a, b): return float(physical[int(a.id)]) > float(physical[int(b.id)])
	)
	## Three of the tallest and three of the shortest, which is the crudest
	## lopsided six there is and exactly the shape a real squad takes when it has
	## two specialist middles and a small libero.
	var lopsided: Array[int] = []
	for index in range(3):
		lopsided.append(int(ranked[index].id))
	for index in range(3):
		lopsided.append(int(ranked[ranked.size() - 1 - index].id))
	var extreme := {}
	for number in range(1, 7):
		var lineup: Resource = load("res://scripts/models/rotation_lineup.gd").new()
		lineup.rotation_number = number
		for slot in range(1, 7):
			lineup.slot_player_ids[slot] = lopsided[posmod(slot - number, 6)]
		extreme[number] = lineup
	var lopsided_summary: Dictionary = Strength.across(extreme, players_by_id)
	print("\nA deliberately lopsided six -- three tallest, three shortest:")
	print("%-20s%9s%9s%7s" % ["axis", "mean", "spread", "worst"])
	for axis in axes:
		print("%-20s%9.1f%9.1f%7d" % [
			axis,
			float(Dictionary(lopsided_summary["mean"]).get(axis, 0.0)),
			float(Dictionary(lopsided_summary["spread"]).get(axis, 0.0)),
			int(Dictionary(lopsided_summary["weakest"]).get(axis, -1)),
		])
	print("  exposure %.1f, against the seeded six's %.1f."
		% [Strength.exposure(lopsided_summary), Strength.exposure(seeded)])
	manager.free()
	quit()
