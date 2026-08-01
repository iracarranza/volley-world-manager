extends SceneTree

## Can the engine feel a better player?
##
##   godot --headless --path . --script res://tools/run_role_sensitivity.gd
##
## The readiness question for leaving the rally simulator is not whether every
## outcome sits in its reference band -- it is whether changing a player's
## attributes is visible in the result at all. If it is not, a training system
## has nothing to move, and no amount of tuning elsewhere will change that.
##
## Each role's starters are given the same boost across the four attributes that
## role is built on, and the home win rate is compared against baseline.
##
## **Home win rate, not side-out.** A boost to the home squad helps them whether
## they are serving or receiving, so side-out counts the same effect once with
## each sign and the two nearly cancel. The first version of this measurement
## used side-out and made the engine look markedly less responsive than it is.

const GameManagerModel := preload("res://scripts/managers/game_manager.gd")
const CalibrationModel := preload(
	"res://scripts/simulation/execution_scale_calibration.gd"
)

const BOOST: int = 15
const SAMPLES_PER_SIDE: int = 70

## The attributes each role is built on, taken from the game's own definition in
## `VolleyballPlayer.POSITION_WEIGHTS` rather than a list chosen here.
##
## A hand-picked list is a way to get the answer you expected. The first version
## of this tool boosted four attributes per role and gave the middle blocker
## block_timing, jump_reach, explosiveness and lateral_speed -- none of which
## a blocker's *read* runs through, so a change meant to make reading matter
## could not have registered no matter how large it was.
static func role_attributes(role: String) -> Array:
	return Array(VolleyballPlayer.POSITION_WEIGHTS.get(role, []))


static func home_win_rate(boost_role: String, delta: int, samples: int) -> float:
	var home_wins := 0
	var total := 0
	for serving_home in [true, false]:
		var manager := GameManagerModel.new()
		manager.seed_vertical_slice_data()
		## The fixture leaves every attribute a role does not name at 50, so a
		## boost there would be measured against a squad of clones.
		CalibrationModel.apply_generated_attributes(manager.players, 900000)
		CalibrationModel.apply_generated_attributes(
			manager.opponent_team.players, 905000
		)
		if delta != 0:
			for player_resource in manager.players:
				var player: VolleyballPlayer = player_resource as VolleyballPlayer
				if player == null or str(player.position_role) != boost_role:
					continue
				for attribute in role_attributes(boost_role):
					player.set(str(attribute), clampi(
						int(player.get(str(attribute))) + delta, 1, 99
					))
		manager.match_state.serving_home = serving_home
		for index in range(samples):
			var result: Resource = manager.resolve_active_rally(900000 + index)
			if result == null:
				continue
			total += 1
			if bool(result.home_team_won):
				home_wins += 1
	return float(home_wins) / maxf(float(total), 1.0)


func _initialize() -> void:
	var baseline := home_win_rate("", 0, SAMPLES_PER_SIDE)
	## Binomial standard error, so a delta can be read against the noise it has
	## to clear rather than eyeballed.
	var rallies := SAMPLES_PER_SIDE * 2
	var standard_error := sqrt(baseline * (1.0 - baseline) / float(rallies))
	print("\nbaseline home win rate  %.4f   (n=%d, SE=%.4f)\n" % [
		baseline, rallies, standard_error,
	])
	for role in VolleyballPlayer.POSITION_WEIGHTS:
		for delta in [BOOST, -BOOST]:
			var measured := home_win_rate(str(role), delta, SAMPLES_PER_SIDE)
			var shift := measured - baseline
			print("%-16s %+3d  %.4f  delta %+.4f  (%.1f SE)%s" % [
				role, delta, measured, shift,
				absf(shift) / maxf(standard_error, 0.0001),
				"" if absf(shift) >= standard_error * 2.0 else "   <- noise",
			])
	print("")
	quit()
