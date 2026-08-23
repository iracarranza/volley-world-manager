extends SceneTree

## Where does the drawn ball stop when nothing plays it next?
##
## A leg with no next contact is a ball on its way to the floor. If the drawn
## flight ends above the floor, playback holds it there for `settle_seconds` and
## then `hold_at_rest()` puts it down -- a hang and a snap, which is the reported
## witness. A constructed fixture showed 1.33 m of it, but that fixture's
## duration was chosen by hand, so the number that matters is this one.

const MANAGER := preload("res://scripts/managers/game_manager.gd")
const BP := preload("res://scripts/simulation/ball_presentation.gd")

func _initialize() -> void:
	var above := 0
	var total := 0
	var worst := 0.0
	var worst_family := ""
	var sum := 0.0
	for side_index in range(2):
		for index in range(90):
			var manager = MANAGER.new()
			manager.seed_vertical_slice_data()
			manager.match_state.serving_home = side_index == 0
			var result: Resource = manager.resolve_active_rally(500000 + index)
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
			if contacts.is_empty():
				continue
			var last: RallyEvent = contacts[-1]
			var trajectory: Dictionary = last.metadata.get("outgoing_trajectory", {})
			if trajectory.is_empty():
				continue
			var display: Dictionary = BP.display_trajectory(
				last, null, trajectory, profiles
			)
			var end_height := float(display.get("end_height_meters", NAN))
			if is_nan(end_height):
				continue
			total += 1
			var gap := end_height - BP.FLOOR_CONTACT_HEIGHT_METERS
			sum += maxf(gap, 0.0)
			if gap > 0.05:
				above += 1
				if gap > worst:
					worst = gap
					worst_family = str(RallyEvent.EventType.keys()[int(last.event_type)])
	print("terminal legs measured              %d" % total)
	print("  drawn stopping above the floor    %d" % above)
	print("  mean height above floor           %.3f m" % (sum / float(maxi(total, 1))))
	print("  worst                             %.3f m on a %s" % [worst, worst_family])
	quit(0)
