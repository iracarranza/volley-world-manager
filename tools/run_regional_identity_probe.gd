extends SceneTree

## Is each region's identity actually distinguishable in a rally?
##
##     godot --headless --path . --script res://tools/run_regional_identity_probe.gd
##
## `REGIONAL_PRINCIPLES` gives eight regions seven axes each, and the design asks
## that every one of them be meaningful -- Landavol despite owning no extreme,
## Taktikã despite being the least physical. Whether that holds is not a question
## about the table. It is a question about what comes out of the resolver, and
## the only honest way to ask it is to run the same rallies under each identity
## and compare the results.
##
## Same seeds, same rosters, same opponent for every region, so the *only* thing
## that varies is the seven numbers. Two regions whose rows match are two regions
## a player cannot tell apart, whatever their taglines say.
##
## The fingerprint is deliberately outcome-side rather than input-side. Reporting
## "Xérvu has the highest serve aggression" measures the table; reporting its ace
## and serve-error rates measures the game.

const GameManagerScript := preload("res://scripts/managers/game_manager.gd")
const RallyEventScript := preload("res://scripts/models/rally_event.gd")

const RALLIES: int = 320
const FIRST_SEED: int = 11000


func _initialize() -> void:
	var rows: Array[Dictionary] = []
	for region in VolleyballRegions.SIXNET_PARTICIPANTS:
		rows.append(_fingerprint(str(region)))

	print("=== %d rallies per region, identical seeds and rosters ===" % (
		RALLIES * 2
	))
	print("")
	print("%-13s %6s %6s %6s %6s %6s %6s %7s %6s %6s" % [
		"region", "kill", "dig", "ace", "svErr", "stuff", "cont/r", "tempo",
		"tmpSD", "quick",
	])
	for row in rows:
		print("%-13s %6.3f %6.3f %6.3f %6.3f %6.3f %6.2f %7.2f %6.3f %6.3f" % [
			row.region, row.kill, row.dig, row.ace, row.serve_error,
			row.stuff, row.contacts, row.mean_tempo, row.tempo_sd,
			row.quick_share,
		])
	print("")

	## **The question stated as a number.** For each region, the closest other
	## region across the whole fingerprint. A region whose nearest neighbour sits
	## on top of it is a region that exists in the table and not in the game.
	##
	## Each column is scaled by its own spread across the eight regions before
	## distances are taken, because otherwise `contacts per rally` -- which ranges
	## over whole numbers -- would drown every rate, and the answer would be about
	## units rather than about identity.
	var keys: Array[String] = [
		"kill", "dig", "ace", "serve_error", "stuff", "contacts", "mean_tempo",
		"tempo_sd", "quick_share",
	]
	var spreads := {}
	for key in keys:
		var lowest := INF
		var highest := -INF
		for row in rows:
			lowest = minf(lowest, float(row[key]))
			highest = maxf(highest, float(row[key]))
		spreads[key] = maxf(highest - lowest, 0.000001)
	print("distance to the nearest other region, in units of the whole spread")
	print("%-13s %9s   %s" % ["region", "distance", "nearest"])
	var separations: Array[Dictionary] = []
	for row in rows:
		var best := INF
		var best_name := ""
		for other in rows:
			if other.region == row.region:
				continue
			var total := 0.0
			for key in keys:
				var step: float = (float(row[key]) - float(other[key])) \
					/ float(spreads[key])
				total += step * step
			var distance := sqrt(total)
			if distance < best:
				best = distance
				best_name = str(other.region)
		separations.append({"region": row.region, "distance": best})
		print("%-13s %9.3f   %s" % [row.region, best, best_name])
	print("")
	separations.sort_custom(func(a, b): return float(a.distance) < float(b.distance))
	print("least distinct: %s (%.3f).  most distinct: %s (%.3f)" % [
		separations[0].region, separations[0].distance,
		separations[separations.size() - 1].region,
		separations[separations.size() - 1].distance,
	])
	quit()


