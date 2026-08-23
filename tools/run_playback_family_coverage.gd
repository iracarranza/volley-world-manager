extends SceneTree

## Which of M8's required fixture families does playback actually get exercised
## on, and does the drawn ball stay continuous in each?
##
## The continuity baseline reported by *contact family* -- SERVE, BLOCK, DIG.
## That is not the same list M8 asks for, which is a list of **situations**: a
## stuff, a wipe, an overpass, a leg where somebody is still getting up. A family
## can be well covered while a situation inside it is never drawn at all, and a
## probe that only reports families cannot tell you which.
##
## So this sweeps both serving sides, classifies every drawn leg into the
## situations M8 names, and reports the seam for each. A row reading zero is the
## finding: that situation is not being certified by anything, and needs a
## constructed fixture rather than a wider sweep.

const MANAGER := preload("res://scripts/managers/game_manager.gd")
const BP := preload("res://scripts/simulation/ball_presentation.gd")

const SEAM_TOLERANCE_METERS: float = 0.05
const SEEDS_PER_SIDE := 110

## Every situation M8 lists, in its order, so a reader can check them off.
const REQUIRED := [
	"serve->receive", "ace", "serve->touch->shank", "receive->set", "set->attack",
	"attack->floor", "attack->block touch->dig", "stuff", "wipe/tool",
	"dig/coverage", "overpass", "terminal net", "terminal out", "terminal floor",
	"recovery_debt leg",
]


func _initialize() -> void:
	var rows := {}
	for name in REQUIRED:
		rows[name] = {"n": 0, "seam_breaks": 0, "seam_total": 0.0, "worst": 0.0}
	for side_index in range(2):
		for index in range(SEEDS_PER_SIDE):
			var manager = MANAGER.new()
			manager.seed_vertical_slice_data()
			manager.match_state.serving_home = side_index == 0
			var result: Resource = manager.resolve_active_rally(500000 + index)
			if result == null:
				continue
			_walk(result, rows)
	_report(rows)


func _walk(result: Resource, rows: Dictionary) -> void:
	var profiles: Dictionary = result.player_physical_profiles
	var terminal := str(result.terminal_outcome)
	var contacts: Array = []
	for raw_event in result.events:
		var event := raw_event as RallyEvent
		if event == null or int(event.actor_id) < 0:
			continue
		if int(event.event_type) in [
			RallyEvent.EventType.SET_DECISION, RallyEvent.EventType.POINT
		]:
			continue
		contacts.append(event)
	var previous_end := NAN
	for position in range(contacts.size()):
		var event: RallyEvent = contacts[position]
		var next_contact: RallyEvent = (
			contacts[position + 1] if position + 1 < contacts.size() else null
		)
		var trajectory: Dictionary = event.metadata.get("outgoing_trajectory", {})
		if trajectory.is_empty():
			trajectory = event.metadata.get("trajectory", {})
		var display: Dictionary = BP.display_trajectory(
			event, next_contact, trajectory, profiles
		)
		var start_height := float(display.get("start_height_meters", NAN))
		var jump := NAN
		if not is_nan(previous_end) and not is_nan(start_height):
			jump = absf(previous_end - start_height)
		for name in _situations(event, next_contact, terminal, position):
			_record(rows, str(name), jump)
		previous_end = float(display.get("end_height_meters", NAN))


## Every situation this leg belongs to. A leg can serve more than one -- an
## attack that is stuffed is both "attack->block" and "stuff" -- and counting it
## once per situation is the point.
func _situations(
	event: RallyEvent, next_contact: RallyEvent, terminal: String, position: int
) -> Array:
	var found: Array = []
	var kind := int(event.event_type)
	var next_kind := -1 if next_contact == null else int(next_contact.event_type)
	var launched: bool = not Dictionary(
		event.metadata.get("outgoing_trajectory", {})
	).is_empty()
	if kind == RallyEvent.EventType.SERVE:
		if next_kind == RallyEvent.EventType.RECEPTION:
			found.append("serve->receive")
		if terminal == "ace":
			found.append("ace")
	if kind == RallyEvent.EventType.RECEPTION:
		if not bool(event.success) and launched:
			found.append("serve->touch->shank")
		if next_kind == RallyEvent.EventType.SET:
			found.append("receive->set")
	if kind == RallyEvent.EventType.SET and next_kind == RallyEvent.EventType.ATTACK:
		found.append("set->attack")
	if kind == RallyEvent.EventType.ATTACK:
		if next_contact == null:
			found.append("attack->floor")
		elif next_kind == RallyEvent.EventType.BLOCK:
			found.append("attack->block touch->dig")
		if terminal == "blocked" or terminal == "counter_block":
			found.append("stuff")
		if str(event.metadata.get("attack_direction", "")).to_lower().contains("wipe") \
				or bool(event.metadata.get("used_the_block", false)) \
				or str(event.metadata.get("resolution", "")).to_lower() == "tool":
			found.append("wipe/tool")
	if kind == RallyEvent.EventType.DIG or kind == RallyEvent.EventType.ATTACK_COVERAGE:
		found.append("dig/coverage")
	## An overpass is a ball crossing the net on a team's first or second contact
	## rather than as an attack, which the resolver marks on the event it creates.
	if bool(event.metadata.get("overpass", false)) \
			or str(event.metadata.get("origin", "")).contains("overpass") \
			or str(event.metadata.get("exit_reason", "")).contains("overpass"):
		found.append("overpass")
	if next_contact == null:
		if terminal.contains("error") or terminal == "out":
			found.append("terminal out")
		elif terminal.contains("net"):
			found.append("terminal net")
		else:
			found.append("terminal floor")
	if not Dictionary(event.metadata.get("recovery_debt", {})).is_empty():
		found.append("recovery_debt leg")
	return found


func _record(rows: Dictionary, name: String, jump: float) -> void:
	if not rows.has(name):
		return
	var row: Dictionary = rows[name]
	row["n"] = int(row["n"]) + 1
	if is_nan(jump):
		return
	row["seam_total"] = float(row["seam_total"]) + jump
	if jump > SEAM_TOLERANCE_METERS:
		row["seam_breaks"] = int(row["seam_breaks"]) + 1
	row["worst"] = maxf(float(row["worst"]), jump)


func _report(rows: Dictionary) -> void:
	print("%-26s %7s %10s %10s %10s" % [
		"required situation", "legs", "seam brk", "mean seam", "worst",
	])
	var uncovered: Array = []
	for name in REQUIRED:
		var row: Dictionary = rows[name]
		var legs := int(row["n"])
		if legs == 0:
			uncovered.append(name)
		print("%-26s %7d %10d %10.3f %10.3f" % [
			name, legs, int(row["seam_breaks"]),
			float(row["seam_total"]) / float(maxi(legs, 1)), float(row["worst"]),
		])
	print("")
	if uncovered.is_empty():
		print("every required situation is exercised by the sweep")
	else:
		print("NOT EXERCISED (needs a constructed fixture): %s" % ", ".join(uncovered))
	quit(0)
