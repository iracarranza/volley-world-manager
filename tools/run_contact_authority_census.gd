extends SceneTree

## Where does each contact family get the ball's height, and who knows it?
##
## `CONTACT_AND_BALL_FLIGHT.md` §5 asks that a realised contact be one point --
## the incoming segment's end, the outgoing segment's start, and the actor's
## contact, all the same. The block reached that bar by publishing the
## intersection its feasibility test already proved. This asks the same question
## of every other family, and it asks it three ways at once, because the answer
## is different for each:
##
##   published   what the incoming flight says its far end was
##               (`end_height_meters`, and `height_source` says whether the
##               writer actually knew or took the 1.0 m default)
##   proxy       what playback draws, which is `BallPresentation.contact_height`
##               -- a reach, a platform or a hip, read off the *body*
##   gap         the distance between them, which is the seam
##
## The classification each family gets is read off those, not asserted:
##
##   authoritative     the writer knew the height and the proxy agrees
##   computed+dropped  the writer knew and the proxy disagrees -- the truth
##                     exists and playback is not reading it
##   body-proxy        the writer did not know; the only number is the body's
##
## Read entirely from published metadata and the shipped presentation call, so a
## family that looks authoritative here is authoritative in the game.

const MANAGER := preload("res://scripts/managers/game_manager.gd")
const BallPresentationScript := preload(
	"res://scripts/simulation/ball_presentation.gd"
)

const RALLIES: int = 300
## Two heights this far apart are a visible jump rather than rounding. Same
## figure the playback continuity probe cuts on.
const SEAM_TOLERANCE_METERS: float = 0.05


func _initialize() -> void:
	var rows := {}
	for side in range(2):
		for index in range(RALLIES / 2):
			var manager = MANAGER.new()
			manager.seed_vertical_slice_data()
			manager.match_state.serving_home = side == 0
			var result: Resource = manager.resolve_active_rally(940000 + index)
			if result == null:
				continue
			var profiles: Dictionary = result.player_physical_profiles
			var contacts: Array = []
			for raw_event in result.events:
				var event := raw_event as RallyEvent
				if event == null:
					continue
				if int(event.event_type) == RallyEvent.EventType.POINT:
					continue
				contacts.append(event)
			for position in range(1, contacts.size()):
				var event: RallyEvent = contacts[position]
				var previous: RallyEvent = contacts[position - 1]
				var incoming: Dictionary = previous.metadata.get(
					"outgoing_trajectory", {}
				)
				if incoming.is_empty():
					incoming = previous.metadata.get("trajectory", {})
				var family := str(
					RallyEvent.EventType.keys()[int(event.event_type)]
				)
				var key := "%s/%s" % [
					family, "home" if side == 0 else "opponent",
				]
				if not rows.has(key):
					rows[key] = {
						"legs": 0, "known": 0, "gap_total": 0.0, "gap_worst": 0.0,
						"breaks": 0, "no_incoming": 0,
					}
				var row: Dictionary = rows[key]
				row["legs"] = int(row["legs"]) + 1
				if incoming.is_empty():
					row["no_incoming"] = int(row["no_incoming"]) + 1
					continue
				var source := str(incoming.get("height_source", "default"))
				var knows_end := source == "resolved"
				if knows_end:
					row["known"] = int(row["known"]) + 1
				## What the incoming leg carries, which is what decides whether
				## the ball's far-end height is *derivable* rather than merely
				## absent. A struck flight publishes its launch state, and a
				## launch plus a real start height integrates to an endpoint --
				## that is a realised segment, not a reconstruction.
				row["src_" + source] = int(row.get("src_" + source, 0)) + 1
				if incoming.has("launch_vertical_mps"):
					row["launch"] = int(row.get("launch", 0)) + 1
					if source in ["resolved", "start_resolved"]:
						row["derivable"] = int(row.get("derivable", 0)) + 1
				elif knows_end:
					row["derivable"] = int(row.get("derivable", 0)) + 1
				## The publisher side of the same seam. A contact's own outgoing
				## flight is the next contact's incoming one, so what it carries
				## decides whether the chain can be closed *forward* -- a real
				## start height plus a launch integrates to the far end, and the
				## far end is the next contact's height.
				var outgoing: Dictionary = event.metadata.get(
					"outgoing_trajectory", {}
				)
				if outgoing.is_empty():
					row["out_none"] = int(row.get("out_none", 0)) + 1
				else:
					row["out_" + str(
						outgoing.get("height_source", "default")
					)] = int(row.get("out_" + str(
						outgoing.get("height_source", "default")
					), 0)) + 1
					if outgoing.has("launch_vertical_mps"):
						row["out_launch"] = int(row.get("out_launch", 0)) + 1
				var published := float(incoming.get("end_height_meters", 1.0))
				var proxy := BallPresentationScript.contact_height(event, profiles)
				var gap := absf(published - proxy)
				row["gap_total"] = float(row["gap_total"]) + gap
				row["gap_worst"] = maxf(float(row["gap_worst"]), gap)
				if gap > SEAM_TOLERANCE_METERS:
					row["breaks"] = int(row["breaks"]) + 1
	_report(rows)
	quit(0)


static func _sources(row: Dictionary, prefix: String = "src_") -> String:
	var parts: Array = []
	for name in ["resolved", "start_resolved", "default"]:
		var count := int(row.get(prefix + name, 0))
		if count > 0:
			parts.append("%s=%d" % [name, count])
	return ", ".join(parts)


func _report(rows: Dictionary) -> void:
	print("%-26s %6s %7s %7s %9s %9s  %s" % [
		"family/serving side", "legs", "known", "breaks", "mean gap",
		"worst gap", "classification",
	])
	var keys: Array = rows.keys()
	keys.sort()
	for key in keys:
		var row: Dictionary = rows[key]
		var legs := maxi(int(row["legs"]) - int(row["no_incoming"]), 1)
		var known := int(row["known"])
		var breaks := int(row["breaks"])
		var verdict := "body-proxy"
		if known == 0:
			verdict = "body-proxy"
		elif breaks == 0:
			verdict = "authoritative"
		else:
			verdict = "computed+dropped"
		var derivable := int(row.get("derivable", 0))
		if derivable > 0 and verdict == "body-proxy":
			verdict = "derivable, not derived"
		print("%-26s %6d %7d %7d %9.3f %9.3f  %-20s launch %d, derivable %d, %s" % [
			str(key), int(row["legs"]), known, breaks,
			float(row["gap_total"]) / float(legs), float(row["gap_worst"]),
			verdict, int(row.get("launch", 0)), derivable,
			_sources(row),
		])
		print("%-26s %6s publishes: none=%d, launch=%d, %s" % [
			"", "", int(row.get("out_none", 0)), int(row.get("out_launch", 0)),
			_sources(row, "out_"),
		])
	print("")
	print("known   = the incoming flight's writer knew its far-end height")
	print("          (`height_source == \"resolved\"`), rather than taking the")
	print("          1.0 m default `BallTrajectory.create` falls back to")
	print("breaks  = legs where the published far end and the drawn contact")
	print("          height differ by more than %.2f m" % SEAM_TOLERANCE_METERS)
