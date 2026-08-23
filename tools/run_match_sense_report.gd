extends SceneTree

## Two questions, one instrument.
##
##   1. Does the opponent make sense? With identical rosters on both sides,
##      every per-side rate should match. Each gap is the engine, because the
##      players are the same players.
##
##   2. Do a player's attributes matter? Spike one side's roster by a known
##      amount and the same rates should move in that side's favour, by an
##      amount that grows with the spike.
##
## They are in one tool on purpose. Measured apart, the first can be satisfied
## by two sides that are equally inert and the second by two sides that are
## equally broken; a roster sweep run against an asymmetric engine reads engine
## bias as roster response, which is exactly the mistake that produced two
## wrong diagnoses in a row. Question 2's rows are only meaningful once question
## 1's gaps are small, and the report says so rather than leaving it implied.
##
## Run:
##   godot --headless --path . --script res://tools/run_match_sense_report.gd

const GameManagerScript := preload("res://scripts/managers/game_manager.gd")
const ExecutionScale := preload(
	"res://scripts/simulation/execution_scale_calibration.gd"
)
const RallyEventScript := preload("res://scripts/models/rally_event.gd")

const PAIRINGS: int = 4
const RALLIES: int = 90

## How much better one side's whole roster is made, in attribute points across
## every rated attribute. Zero is the symmetry case and the baseline every other
## row is read against.
const SPIKES: Array[int] = [0, 6, 12]

## Bands a per-side gap is judged against. Not a pass mark for the sport -- a
## pass mark for *symmetry*: with the same players on both sides these rates
## should differ by roughly nothing, and anything above the second figure is a
## defect rather than noise.
## The tempo a default home play asks for. The opponent's tendency is pinned to
## it for the duration of this sweep so both sides request the same ball; a team
## that genuinely wants a quicker offence is a tactical difference worth having,
## and worth measuring separately from whether the engine is even-handed.
const HOME_PLAYBOOK_TEMPO: int = 3

const GAP_GOOD: float = 0.03
const GAP_SUSPECT: float = 0.08

const RATES: Array[String] = [
	"kill", "attack_error", "stuffed", "dig", "set_quality", "attack_quality",
]


func _initialize() -> void:
	print("Match sense report -- %d pairings x %d rallies x 2 serving assignments"
		% [PAIRINGS, RALLIES])
	print("")
	var baseline := {}
	for spike in SPIKES:
		var totals := _sweep(spike)
		if spike == 0:
			baseline = totals
			_report_symmetry(totals)
			print("")
			print("2. Do attributes matter?  (home roster spiked, opponent left alone)")
			print("%-8s %10s %10s %10s %10s" % [
				"spike", "home_pts", "opp_pts", "home_share", "delta",
			])
		var home_points := float(totals.home_points)
		var opponent_points := float(totals.opponent_points)
		var share := home_points / maxf(home_points + opponent_points, 1.0)
		var baseline_share := float(baseline.home_points) / maxf(
			float(baseline.home_points) + float(baseline.opponent_points), 1.0
		)
		print("%-8s %10d %10d %10.3f %+10.3f" % [
			"+%d" % spike, int(home_points), int(opponent_points), share,
			share - baseline_share,
		])
	print("")
	print("A flat delta column means roster investment does not reach the result.")
	print("Read it only if the gaps above are inside %.2f -- an asymmetric engine"
		% GAP_SUSPECT)
	print("returns its own bias in this column and it looks like a roster response.")
	quit()


## Question 1, printed as a gap per rate rather than two columns to eyeball.
func _report_symmetry(totals: Dictionary) -> void:
	print("1. Does the opponent make sense?  (identical rosters -- every gap is the engine)")
	print("%-16s %10s %10s %10s   %s" % ["rate", "home", "opponent", "gap", "verdict"])
	var worst := 0.0
	for rate in RATES:
		var home_value := _rate(totals, "home", rate)
		var opponent_value := _rate(totals, "opponent", rate)
		var gap := absf(home_value - opponent_value)
		worst = maxf(worst, gap)
		var verdict := "ok"
		if gap > GAP_SUSPECT:
			verdict = "DEFECT"
		elif gap > GAP_GOOD:
			verdict = "suspect"
		print("%-16s %10.3f %10.3f %10.3f   %s" % [
			rate, home_value, opponent_value, gap, verdict,
		])
	print("")
	print("worst gap %.3f -- symmetric at <= %.2f" % [worst, GAP_GOOD])


