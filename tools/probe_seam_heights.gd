extends SceneTree

## Why does the ball's height jump at a contact?
##
## The continuity baseline found 380 of 835 drawn legs arriving at one height
## and departing at another, worst 3.227 m at attack-to-block. A ball has one
## height at one moment, so two numbers for it is two authorities for one
## physical question -- but which of the two is wrong depends on how each was
## produced, and that is not visible in the aggregate. This prints the parts.

const MANAGER := preload("res://scripts/managers/game_manager.gd")
const BallPresentationScript := preload("res://scripts/simulation/ball_presentation.gd")


func _initialize() -> void:
	var shown := {}
	for index in range(60):
		var manager = MANAGER.new()
		manager.seed_vertical_slice_data()
		manager.match_state.serving_home = false
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
		for position in range(contacts.size() - 1):
			var event: RallyEvent = contacts[position]
			var next_contact: RallyEvent = contacts[position + 1]
			var pair := "%s->%s" % [
				str(RallyEvent.EventType.keys()[int(event.event_type)]),
				str(RallyEvent.EventType.keys()[int(next_contact.event_type)]),
			]
			if int(shown.get(pair, 0)) >= 2:
				continue
			var trajectory: Dictionary = event.metadata.get("outgoing_trajectory", {})
			if trajectory.is_empty():
				trajectory = event.metadata.get("trajectory", {})
			var display: Dictionary = BallPresentationScript.display_trajectory(
				event, next_contact, trajectory, profiles
			)
			var raw_duration := float(trajectory.get("duration", 0.0))
			var arrive := float(display.get("end_height_meters", NAN))
			## What the next leg will depart from, computed its own way.
			var depart := BallPresentationScript.contact_height(next_contact, profiles)
			if absf(arrive - depart) <= 0.05:
				continue
			shown[pair] = int(shown.get(pair, 0)) + 1
			print(
				"%-22s arrive %6.3f  depart %6.3f  gap %6.3f | start %5.2f dur %5.3f/%5.3f vert %s touched %s"
				% [
					pair, arrive, depart, absf(arrive - depart),
					float(display.get("start_height_meters", NAN)),
					float(display.get("duration", 0.0)), raw_duration,
					("%.2f" % float(display.launch_vertical_mps)) \
						if display.has("launch_vertical_mps") else " none",
					str(not Dictionary(
						next_contact.metadata.get("outgoing_trajectory", {})
					).is_empty()),
				]
			)
	quit(0)
