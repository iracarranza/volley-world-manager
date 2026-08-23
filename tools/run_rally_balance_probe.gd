extends SceneTree

## Is this a match, or one play run over and over?
##
##     godot --headless --path . --script res://tools/run_rally_balance_probe.gd
##
## The re-fit's instrument. `docs/BACKLOG.md` has named the same limiter since
## "What the rally simulator work is for" -- *the model plays one rally over and
## over* -- and every attempt to fix it has been measured with a different
## private probe, so no two attempts have been comparable. This is one reading
## with every number that decides whether the fit is done, and the numbers it
## reports are the ones the sport has real values for.
##
## **The targets.** A men's professional side kills about 45-50% of its swings;
## this engine has run at 79-91%, and the difference is not scoring, it is that
## nothing is ever dug, so no rally reaches a second exchange, so the opponent
## never gets to attack. Those three facts are one fact and this prints them
## together for that reason.
##
##     kill rate            0.45 - 0.50
##     dig rate             0.35 - 0.55 of swings the defence reaches
##     swing balance        near 1.0, home swings against opponent swings
##     contacts per rally   above 6, which is two full exchanges
##
## Both serving sides are run, because half of this engine's historical
## asymmetries were one side of the net being modelled and the other not.

const GameManagerScript := preload("res://scripts/managers/game_manager.gd")
const RallyEventScript := preload("res://scripts/models/rally_event.gd")

const RALLIES: int = 350
const FIRST_SEED: int = 20000


func _initialize() -> void:
	var tally := {
		"rallies": 0, "contacts": 0,
		"home_swings": 0, "opponent_swings": 0,
		"home_kills": 0, "opponent_kills": 0,
		"digs_attempted": 0, "digs_up": 0,
		"coverage_attempted": 0, "coverage_up": 0, "coverage_quality": 0.0,
		"serves": 0, "aces": 0, "serve_errors": 0,
		"receptions": 0, "reception_quality": 0.0,
		"dig_quality": 0.0, "digs_counted": 0,
		"attack_quality": 0.0, "attacks_counted": 0,
		"home_attack_quality": 0.0, "opponent_attack_quality": 0.0,
		"home_digs": 0, "home_digs_up": 0,
		"opponent_digs": 0, "opponent_digs_up": 0,
		"blocks": 0, "stuffs": 0,
	}
	for serving_home in [true, false]:
		var manager: Object = GameManagerScript.new()
		manager.seed_vertical_slice_data()
		manager.match_state.serving_home = serving_home
		for seed_value in range(FIRST_SEED, FIRST_SEED + RALLIES):
			var result: Resource = manager.resolve_active_rally(seed_value)
			if result != null:
				_collect(result, tally)
		manager.free()

	var home_swings := maxf(float(tally.home_swings), 1.0)
	var opponent_swings := maxf(float(tally.opponent_swings), 1.0)
	var swings := home_swings + opponent_swings
	print("=== %d rallies, both serving sides ===" % int(tally.rallies))
	print("")
	_line("contacts per rally", float(tally.contacts) / maxf(float(tally.rallies), 1.0), "above 6.0")
	print("")
	_line("kill rate, both sides",
		float(tally.home_kills + tally.opponent_kills) / swings, "0.45 - 0.50")
	_line("  home", float(tally.home_kills) / home_swings, "")
	_line("  opponent", float(tally.opponent_kills) / opponent_swings, "")
	_line("swing balance", opponent_swings / home_swings, "near 1.00")
	print("    home %d swings, opponent %d" % [
		int(tally.home_swings), int(tally.opponent_swings),
	])
	print("")
	print("    %d floor digs attempted" % int(tally.digs_attempted))
	_line("dig rate", float(tally.digs_up) / maxf(float(tally.digs_attempted), 1.0),
		"0.35 - 0.55")
	_line("dig quality, mean",
		float(tally.dig_quality) / maxf(float(tally.digs_counted), 1.0), "")
	## Its own two lines, never folded back into the dig figures above.
	_line("attack coverage rate",
		float(tally.coverage_up) / maxf(float(tally.coverage_attempted), 1.0), "")
	print("    %d coverage contacts attempted" % int(tally.coverage_attempted))
	_line("attack coverage quality, mean",
		float(tally.coverage_quality) / maxf(float(tally.coverage_attempted), 1.0), "")
	_line("attack quality, mean",
		float(tally.attack_quality) / maxf(float(tally.attacks_counted), 1.0), "")
	## Split by side, because half this engine's history is one side of the net
	## being modelled fully and the other not, and a mean over both hides it.
	_line("  home swing quality",
		float(tally.home_attack_quality) / home_swings, "")
	_line("  opponent swing quality",
		float(tally.opponent_attack_quality) / opponent_swings, "")
	_line("  home dig rate", float(tally.home_digs_up)
		/ maxf(float(tally.home_digs), 1.0), "")
	_line("  opponent dig rate", float(tally.opponent_digs_up)
		/ maxf(float(tally.opponent_digs), 1.0), "")
	_line("block touch rate", float(tally.blocks) / swings, "")
	_line("stuff rate", float(tally.stuffs) / swings, "0.08 - 0.14")
	print("")
	_line("ace rate", float(tally.aces) / maxf(float(tally.serves), 1.0), "0.05 - 0.09")
	_line("serve error rate",
		float(tally.serve_errors) / maxf(float(tally.serves), 1.0), "0.12 - 0.20")
	_line("reception quality, mean",
		float(tally.reception_quality) / maxf(float(tally.receptions), 1.0), "")
	quit()


