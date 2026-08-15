extends SceneTree

## What does the dig contest actually cut, and does it know how fast the ball is?
##
##     godot --headless --path . --script res://tools/run_dig_contest_probe.gd
##
## Asked directly, and it is the right question to ask before changing spike
## pace: *"a hit scores when its relative quality versus the defense surpasses a
## threshold and multiplies its effectiveness (review that!)"*.
##
## `_dig_contest` is one line:
##
##     defense_quality + noise > attack_quality + DIG_ATTACKER_ADVANTAGE
##
## Two things about that shape are worth measuring rather than asserting. The
## first is that the margin is spent entirely on a boolean -- a ball that beats
## the defence by 0.01 and one that beats it by 0.5 produce the same outcome, so
## nothing "multiplies its effectiveness". The second is what `attack_quality`
## is: `_attack_effectiveness` returns the swing's *execution* quality times an
## identity multiplier. Not its speed. So the table below asks whether a faster
## ball is any harder to dig, and if the answer is no, then making spikes faster
## cannot move the dig rate by itself and would ship inert.
##
## Bands are quantiles of the sample rather than round numbers, because a band
## outside the distribution reports zero and says nothing -- which is the whole
## of §0 and has cost this branch three separate afternoons.

const GameManagerScript := preload("res://scripts/managers/game_manager.gd")
const RallyEventScript := preload("res://scripts/models/rally_event.gd")

const RALLIES: int = 260
const FIRST_SEED: int = 7000
const BANDS: int = 5


func _initialize() -> void:
	var rows: Array[Dictionary] = []
	for serving_home in [true, false]:
		var manager: Object = GameManagerScript.new()
		manager.seed_vertical_slice_data()
		manager.match_state.serving_home = serving_home
		for seed_value in range(FIRST_SEED, FIRST_SEED + RALLIES):
			var result: Resource = manager.resolve_active_rally(seed_value)
			if result == null:
				continue
			_collect(result, rows)
		manager.free()

	if rows.is_empty():
		print("no digs sampled")
		quit()
		return

	print("=== %d digs of a swing ===" % rows.size())
	print("")
	_spread("defence quality", rows, "defense")
	_spread("attack effectiveness", rows, "attack")
	_spread("margin (defence - attack)", rows, "margin")
	_spread("incoming ball speed, m/s", rows, "speed")
	print("")
	var conversion := 0.0
	for row in rows:
		conversion += float(row.quality_per_capability)
	conversion /= float(rows.size())
	## **The margin in the only unit a person picking a libero can act on.**
	##
	## The four dig attributes are weighted to sum to exactly 1.0, so a point on
	## all four moves capability by 0.010, and quality is that capability times
	## whatever opportunity the situation left them. Inverting the second factor
	## turns a margin into rating points.
	var per_point := 0.01 * conversion
	print("one rating point across the four dig attributes = %.4f of margin" % per_point)
	print("  the breakthrough bar    %.2f = %4.1f rating points" % [
		0.04, 0.04 / per_point,
	])
	print("  never dug at all        %.2f = %4.1f rating points" % [
		0.13, 0.13 / per_point,
	])
	print("")
	_by_band("dig rate by margin", rows, "margin")
	_by_band("dig rate by incoming ball speed", rows, "speed")

	## **Both sides of the net, term by term.** A gap observed in the product says
	## nothing about which factor made it: `_defense_terms` multiplies capability
	## by an opportunity built from timing, posture, support and recovery, so the
	## difference has to live in one of them.
	print("the two sides, term by term")
	print("")
	print("%-9s %5s %6s %6s %6s %6s %6s %6s %6s %7s %6s" % [
		"side", "n", "dug", "cap", "timing", "postur", "suppt", "recov",
		"oppty", "margin", "rdErr",
	])
	for side in ["home", "opponent"]:
		var group: Array = []
		for row in rows:
			if str(row.side) == side:
				group.append(row)
		if group.is_empty():
			continue
		var totals := {}
		var dug := 0
		for key in ["capability", "timing", "posture", "support", "recovery",
				"opportunity", "reach_margin", "read_error", "attack", "speed"]:
			totals[key] = 0.0
		for row in group:
			if bool(row.dug):
				dug += 1
			for key in totals:
				totals[key] = float(totals[key]) + float(row[key])
		var n := float(group.size())
		print("%-9s %5d %6.3f %6.3f %6.3f %6.3f %6.3f %6.3f %6.3f %7.2f %6.3f" % [
			side, group.size(), float(dug) / n,
			float(totals.capability) / n, float(totals.timing) / n,
			float(totals.posture) / n, float(totals.support) / n,
			float(totals.recovery) / n, float(totals.opportunity) / n,
			float(totals.reach_margin) / n, float(totals.read_error) / n,
		])
		print("%-9s %5s faced pressure %.3f at %.1f m/s" % [
			"", "", float(totals.attack) / n, float(totals.speed) / n,
		])
	print("")
	print("If the speed table is flat, the contest cannot see pace, and a faster")
	print("spike would arrive with the defence exactly as likely to dig it.")
	quit()


