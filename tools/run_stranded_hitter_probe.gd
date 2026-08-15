extends SceneTree

## After the set goes to somebody else, where does a hitter stand?
##
##     godot --headless --path . --script res://tools/run_stranded_hitter_probe.gd
##
## Reported: hitters who entered their approach runway and did not get a set
## stay there instead of returning to a logical position.
##
## The staging is real and is meant to be. `_transition_phase_map`, published on
## the SET event, sends every front-row voli who is not the chosen hitter to
## `_approach_start_position` -- so during the set's flight all three front-row
## volis run to their marks, which is what a real offence does. The question is
## only what happens to the two who were passed over once the ball has gone.
##
## So this counts, per window after the set, whether each of those volis is
## **named** by anything: a phase-target map, a staging target, or a movement
## target on the event being drawn. A voli nobody names does not necessarily
## freeze -- `_apply_base_positions` sends the resting side home, and a cheat
## step moves anyone with no assignment -- but a voli named by nothing for
## several windows in a row is the only way the reported behaviour can happen,
## and if that never occurs then the report is about something else.
##
## Measured at the event level rather than off the rendered court on purpose:
## the question is what the resolver publishes, and drawing it would put the
## movement plan, the pacing and the base-return rule between the question and
## the answer. `measure_offball_travel.gd` is the instrument for the other half.
##
## **Measured: 133 sets, 331 passed-over volis.**
##
##     windows unnamed   volis
##     0                    94   28.4%
##     1                   126   38.1%
##     2                    66   19.9%
##     3                    14    4.2%
##     4                    27    8.2%
##     6                     4    1.2%
##
## 111 of 331 (33.5%) go two or more windows with nobody naming them, and **100
## of those 111 are never named again before the rally ends**. The resolver
## stops having an opinion about a hitter it passed over, and does not resume.
##
## **What this does not say**, because the distinction is the one this file
## exists to respect: it measures publication, not pixels. A voli nobody names
## may still be moved by `_apply_base_positions` or by a cheat step. So this is
## the necessary condition for the reported behaviour rather than a sighting of
## it -- but "nobody ever names them again" is a defect on its own terms
## whatever the drawing then does with it.
func _initialize() -> void:
	var Events := load("res://scripts/models/rally_event.gd")
	var manager: Object = load("res://scripts/managers/game_manager.gd").new()
	manager.seed_vertical_slice_data()

	var streaks := {}
	var stranded := 0
	var sets_seen := 0
	var by_next := {}
	for rally_seed in range(31000, 31120):
		manager.match_state.serving_home = (rally_seed % 2) == 0
		var result: Resource = manager.resolve_active_rally(rally_seed)
		if result == null:
			continue
		var events: Array = []
		for event in result.events:
			if int(event.event_type) != Events.EventType.SET_DECISION:
				events.append(event)
		for index in range(events.size()):
			var event = events[index]
			if int(event.event_type) != Events.EventType.SET:
				continue
			var staged := Dictionary(event.metadata.get("home_phase_targets", {}))
			if staged.is_empty():
				continue
			var hitter := int(event.metadata.get("staged_next_actor_id", -1))
			sets_seen += 1
			## Everybody the set sent somewhere who is not the voli it was set
			## to. These are the passed-over hitters plus the back row, and the
			## back row is left in deliberately -- a rule that only holds for
			## the front row is a rule that has to know which is which, and the
			## streak below is the same question for both.
			for raw_id in staged:
				var player_id := int(raw_id)
				if player_id == hitter:
					continue
				var quiet := 0
				var next_label := "rally ended"
				for ahead in range(index + 1, events.size()):
					var later = events[ahead]
					if _names(later, player_id):
						next_label = "%s names them" % Events.EventType.keys()[
							int(later.event_type)
						]
						break
					quiet += 1
					next_label = "rally ended"
				streaks[quiet] = int(streaks.get(quiet, 0)) + 1
				if quiet >= 2:
					stranded += 1
					by_next[next_label] = int(by_next.get(next_label, 0)) + 1

	print("%d sets with a published transition map\n" % sets_seen)
	print("windows a passed-over voli goes unnamed after the set")
	print("%-10s %10s" % ["windows", "volis"])
	var keys := streaks.keys()
	keys.sort()
	var total := 0
	for key in keys:
		total += int(streaks[key])
	for key in keys:
		print("%-10d %10d  %5.1f%%" % [
			int(key), int(streaks[key]),
			100.0 * float(streaks[key]) / maxf(float(total), 1.0),
		])
	print("\n%d of %d (%.1f%%) go two or more windows with nobody naming them" % [
		stranded, total, 100.0 * float(stranded) / maxf(float(total), 1.0),
	])
	print("\nwhat ends the silence, for those")
	for key in by_next:
		print("  %-24s %5d" % [key, int(by_next[key])])
	manager.free()
	quit()


## Whether this event says anything about where this voli goes.
##
## The three sources playback reads, in `_build_movement_plan`: either phase-map
## for the side they are on, the staged next actor, and the event's own
## movement target. Anything else is `_apply_base_positions` or a cheat step,
## which is exactly what "nobody named them" means.
func _names(event, player_id: int) -> bool:
	for key in ["home_phase_targets", "opponent_phase_targets"]:
		if Dictionary(event.metadata.get(key, {})).has(player_id):
			return true
	if int(event.metadata.get("staged_next_actor_id", -1)) == player_id:
		return true
	if int(event.actor_id) == player_id and event.metadata.has("movement_target"):
		return true
	return int(event.actor_id) == player_id
