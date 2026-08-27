extends SceneTree

## Does the drawn ball tell the truth the resolver published?
##
## `BallPresentation.display_trajectory` is the whole drawn flight, and it takes
## only the event, the next contact, the authoritative trajectory and the
## bodies -- so the ball the viewer sees can be rebuilt exactly, headless,
## without the app. That is what makes M8's visual layer machine-checkable at
## all, and this is the instrument that does it.
##
## Three questions, none of them about aesthetics:
##
##   SEAM     leg N ends at a height; leg N+1 starts at one. A ball that is
##            drawn arriving at 0.62 m and leaving from 0.12 m has jumped, and
##            the viewer sees a teleport. This is the general form of the
##            reported witness and of the recorded "ball jump at a seam".
##   FLOOR    a contact nobody made is a ball that reached the floor. It must be
##            drawn arriving at the floor, not at the height the body that
##            missed it would have played from.
##   REACH    the drawn contact position against the actor's published body
##            position, so a ball is not drawn being played from where nobody
##            stood.
##
## Reported per contact family and per side, because three home/opponent drifts
## in this engine were each one side quietly not doing what its twin did.

const MANAGER := preload("res://scripts/managers/game_manager.gd")
const BallPresentationScript := preload("res://scripts/simulation/ball_presentation.gd")

## Two heights this far apart at one seam are a visible jump rather than a
## rounding difference. 5 cm is well under a ball radius.
const SEAM_TOLERANCE_METERS: float = 0.05


func _initialize() -> void:
	var rows := {}
	var seam_worst := 0.0
	var seam_worst_label := ""
	var block_touched := 0
	var block_touched_breaks := 0
	var block_missed := 0
	var block_missed_breaks := 0
	var floor_worst := 0.0
	var floor_worst_label := ""
	for side_index in range(2):
		var serving_home := side_index == 0
		for index in range(90):
			var manager = MANAGER.new()
			manager.seed_vertical_slice_data()
			manager.match_state.serving_home = serving_home
			var result: Resource = manager.resolve_active_rally(400000 + index)
			if result == null:
				continue
			var profiles: Dictionary = result.player_physical_profiles
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
			var previous_label := ""
			for position in range(contacts.size()):
				var event: RallyEvent = contacts[position]
				var next_contact: RallyEvent = (
					contacts[position + 1] if position + 1 < contacts.size() else null
				)
				var trajectory: Dictionary = event.metadata.get("outgoing_trajectory", {})
				if trajectory.is_empty():
					trajectory = event.metadata.get("trajectory", {})
				var display: Dictionary = BallPresentationScript.display_trajectory(
					event, next_contact, trajectory, profiles
				)
				var start_height := float(display.get("start_height_meters", NAN))
				var end_height := float(display.get("end_height_meters", NAN))
				var family := str(RallyEvent.EventType.keys()[int(event.event_type)])
				var key := "%s/%s" % [family, "home" if serving_home else "opponent"]
				if not rows.has(key):
					rows[key] = {
						"legs": 0, "seam_breaks": 0, "floor_breaks": 0,
						"untouched": 0, "seam_total": 0.0,
					}
				var row: Dictionary = rows[key]
				row["legs"] = int(row["legs"]) + 1

				## SEAM. The previous leg's arrival height against this leg's
				## departure height, for the same ball.
				if not is_nan(previous_end) and not is_nan(start_height):
					var jump := absf(previous_end - start_height)
					row["seam_total"] = float(row["seam_total"]) + jump
					if jump > SEAM_TOLERANCE_METERS:
						row["seam_breaks"] = int(row["seam_breaks"]) + 1
						if jump > seam_worst:
							seam_worst = jump
							seam_worst_label = "%s -> %s" % [previous_label, family]
				## A block the ball went past is not a seam at all: the leg into
				## it does not end there, it carries on to the floor or to a
				## digger. Counted apart so the block's residual can be read as
				## what it is rather than as a contact that fails to line up.
				if int(event.event_type) == RallyEvent.EventType.BLOCK \
						and not is_nan(previous_end) and not is_nan(start_height):
					var touched := not str(
						event.metadata.get("block_contact_kind", "")
					).is_empty()
					var broke := absf(previous_end - start_height) \
						> SEAM_TOLERANCE_METERS
					if touched:
						block_touched += 1
						if broke:
							block_touched_breaks += 1
					else:
						block_missed += 1
						if broke:
							block_missed_breaks += 1

				## FLOOR. A next contact that did not touch the ball is a ball
				## that reached the floor, so the leg into it must arrive there.
				if next_contact != null and not bool(next_contact.success):
					row["untouched"] = int(row["untouched"]) + 1
					var above := end_height - BallPresentationScript.FLOOR_CONTACT_HEIGHT_METERS
					if above > SEAM_TOLERANCE_METERS:
						row["floor_breaks"] = int(row["floor_breaks"]) + 1
						if above > floor_worst:
							floor_worst = above
							floor_worst_label = "%s -> missed %s" % [
								family,
								str(RallyEvent.EventType.keys()[
									int(next_contact.event_type)
								]),
							]
				previous_end = end_height
				previous_label = family
	_report(rows, seam_worst, seam_worst_label, floor_worst, floor_worst_label)
	print("")
	print("block seams, split by whether a hand met the ball")
	print("  the ball was met       %4d legs, %d break" % [
		block_touched, block_touched_breaks,
	])
	print("  the ball went past     %4d legs, %d break" % [
		block_missed, block_missed_breaks,
	])


func _report(
	rows: Dictionary, seam_worst: float, seam_worst_label: String,
	floor_worst: float, floor_worst_label: String
) -> void:
	print("%-26s %6s %6s %10s %10s %10s" % [
		"family/serving side", "legs", "untch", "seam brk", "mean seam", "floor brk",
	])
	var keys: Array = rows.keys()
	keys.sort()
	var total_seam := 0
	var total_floor := 0
	var total_legs := 0
	for key in keys:
		var row: Dictionary = rows[key]
		var legs := maxi(int(row["legs"]), 1)
		total_seam += int(row["seam_breaks"])
		total_floor += int(row["floor_breaks"])
		total_legs += int(row["legs"])
		print("%-26s %6d %6d %10d %10.3f %10d" % [
			str(key), int(row["legs"]), int(row["untouched"]),
			int(row["seam_breaks"]), float(row["seam_total"]) / float(legs),
			int(row["floor_breaks"]),
		])
	print("")
	print("legs drawn                         %d" % total_legs)
	print("seam height jumps > %.2f m         %d" % [SEAM_TOLERANCE_METERS, total_seam])
	print("  worst %.3f m at %s" % [seam_worst, seam_worst_label])
	print("untouched balls not drawn to floor %d" % total_floor)
	print("  worst %.3f m above floor at %s" % [floor_worst, floor_worst_label])
	quit(0)