func _fingerprint(region: String) -> Dictionary:
	var kills := 0
	var swings := 0
	var digs := 0
	var dig_chances := 0
	var aces := 0
	var serve_errors := 0
	var serves := 0
	var stuffs := 0
	var contacts := 0
	var rallies := 0
	var tempo_total := 0.0
	var tempo_count := 0
	var quicks := 0
	## **Spëddigh's identity is a spread, not a mean.** The first version of this
	## probe reported only `mean_tempo`, which is the average of the distribution
	## whose *width* is the whole of what "pushes every play to be faster and
	## tighter, unpredictably" claims -- a side that alternates tempo 0 and tempo 3
	## has the same mean as one that runs tempo 2 every time. Measuring the mean of
	## a distribution defined by its variance is the §0 mistake made with the
	## instrument instead of the model.
	var tempo_values: Array[float] = []
	for serving_home in [true, false]:
		var manager: Object = GameManagerScript.new()
		manager.seed_vertical_slice_data()
		## The one thing that varies. Everything else -- roster, opponent, seeds
		## -- is identical across regions by construction.
		manager.team.principles = VolleyballRegions.preferred_principles(region)
		manager.match_state.serving_home = serving_home
		for seed_value in range(FIRST_SEED, FIRST_SEED + RALLIES):
			var result: Resource = manager.resolve_active_rally(seed_value)
			if result == null:
				continue
			rallies += 1
			## **A kill is read off the rally's outcome, not the swing's
			## `success`.** `success` on an ATTACK is a quality threshold and says
			## nothing about whether the ball landed, which is why the first run of
			## this probe reported a kill rate of 0.000 for all eight regions --
			## a column that is identically zero everywhere is not evidence that
			## the regions match, it is evidence the column is not measuring
			## anything. Same vocabulary `run_rally_balance_probe` uses.
			match str(result.terminal_outcome):
				"kill":
					kills += 1
				"ace":
					aces += 1
			for event in result.events:
				var side := str(event.metadata.get("side", ""))
				match int(event.event_type):
					RallyEventScript.EventType.SERVE:
						if side != "home":
							continue
						serves += 1
						if not event.success:
							serve_errors += 1
					RallyEventScript.EventType.ATTACK:
						contacts += 1
						if side != "home":
							continue
						swings += 1
						if event.metadata.has("tempo"):
							tempo_total += float(event.metadata.tempo)
							tempo_count += 1
							tempo_values.append(float(event.metadata.tempo))
							if int(event.metadata.tempo) <= 1:
								quicks += 1
					RallyEventScript.EventType.DIG:
						contacts += 1
						if side != "home":
							continue
						dig_chances += 1
						if event.success:
							digs += 1
					RallyEventScript.EventType.BLOCK:
						contacts += 1
						if side == "home" \
								and str(event.metadata.get("outcome", "")) == "stuff":
							stuffs += 1
					RallyEventScript.EventType.RECEPTION, \
					RallyEventScript.EventType.SET:
						contacts += 1
		manager.free()
	var mean_tempo := tempo_total / float(maxi(tempo_count, 1))
	var variance := 0.0
	for value in tempo_values:
		variance += (value - mean_tempo) * (value - mean_tempo)
	return {
		"region": region,
		"tempo_sd": sqrt(variance / float(maxi(tempo_values.size(), 1))),
		"kill": float(kills) / float(maxi(swings, 1)),
		"dig": float(digs) / float(maxi(dig_chances, 1)),
		"ace": float(aces) / float(maxi(serves, 1)),
		"serve_error": float(serve_errors) / float(maxi(serves, 1)),
		"stuff": float(stuffs) / float(maxi(swings, 1)),
		"contacts": float(contacts) / float(maxi(rallies, 1)),
		"mean_tempo": tempo_total / float(maxi(tempo_count, 1)),
		"quick_share": float(quicks) / float(maxi(tempo_count, 1)),
	}
