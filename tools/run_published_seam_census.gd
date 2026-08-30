extends SceneTree

## M11's census: do the two *published* legs at a contact agree?
##
## **This is deliberately not what `run_playback_continuity_probe.gd` measures,
## and the difference is why FD-006 closed wrongly.** That probe compares
## `BallPresentation.display_trajectory` output -- the drawn ball -- and
## presentation computes its own heights from the event pair and the two bodies.
## So it can produce a continuous drawn flight on top of a discontinuous record,
## and it did: `SERVE -> RECEPTION` reported `0 breaks, mean 0.000` while the
## serve's published leg ended at 1.00 m and the reception's published leg began
## at 3.79 m. A drawn seam of zero says presentation papered over the gap, not
## that there was none.
##
## §5's claim is about the record, not the drawing: `incoming.end ≡ C ≡
## outgoing.start`. So the only faithful test is the published `end_height_meters`
## of the leg into a contact against the published `start_height_meters` of the
## leg out of it. Nothing here consults presentation.
##
## The second column matters as much as the first. A family can agree with itself
## because *neither* end was ever resolved -- two 1.0 m defaults agree perfectly
## -- so every row also reports how many of its legs actually said they knew.
## That is the criterion the old census lacked: it counted whether a height had
## an owner, never whether the two legs agreed, and never whether an agreement
## was made of two facts or two defaults.

const MANAGER := preload("res://scripts/managers/game_manager.gd")
const EVENT := preload("res://scripts/models/rally_event.gd")
const RALLIES: int = 240
const TOLERANCE_METERS: float = 0.01

## Action events publish no flight and must not be read as a contact standing
## between two -- FD-009's defect, kept out by construction here.
const BALL_CONTACTS: Array[String] = [
	"SERVE", "RECEPTION", "SET", "ATTACK", "BLOCK", "DIG", "ATTACK_COVERAGE",
]


func _initialize() -> void:
	var rows := {}
	for index in range(RALLIES):
		var manager = MANAGER.new()
		manager.seed_vertical_slice_data()
		manager.match_state.serving_home = index % 2 == 0
		var result: Resource = manager.resolve_active_rally(31000 + index)
		if result == null:
			continue
		for raw in result.events:
			var event: Resource = raw
			if event == null:
				continue
			var family := str(EVENT.EventType.keys()[int(event.event_type)])
			if not family in BALL_CONTACTS:
				continue
			var incoming: Dictionary = event.metadata.get(
				"incoming_trajectory", {}
			)
			var outgoing: Dictionary = event.metadata.get(
				"outgoing_trajectory", {}
			)
			if incoming.is_empty() or outgoing.is_empty():
				continue
			var into := float(incoming.get("end_height_meters", NAN))
			var out_of := float(outgoing.get("start_height_meters", NAN))
			if is_nan(into) or is_nan(out_of):
				continue
			if not rows.has(family):
				rows[family] = {
					"legs": 0, "breaks": 0, "total": 0.0, "worst": 0.0,
					"both_known": 0,
				}
			var row: Dictionary = rows[family]
			var gap := absf(into - out_of)
			row["legs"] = int(row["legs"]) + 1
			row["total"] = float(row["total"]) + gap
			row["worst"] = maxf(float(row["worst"]), gap)
			if gap > TOLERANCE_METERS:
				row["breaks"] = int(row["breaks"]) + 1
			## An agreement between two records that both say they know is worth
			## something. An agreement between two defaults is worth nothing, and
			## reads identically in the gap column.
			if str(incoming.get("height_source", "default")) in [
				"resolved", "start_resolved"
			] and str(outgoing.get("height_source", "default")) in [
				"resolved", "start_resolved"
			]:
				row["both_known"] = int(row["both_known"]) + 1
	_report(rows)
	quit()


func _report(rows: Dictionary) -> void:
	print("\n%d rallies, both serving sides. Published legs only." % RALLIES)
	print("\n%-17s %6s %8s %10s %9s %11s" % [
		"contact", "legs", "breaks", "mean gap", "worst", "both known",
	])
	var families: Array = rows.keys()
	families.sort()
	var total_legs := 0
	var total_breaks := 0
	var total_known := 0
	for family in families:
		var row: Dictionary = rows[family]
		var legs := int(row["legs"])
		total_legs += legs
		total_breaks += int(row["breaks"])
		total_known += int(row["both_known"])
		print("%-17s %6d %8d %10.4f %9.4f %10d%%" % [
			family, legs, int(row["breaks"]),
			float(row["total"]) / float(legs), float(row["worst"]),
			roundi(float(row["both_known"]) / float(legs) * 100.0),
		])
	print("\n%-17s %6d %8d %10s %9s %10d%%" % [
		"ALL", total_legs, total_breaks, "", "",
		roundi(float(total_known) / float(maxi(total_legs, 1)) * 100.0),
	])
	print("\nA break is a published gap over %.2f m at one contact." % [
		TOLERANCE_METERS,
	])