func _line(label: String, value: float, target: String) -> void:
	print("  %-26s %7.3f   %s" % [label, value, target])


func _collect(result: Resource, tally: Dictionary) -> void:
	tally.rallies = int(tally.rallies) + 1
	for raw_event in result.events:
		var event: Resource = raw_event
		var kind: String = event.type_name()
		if kind in ["Set Decision", "Point"]:
			continue
		tally.contacts = int(tally.contacts) + 1
		var home := str(event.metadata.get("side", "")) == "home"
		match kind:
			"Serve":
				tally.serves = int(tally.serves) + 1
				if not bool(event.success):
					tally.serve_errors = int(tally.serve_errors) + 1
			"Reception":
				tally.receptions = int(tally.receptions) + 1
				tally.reception_quality = float(tally.reception_quality) \
					+ float(event.quality)
			"Attack":
				tally.attacks_counted = int(tally.attacks_counted) + 1
				tally.attack_quality = float(tally.attack_quality) \
					+ float(event.quality)
				if home:
					tally.home_swings = int(tally.home_swings) + 1
					tally.home_attack_quality = float(tally.home_attack_quality) \
						+ float(event.quality)
				else:
					tally.opponent_swings = int(tally.opponent_swings) + 1
					tally.opponent_attack_quality = \
						float(tally.opponent_attack_quality) + float(event.quality)
			"Block":
				tally.blocks = int(tally.blocks) + 1
				if str(event.metadata.get("outcome", "")) == "stuff":
					tally.stuffs = int(tally.stuffs) + 1
			"Attack Coverage":
				## **Kept out of the dig numbers, which is the whole point.** A
				## coverer picks the rebound off their own block from a metre
				## away and comes up with it essentially always -- 38 of 38 over
				## these same 700 rallies -- so averaging it into the dig rate
				## lifted a floor-dig rate of 0.445 to a reported 0.493 and made
				## the 0.35-0.55 target look comfortably met from the middle
				## rather than from the bottom third.
				tally.coverage_attempted = int(tally.coverage_attempted) + 1
				tally.coverage_quality = float(tally.coverage_quality) \
					+ float(event.quality)
				if bool(event.success):
					tally.coverage_up = int(tally.coverage_up) + 1
			"Dig":
				## Every dig the defence got to play, and whether it came up.
				## `success` is the contest's own verdict, which is the thing a
				## rally continues on.
				tally.digs_attempted = int(tally.digs_attempted) + 1
				tally.digs_counted = int(tally.digs_counted) + 1
				tally.dig_quality = float(tally.dig_quality) + float(event.quality)
				if bool(event.success):
					tally.digs_up = int(tally.digs_up) + 1
				if home:
					tally.home_digs = int(tally.home_digs) + 1
					if bool(event.success):
						tally.home_digs_up = int(tally.home_digs_up) + 1
				else:
					tally.opponent_digs = int(tally.opponent_digs) + 1
					if bool(event.success):
						tally.opponent_digs_up = int(tally.opponent_digs_up) + 1
	## A kill is a swing that ended the rally by hitting the floor, read off the
	## rally's own outcome vocabulary rather than off the attack event's
	## `success` -- which is a quality threshold and says nothing about whether
	## the ball landed.
	match str(result.terminal_outcome):
		"kill":
			tally.home_kills = int(tally.home_kills) + 1
		"opponent_kill":
			tally.opponent_kills = int(tally.opponent_kills) + 1
		"ace":
			tally.aces = int(tally.aces) + 1
