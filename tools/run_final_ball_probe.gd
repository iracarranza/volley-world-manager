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
## So the next step is not the outro. It is publishing a drawn flight's end
## height, and then re-running this with the question it was meant to ask.
func _initialize() -> void:
	var Events := load("res://scripts/models/rally_event.gd")
	var names := {
		Events.EventType.SERVE: "SERVE", Events.EventType.RECEPTION: "RECEPTION",
		Events.EventType.SET: "SET", Events.EventType.ATTACK: "ATTACK",
		Events.EventType.BLOCK: "BLOCK", Events.EventType.DEFENSE: "DEFENSE",
	}
	var manager: Object = load("res://scripts/managers/game_manager.gd").new()
	manager.seed_vertical_slice_data()
	var by_outcome := {}
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
