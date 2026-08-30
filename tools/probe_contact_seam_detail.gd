extends SceneTree

## Which *side* of a breaking contact is the one that does not know?
##
## `run_published_seam_census.gd` reports the gap and whether both legs claimed
## to know their heights, which is enough to say a family is broken and not
## enough to say what to repair. A 2.08 m mean at ATTACK is one of two stories:
## the leg in and the leg out each resolved a height and disagree, or one of
## them fell back to `BallTrajectory.create`'s 1.0 m default and the "gap" is
## just that default against a real number. Those want opposite repairs.
##
## So this prints both ends of the same contact with the source each leg
## published, for the first few of each family.

const MANAGER := preload("res://scripts/managers/game_manager.gd")
const EVENT := preload("res://scripts/models/rally_event.gd")
const RALLIES: int = 40
const PER_FAMILY: int = 3


func _initialize() -> void:
	var shown := {}
	for index in range(RALLIES):
		var manager = MANAGER.new()
		manager.seed_vertical_slice_data()
		manager.match_state.serving_home = index % 2 == 0
		var result: Resource = manager.resolve_active_rally(41000 + index)
		if result == null:
			continue
		for raw in result.events:
			var event: Resource = raw
			if event == null:
				continue
			var family := str(EVENT.EventType.keys()[int(event.event_type)])
			if int(shown.get(family, 0)) >= PER_FAMILY:
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
			if absf(into - out_of) <= 0.01:
				continue
			shown[family] = int(shown.get(family, 0)) + 1
			print("%-16s actor=%-4d gap %.3f m" % [
				family, int(event.actor_id), absf(into - out_of),
			])
			print("    in  %-18s ends   %.3f m   source=%-14s kind=%s" % [
				str(incoming.get("trajectory_type", "?")), into,
				str(incoming.get("height_source", "default")),
				str(incoming.get("trajectory_role", "-")),
			])
			print("    out %-18s starts %.3f m   source=%-14s kind=%s" % [
				str(outgoing.get("trajectory_type", "?")), out_of,
				str(outgoing.get("height_source", "default")),
				str(outgoing.get("trajectory_role", "-")),
			])
			var stated: Variant = event.metadata.get(
				"contact_height_meters",
				event.metadata.get("ball_contact_height", null),
			)
			if stated != null:
				print("    the event itself says the contact was at %.3f m" % [
					float(stated),
				])
	quit()
