extends SceneTree

## Where do the two sides' reception-to-set chains first disagree?
##
## Both sides own the ball's height at a contact now, so the opponent set's
## residual seam is two authorities disagreeing rather than one being absent.
## This walks the chain on each side -- RECEPTION contact, the pass flight it
## launched, whatever events sit between, the SET contact, the set flight -- and
## reports every link side by side so the *first* divergence is visible rather
## than inferred from the last one.
##
## Nothing here recomputes the resolver. Every field is read off published
## metadata; a difference reported below is a difference the game has.

const MANAGER := preload("res://scripts/managers/game_manager.gd")

const RALLIES: int = 300
const SEAM_TOLERANCE_METERS: float = 0.05


func _initialize() -> void:
	var rows := {}
	## Individual chains, kept so a breaking case can be printed whole rather
	## than described. The first few of each kind is enough to read.
	var samples := {"broken": [], "clean": []}
	for side in range(2):
		var side_name := "home" if side == 0 else "opponent"
		for index in range(RALLIES / 2):
			var manager = MANAGER.new()
			manager.seed_vertical_slice_data()
			manager.match_state.serving_home = side == 0
			var result: Resource = manager.resolve_active_rally(960000 + index)
			if result == null:
				continue
			var contacts: Array = []
			for raw_event in result.events:
				var event := raw_event as RallyEvent
				if event == null:
					continue
				if int(event.event_type) == RallyEvent.EventType.POINT:
					continue
				contacts.append(event)
			for position in range(contacts.size()):
				var event: RallyEvent = contacts[position]
				if int(event.event_type) != RallyEvent.EventType.SET:
					continue
				var chain := _describe_chain(contacts, position, side_name)
				if chain.is_empty():
					continue
				var key := "%s/%s" % [
					str(chain.set_side), str(chain.between),
				]
				if not rows.has(key):
					rows[key] = {
						"n": 0, "broken": 0, "gap": 0.0, "worst": 0.0,
						"lineage_breaks": 0, "no_pass": 0,
						"stamped_from": {},
					}
				var row: Dictionary = rows[key]
				row["n"] = int(row["n"]) + 1
				var source := str(chain.stamped_from)
				row["stamped_from"][source] = int(
					row["stamped_from"].get(source, 0)
				) + 1
				if bool(chain.no_pass):
					row["no_pass"] = int(row["no_pass"]) + 1
				if bool(chain.lineage_break):
					row["lineage_breaks"] = int(row["lineage_breaks"]) + 1
				var gap := float(chain.gap)
				row["gap"] = float(row["gap"]) + gap
				row["worst"] = maxf(float(row["worst"]), gap)
				if gap > SEAM_TOLERANCE_METERS:
					row["broken"] = int(row["broken"]) + 1
					if samples.broken.size() < 4:
						samples.broken.append(chain)
				elif samples.clean.size() < 2 and str(chain.set_side) == "opponent":
					samples.clean.append(chain)
	_report(rows, samples)
	quit(0)


## One reception-to-set chain, flattened into comparable fields.
func _describe_chain(
	contacts: Array, set_index: int, serving_side: String
) -> Dictionary:
	var set_event: RallyEvent = contacts[set_index]
	## The contact that fed this set, and everything between the two.
	var feed_index := set_index - 1
	var between: Array = []
	while feed_index >= 0:
		var candidate: RallyEvent = contacts[feed_index]
		var kind := int(candidate.event_type)
		if kind in [
			RallyEvent.EventType.RECEPTION, RallyEvent.EventType.DIG,
			RallyEvent.EventType.ATTACK_COVERAGE,
		]:
			break
		between.push_front(str(
			RallyEvent.EventType.keys()[kind]
		))
		feed_index -= 1
	if feed_index < 0:
		return {}
	var feed: RallyEvent = contacts[feed_index]
	var pass_flight: Dictionary = feed.metadata.get("outgoing_trajectory", {})
	var set_flight: Dictionary = set_event.metadata.get("outgoing_trajectory", {})
	var stated: Variant = set_event.metadata.get(
		"ball_contact_height_meters", null
	)
	var pass_end := float(pass_flight.get("end_height_meters", NAN))
	return {
		"seed_side": serving_side,
		## Which side the *set* belongs to, which is the axis FD-009 is about --
		## on a home serve the opponent sets first, so serving side and setting
		## side are not the same thing and conflating them was a real risk here.
		"set_side": str(set_event.metadata.get("side", "?")),
		"between": ",".join(between) if not between.is_empty() else "-",
		"feed": str(RallyEvent.EventType.keys()[int(feed.event_type)]),
		"no_pass": pass_flight.is_empty(),
		"pass_source": str(pass_flight.get("height_source", "none")),
		"pass_end_height": pass_end,
		"set_stated_height": NAN if stated == null else float(stated),
		"stamped_from": str(set_event.metadata.get(
			"ball_contact_height_source", "none"
		)),
		"set_launch_height": float(set_flight.get("start_height_meters", NAN)),
		"gap": 0.0 if stated == null or is_nan(pass_end) \
			else absf(float(stated) - pass_end),
		## Same ball, or a different one? A set fed by a flight it does not
		## descend from is a lineage break and a different defect entirely.
		"lineage_break": not str(pass_flight.get(
			"authoritative_flight_id", ""
		)).is_empty() and str(set_event.metadata.get(
			"incoming_pass_trajectory", {}
		).get("authoritative_flight_id", str(pass_flight.get(
			"authoritative_flight_id", ""
		)))) != str(pass_flight.get("authoritative_flight_id", "")),
		"pass_end_time": float(pass_flight.get("end_time", NAN)),
		"set_time": float(set_event.metadata.get("event_time", NAN)),
	}


func _report(rows: Dictionary, samples: Dictionary) -> void:
	print("%-34s %5s %7s %9s %9s %8s %9s" % [
		"set side / events between", "n", "broken", "mean gap", "worst gap",
		"no pass", "lineage",
	])
	var keys: Array = rows.keys()
	keys.sort()
	for key in keys:
		var row: Dictionary = rows[key]
		var n := maxi(int(row["n"]), 1)
		print("%-34s %5d %7d %9.3f %9.3f %8d %9d" % [
			str(key), int(row["n"]), int(row["broken"]),
			float(row["gap"]) / float(n), float(row["worst"]),
			int(row["no_pass"]), int(row["lineage_breaks"]),
		])
		print("%-34s   stamped from: %s" % ["", str(row["stamped_from"])])
	for kind in ["broken", "clean"]:
		print("")
		print("-- %s chains --" % kind)
		for chain in samples[kind]:
			print("  set_side=%-9s between=%-14s feed=%-10s pass_src=%-14s" % [
				str(chain.set_side), str(chain.between), str(chain.feed),
				str(chain.pass_source),
			])
			print("    pass end %.3f m @ t=%.3f | set says %.3f m (from %s) | set launches %.3f m @ t=%.3f | gap %.3f" % [
				float(chain.pass_end_height), float(chain.pass_end_time),
				float(chain.set_stated_height), str(chain.stamped_from),
				float(chain.set_launch_height), float(chain.set_time),
				float(chain.gap),
			])