func _rate(totals: Dictionary, side: String, rate: String) -> float:
	var side_totals: Dictionary = totals[side]
	var attempts := maxf(float(side_totals.attacks), 1.0)
	match rate:
		"kill":
			return float(side_totals.kills) / attempts
		"attack_error":
			return float(side_totals.errors) / attempts
		"stuffed":
			return float(side_totals.stuffed) / attempts
		"dig":
			return float(side_totals.digs) / maxf(float(side_totals.dig_attempts), 1.0)
		"set_quality":
			return float(side_totals.set_quality) / maxf(float(side_totals.sets), 1.0)
		"attack_quality":
			return float(side_totals.attack_quality) / attempts
	return 0.0


func _sweep(spike: int) -> Dictionary:
	var totals := {
		"home": _empty_side(), "opponent": _empty_side(),
		"home_points": 0, "opponent_points": 0,
	}
	for pairing_index in range(PAIRINGS):
		var roster_seed := 900006 + pairing_index * 1000
		for serving_home in [true, false]:
			var manager: Object = GameManagerScript.new()
			manager.seed_vertical_slice_data()
			ExecutionScale.apply_generated_attributes(manager.players, roster_seed)
			ExecutionScale.apply_generated_attributes(
				manager.opponent_team.players, roster_seed
			)
			if spike > 0:
				_spike_roster(manager.players, spike)
			## Identical rosters are not identical teams. The vertical-slice
			## fixture gives its opponent a tempo tendency of 1 -- a first-tempo
			## offence -- while the home playbook requests 3, and tempo drives
			## the set's arc so steeply that the two sides were being handed
			## different amounts of approach time by tactics alone. A gate that
			## does not control for that reads a coaching choice as an engine
			## defect, which is exactly the confound it exists to prevent.
			manager.opponent_team.tendencies["tempo"] = HOME_PLAYBOOK_TEMPO
			manager.match_state.serving_home = serving_home
			for seed_value in range(5000, 5000 + RALLIES):
				var result: Resource = manager.resolve_active_rally(seed_value)
				if result != null:
					_collect(result, totals)
			manager.free()
	return totals


func _empty_side() -> Dictionary:
	return {
		"attacks": 0, "kills": 0, "errors": 0, "stuffed": 0,
		"dig_attempts": 0, "digs": 0, "sets": 0,
		"set_quality": 0.0, "attack_quality": 0.0,
	}


## Every rated attribute, so this is roster *investment* rather than a change
## to one skill that some paths read and others do not.
func _spike_roster(players: Array, amount: int) -> void:
	for raw_player in players:
		var player: VolleyballPlayer = raw_player as VolleyballPlayer
		if player == null:
			continue
		for attribute in VolleyballPlayer.ABILITY_ATTRIBUTES:
			player.set(attribute, clampi(
				int(player.get(attribute)) + amount, 1, 99
			))


func _collect(result: Resource, totals: Dictionary) -> void:
	for raw_event in result.events:
		var event: Resource = raw_event
		var side := str(event.metadata.get("side", ""))
		if side != "home" and side != "opponent":
			continue
		var side_totals: Dictionary = totals[side]
		match event.event_type:
			RallyEventScript.EventType.SET:
				side_totals.sets += 1
				side_totals.set_quality += float(event.quality)
			RallyEventScript.EventType.ATTACK:
				side_totals.attacks += 1
				side_totals.attack_quality += float(event.quality)
			RallyEventScript.EventType.DIG:
				side_totals.dig_attempts += 1
				if event.success:
					side_totals.digs += 1
		totals[side] = side_totals
	## Who won the point comes from `result.home_team_won`, which the resolver
	## sets at every terminal, rather than from mapping outcome names by hand. An
	## ace and a serve error belong to whichever side was serving, so a name-based
	## mapping silently reverses half of them -- and this sweep deliberately runs
	## both serving assignments.
	if bool(result.home_team_won):
		totals["home_points"] += 1
	else:
		totals["opponent_points"] += 1
	## The per-side attack tallies stay outcome-named, because those names say
	## which side swung and the flag does not.
	var home_totals: Dictionary = totals["home"]
	var opponent_totals: Dictionary = totals["opponent"]
	match str(result.terminal_outcome):
		"kill", "kill_default":
			home_totals.kills += 1
		"attack_error":
			home_totals.errors += 1
		"blocked":
			home_totals.stuffed += 1
		"opponent_kill":
			opponent_totals.kills += 1
		"opponent_attack_error":
			opponent_totals.errors += 1
		"counter_block":
			opponent_totals.stuffed += 1
	totals["home"] = home_totals
	totals["opponent"] = opponent_totals
