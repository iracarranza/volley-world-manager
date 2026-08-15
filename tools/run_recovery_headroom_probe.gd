extends SceneTree

## Is there room for accommodation to matter?
##
##     godot --headless --path . --script res://tools/run_recovery_headroom_probe.gd
##
## `ACCOMMODATIONS_AND_CARE.md` §6 proposes four rows, three of which move
## fatigue: the table buys a recovery *rate*, the dorms set a recovery
## *ceiling*, care decides how much of a match survives the week. All three are
## multipliers on a quantity nobody has looked at.
##
## If a squad starts every week at nearly zero fatigue, then a ±15% multiplier on
## weekly recovery moves a number that was already spent -- a knob that cannot
## reach its own range, silently, which is the failure this repository has a
## document about. The proposal names ±15% before anything measured what it is
## ±15% *of*.
##
## So: what does a voli's fatigue actually look like across a season?
func _initialize() -> void:
	var career: Object = load("res://scripts/managers/career_manager.gd").new()
	var game: Object = load("res://scripts/managers/game_manager.gd").new()
	get_root().add_child(game)
	get_root().add_child(career)
	career.game_manager_override = game
	var error: String = career.create_career(
		"Headroom", "Probe VC", "Landavol", "Club", "Balanced"
	)
	if not error.is_empty():
		print("could not start a career: %s" % error)
		quit()
		return

	var samples: Array[float] = []
	var peak := 0.0
	var weeks_with_any := 0
	for _week in range(30):
		for fixture in career.career.fixtures:
			if not bool(fixture.completed) \
					and int(fixture.week) <= int(career.career.absolute_week):
				career.simulate_fixture(int(fixture.id))
				break
		career.advance_week()
		var week_peak := 0.0
		for player in game.players:
			var value := float(player.fatigue)
			samples.append(value)
			week_peak = maxf(week_peak, value)
		peak = maxf(peak, week_peak)
		if week_peak > 0.01:
			weeks_with_any += 1

	samples.sort()
	print("%d weekly readings across 30 weeks\n" % samples.size())
	for share in [0.10, 0.50, 0.75, 0.90, 0.99]:
		print("  p%-3d  %.3f" % [
			int(share * 100.0),
			float(samples[clampi(int(float(samples.size()) * share), 0, samples.size() - 1)]),
		])
	print("  peak  %.3f" % peak)
	print("\n%d of 30 weeks had anybody carrying fatigue at all." % weeks_with_any)
	var Fatigue := load("res://scripts/simulation/fatigue_model.gd")
	print("LABOURED starts at %.2f and SPENT at %.2f."
		% [Fatigue.LABOURED_ONSET, Fatigue.SPENT_ONSET])
	print("A multiplier on recovery can only matter where there is fatigue to")
	print("recover from. If these readings sit near zero, the table, the dorms")
	print("and the care row are three dials on a number that is already spent.")
	quit()
