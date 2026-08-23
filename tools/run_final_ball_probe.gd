extends SceneTree

## When playback stops, is the ball on the floor?
##
##     godot --headless --path . --script res://tools/run_final_ball_probe.gd
##
## Reported as tools ending the point before the ball is drawn hitting the
## floor, and as the principle behind it: the rally is over when the ball is
## down, not when the event list runs out. Half of the report was an outro
## charged to zero by the flight/aftermath rule and is fixed. This measures the
## other half before anything is built for it, because a 0.38 s outro that is
## already long enough on most rallies would make the rest a fix for a case that
## does not occur -- and this session has produced three of those.
##
## The question in a form the data can answer: **does the rally's last contact
## carry a flight?** If it does, playback draws that flight in full and the ball
## finishes wherever the flight finishes. If it does not, the last thing drawn
## belongs to an earlier contact, and whether the ball is down depends on where
## *that* one ended -- at a landing, or at a pair of hands.
##
## **Measured, and then read too fast.** 400 rallies, every terminal outcome:
## the final contact carries a flight on 0.0% of them. Universal, not rare. A
## trailing non-flight contact always exists, so every rally ends on a window
## whose length is the outro rather than the ball's.
##
## That is worth knowing and it is *not* the answer to the question asked. It
## says the last event has no flight; it does not say the ball is in the air.
## On a kill the attack's flight already ran to its landing on the floor and the
## trailing failed dig is a beat over a dead ball, which is correct. The three
## trailing pairs that dominate -- DEFENSE, ATTACK and BLOCK each followed by a
## contact with no flight -- are consistent with both a ball that has landed and
## a ball still falling, and this instrument cannot separate them.
##
## What separates them is the **end height** of the preceding flight, which is
## the thing named as missing. Nothing publishes it, and inferring it from
## `end_position` fails on exactly the case that matters: a flight terminated at
## an interception ends at a pair of hands whose height is not written down.
##
## **And the end height was already published.** `BallPresentation` writes
## `end_height_meters` onto every display trajectory -- it is computed at
## playback time rather than stamped on the event, which is why grepping the
## event metadata for it found nothing. So the probe asks the presentation layer
## directly, exactly as playback does, and the question it could not answer
## becomes one line.
##
## **Second run, and the instrument is wrong again -- the fifth time in this
## session, which is the finding.** It reports 63.2% of 400 rallies stopping
## with the ball above 0.35 m, and a modal end height of 5.2 m rising to 8.2 m.
## A volleyball does not go eight metres up. The number is an artefact of how
## this probe asks:
##
## - `display_trajectory` is handed `{}` for `profiles`, so
##   `contact_height(next_contact, {})` falls back to a default rather than to
##   the height that contact actually happened at.
## - and the `next_contact` passed for the final flight is the trailing contact
##   that *failed*, which `terminate_at_next_contact` deliberately declines to
##   terminate at -- so the flight keeps its aimed landing while the end height
##   is taken from the contact it did not reach.
##
## Reasoned through instead: a trailing failed contact means nobody touched the
## ball, so it flew on to the aimed landing, and the aimed landing is the floor.
## Which says the ball is probably down on most rallies and the outro is
## probably adequate -- the opposite of what the table above claims.
##
## **So this is not settled and the outro is not built.** What would settle it is
## the height at the *end of the drawn flight the last leg actually ran*, taken
## from playback rather than reconstructed beside it: the same number
## `set_ball_trajectory_sample` uses at progress 1.0. That wants a hook in the
## match screen, not another guess out here.
##
## Left in the tree with its own wrongness written down, because the pattern is
## worth more than the probe: five instruments this session have measured
## something adjacent to the question and been read as answering it.
func _initialize() -> void:
	var Events := load("res://scripts/models/rally_event.gd")
	var names := {
		Events.EventType.SERVE: "SERVE", Events.EventType.RECEPTION: "RECEPTION",
		Events.EventType.SET: "SET", Events.EventType.ATTACK: "ATTACK",
		Events.EventType.BLOCK: "BLOCK", Events.EventType.DIG: "DIG", Events.EventType.ATTACK_COVERAGE: "ATTACK_COVERAGE",
	}
	var Presentation := load("res://scripts/simulation/ball_presentation.gd")
	var manager: Object = load("res://scripts/managers/game_manager.gd").new()
	manager.seed_vertical_slice_data()
	var by_outcome := {}
	var heights := {}
	var airborne := 0
	var rallies := 0
	for rally_seed in range(20000, 20400):
		manager.match_state.serving_home = (rally_seed % 2) == 0
		var result: Resource = manager.resolve_active_rally(rally_seed)
		if result == null:
			continue
		rallies += 1
		## The last contact, and the last one that carried a flight.
		var last_contact = null
		var last_flight = null
		for event in result.events:
			if int(event.event_type) == Events.EventType.SET_DECISION:
				continue
			last_contact = event
			if not Dictionary(event.metadata.get("outgoing_trajectory", {})).is_empty():
				last_flight = event
		if last_contact == null:
			continue
		## Where the last drawn flight actually left the ball. The presentation
		## layer is asked rather than reimplemented, so this is the same number
		## playback draws to.
		if last_flight != null:
			var after = null
			var seen := false
			for event in result.events:
				if int(event.event_type) == Events.EventType.SET_DECISION:
					continue
				if seen:
					after = event
					break
				if event == last_flight:
					seen = true
			var display: Dictionary = Presentation.display_trajectory(
				last_flight, after,
				Dictionary(last_flight.metadata.get("outgoing_trajectory", {})),
				{},
			)
			var end_height := float(display.get("end_height_meters", 0.0))
			var bucket := "%.1f" % (floorf(end_height / 0.25) * 0.25)
			heights[bucket] = int(heights.get(bucket, 0)) + 1
			## A ball more than a hand's width off the floor when the last flight
			## finishes is a ball still in the air when playback stops.
			if end_height > 0.35:
				airborne += 1
		var outcome := str(result.terminal_outcome)
		var row: Dictionary = by_outcome.get(outcome, {
			"rallies": 0, "final_carries_flight": 0, "trailing": {},
		})
		row["rallies"] = int(row["rallies"]) + 1
		if last_flight == last_contact:
			row["final_carries_flight"] = int(row["final_carries_flight"]) + 1
		else:
			## The contacts drawn after the last flight. Each is a window with a
			## ball that is wherever the previous flight left it.
			var key := "%s -> %s" % [
				names.get(int(last_flight.event_type), "none") if last_flight != null \
					else "none",
				names.get(int(last_contact.event_type), "?"),
			]
			var trailing: Dictionary = row["trailing"]
			trailing[key] = int(trailing.get(key, 0)) + 1
			row["trailing"] = trailing
		by_outcome[outcome] = row

	print("%d rallies\n" % rallies)
	print("%-18s %8s %14s %10s" % [
		"terminal outcome", "rallies", "final has flight", "share"])
	var keys := by_outcome.keys()
	keys.sort()
	var total := 0
	var total_with := 0
	for key in keys:
		var row: Dictionary = by_outcome[key]
		total += int(row["rallies"])
		total_with += int(row["final_carries_flight"])
		print("%-18s %8d %14d %9.1f%%" % [
			key, int(row["rallies"]), int(row["final_carries_flight"]),
			100.0 * float(row["final_carries_flight"]) \
				/ maxf(float(row["rallies"]), 1.0),
		])
	print("%-18s %8d %14d %9.1f%%" % [
		"all", total, total_with,
		100.0 * float(total_with) / maxf(float(total), 1.0)])

	print("\nheight of the ball where the last drawn flight ends, 25 cm buckets")
	var height_keys := heights.keys()
	height_keys.sort()
	for key in height_keys:
		print("  %6s m  %5d" % [key, int(heights[key])])
	print("\n%d of %d rallies (%.1f%%) stop drawing with the ball above 0.35 m" % [
		airborne, rallies, 100.0 * float(airborne) / maxf(float(rallies), 1.0)])

	print("\nwhen the final contact has no flight, what trails what")
	var trailing_all := {}
	for key in keys:
		for pair in Dictionary(by_outcome[key]["trailing"]).keys():
			trailing_all[pair] = int(trailing_all.get(pair, 0)) \
				+ int(by_outcome[key]["trailing"][pair])
	var pairs := trailing_all.keys()
	pairs.sort_custom(func(a: String, b: String) -> bool:
		return int(trailing_all[a]) > int(trailing_all[b]))
	for pair in pairs:
		print("  %-24s %5d" % [pair, int(trailing_all[pair])])
	manager.free()
	quit()