func _spread(title: String, rows: Array, key: String) -> void:
	var values: Array = []
	for row in rows:
		values.append(float(row[key]))
	values.sort()
	print("%-28s p10 %7.3f  p50 %7.3f  p90 %7.3f" % [
		title, _at(values, 0.10), _at(values, 0.50), _at(values, 0.90),
	])


func _by_band(title: String, rows: Array, key: String) -> void:
	var sorted_rows: Array = rows.duplicate()
	sorted_rows.sort_custom(func(a, b): return float(a[key]) < float(b[key]))
	print("%s" % title)
	print("  %-18s %6s %8s" % ["band", "n", "dug"])
	var per_band := int(ceil(float(sorted_rows.size()) / float(BANDS)))
	for band in range(BANDS):
		var from := band * per_band
		var to := mini(from + per_band, sorted_rows.size())
		if from >= to:
			continue
		var dug := 0
		for index in range(from, to):
			if bool(sorted_rows[index].dug):
				dug += 1
		print("  %6.3f to %6.3f %6d %8.3f" % [
			float(sorted_rows[from][key]), float(sorted_rows[to - 1][key]),
			to - from, float(dug) / float(to - from),
		])
	print("")


func _at(sorted_values: Array, quantile: float) -> float:
	return float(sorted_values[clampi(
		int(floor(quantile * float(sorted_values.size() - 1))),
		0, sorted_values.size() - 1,
	)])


func _collect(result: Resource, rows: Array[Dictionary]) -> void:
	var events: Array = result.events
	for index in range(events.size()):
		var event: Resource = events[index]
		if int(event.event_type) != RallyEventScript.EventType.DIG:
			continue
		var terms: Dictionary = event.metadata.get("dig_terms", {})
		if terms.is_empty() or not terms.has("contested_against"):
			continue
		## The ball this defender was actually facing. Walked backwards to the
		## nearest struck contact rather than assumed to be the previous event,
		## because a block touch sits between the swing and the dig on about a
		## fifth of them and its deflection is the flight that arrived.
		var speed := 0.0
		for back in range(index - 1, maxi(index - 3, -1), -1):
			var previous: Resource = events[back]
			var trajectory: Dictionary = previous.metadata.get(
				"outgoing_trajectory", {}
			)
			if trajectory.is_empty():
				continue
			speed = BallPresentation.launch_speed_mps(trajectory)
			break
		if speed <= 0.0:
			continue
		var capability := float(terms.get("capability", 0.0))
		var side := str(event.metadata.get("side", "?"))
		var defense := float(terms.get("quality", 0.0))
		var attack := float(terms.get("contested_against", 0.0))
		rows.append({
			"defense": defense,
			"attack": attack,
			"margin": defense - attack,
			"speed": speed,
			"dug": bool(event.success),
			"capability": capability,
			## What one point of rating is worth here. The four dig attributes are
			## weighted to sum to exactly 1.0, so a point on all four moves
			## capability by 0.01 -- and quality is capability times the
			## opportunity the situation left them. Inverting that says how many
			## rating points a given margin is, which is the only unit a person
			## picking a libero can actually act on.
			"quality_per_capability": defense / maxf(capability, 0.0001),
			"side": side,
			## Every term `_defense_terms` multiplies together, so a gap between the
			## two sides can be attributed to one of them rather than merely observed
			## in the product.
			"timing": float(terms.get("timing", 0.0)),
			"posture": float(terms.get("posture", 0.0)),
			"support": float(terms.get("support", 0.0)),
			"opportunity": float(terms.get("opportunity", 0.0)),
			"recovery": float(terms.get("recovery", 1.0)),
			"reach_margin": float(terms.get("reach_margin_meters", 0.0)),
			"read_error": float(terms.get("read_error_meters", 0.0)),
		})
