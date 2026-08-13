extends Node

## What an obstructed run looks like in the 3D court.
##
##     xvfb-run -a godot --path . res://tools/obstruction_shot.tscn
##
## The probe next door counts obstructions; this one has to *show* one, because
## a route model that bends a path nobody can see is indistinguishable from one
## that does nothing.
##
## Four frames of the same leg, because a corner is a change of direction and a
## change of direction cannot be seen in a single frame. The setter and the body
## they go round are both drawn; if the run is straight through the obstruction
## in any frame, `_plan_sample` is not honouring the waypoint and the whole
## thing is inert.
##
## The plan is `MatchCourt3D`'s own -- `apply_movement_plan` with the same
## `waypoint` key `match_screen.gd` fills in from the event. Building the plan
## by hand here would prove the shot works and nothing about the game.

const SHOT_DIRECTORY := "user://obstruction_shot"
const SEARCH_RALLIES: int = 400
## Small bends exist in bulk -- the probe's median is 0.199 m -- and a 0.2 m
## corner is real but not legible in a still. The shot wants a clear one.
const MINIMUM_DETOUR_METERS: float = 0.45
const MOMENTS: Array[float] = [0.0, 0.34, 0.67, 1.0]


func _ready() -> void:
	await get_tree().process_frame
	await _shoot()
	get_tree().quit()


func _shoot() -> void:
	var career_manager: Node = get_node("/root/CareerManager")
	var game_manager: Node = get_node("/root/GameManager")
	var error: String = career_manager.create_career(
		"Obstruction Shot", "Probe VC", "Landavol", "Established", "Balanced"
	)
	if not error.is_empty():
		print("could not start a career: %s" % error)
		return
	DirAccess.make_dir_recursive_absolute(SHOT_DIRECTORY)

	var found: Dictionary = _find_obstructed_rally(game_manager)
	if found.is_empty():
		print("no obstructed second contact in %d rallies" % SEARCH_RALLIES)
		return
	var set_event: Resource = found["event"]
	var start := Vector2(set_event.metadata["movement_start"])
	var corner := Vector2(set_event.metadata["navigation_waypoint"])
	var target: Vector2 = set_event.start_position
	var blocker_id := int(set_event.metadata.get("obstructed_by", -1))
	var blocker_at := Vector2(set_event.metadata.get(
		"obstruction_position", Vector2.ZERO
	))
	var window := float(set_event.metadata.get("movement_duration", 1.0))
	print("=== obstructed second contact, seed %d" % int(found["seed"]))
	print("setter        %s (#%d)" % [set_event.actor_name, int(set_event.actor_id)])
	print("start         %s" % str(start))
	print("corner        %s" % str(corner))
	print("contact       %s" % str(target))
	print("in the way    #%d at %s, %.3f m short of clearance" % [
		blocker_id, str(blocker_at),
		float(set_event.metadata.get("obstruction_shortfall_meters", 0.0)),
	])
	print("detour        %.3f m off the straight line" % float(found["detour"]))
	print("travel        %.3f s" % window)

	var court = load("res://scenes/components/match_court_3d.tscn").instantiate()
	add_child(court)
	await get_tree().process_frame

	var setter: VolleyballPlayer = game_manager.player_by_id(int(set_event.actor_id))
	var obstructor: VolleyballPlayer = game_manager.player_by_id(blocker_id)
	court.ensure_player(
		int(set_event.actor_id), start, true, set_event.actor_name,
		str(setter.dominant_hand) if setter != null else "Right",
		_body(setter),
	)
	if obstructor != null:
		court.ensure_player(
			blocker_id, blocker_at, true, obstructor.display_name,
			str(obstructor.dominant_hand), _body(obstructor),
		)
		court.set_player_position(blocker_id, blocker_at)

	## Exactly the shape `match_screen.gd` builds: start, target, and the corner
	## under the key the 3D court's `_plan_sample` reads.
	var plan := {
		int(set_event.actor_id): {
			"start": start, "target": target, "waypoint": corner,
			"seconds": window,
		},
	}
	for index in range(MOMENTS.size()):
		court.apply_movement_plan(plan, MOMENTS[index], window)
		for _settle in range(3):
			await get_tree().process_frame
		var where: Vector2 = court.live_positions.get(int(set_event.actor_id), start)
		var straight := Geometry2D.get_closest_point_to_segment(
			blocker_at, start, target
		)
		print("  t=%.2f  setter at %s  %.2f m from the body in the way" % [
			MOMENTS[index], str(where),
			RallyKinematics.court_delta_meters(where, blocker_at).length(),
		])
		if index == 0:
			print("  (straight line passes %.2f m from them)"
				% RallyKinematics.court_delta_meters(straight, blocker_at).length())
		var path := "%s/obstructed_run_%02d.png" % [
			SHOT_DIRECTORY, int(MOMENTS[index] * 100.0)
		]
		get_viewport().get_texture().get_image().save_png(path)
	print("wrote %d frames to %s"
		% [MOMENTS.size(), ProjectSettings.globalize_path(SHOT_DIRECTORY)])


func _body(player: VolleyballPlayer) -> Dictionary:
	if player == null:
		return {}
	## `height_cm`, not `height_meters`: `_apply_physical_profile` reads the
	## former and silently falls back to the reference height for the latter.
	return {
		"height_cm": player.height_cm,
		"wingspan_cm": player.wingspan_cm,
		"body_type": str(player.body_type),
		"position_code": str(player.primary_position),
	}


## The first rally whose second contact had to go round somebody by a margin
## big enough to read in a still.
func _find_obstructed_rally(game_manager: Node) -> Dictionary:
	for index in range(SEARCH_RALLIES):
		var seed_value := hash("obstructionshot|%d" % index)
		var result: Resource = game_manager.resolve_active_rally(seed_value)
		if result == null or result.events.is_empty():
			continue
		for position in range(result.events.size()):
			var event: Resource = result.events[position]
			if event == null \
					or int(event.event_type) != RallyEvent.EventType.SET \
					or not event.metadata.has("navigation_waypoint") \
					or not event.metadata.has("movement_start"):
				continue
			var start := Vector2(event.metadata["movement_start"])
			var corner := Vector2(event.metadata["navigation_waypoint"])
			var straight := Geometry2D.get_closest_point_to_segment(
				corner, start, event.start_position
			)
			var detour := RallyKinematics.court_delta_meters(corner, straight).length()
			if detour < MINIMUM_DETOUR_METERS:
				continue
			return {
				"result": result, "event": event, "seed": seed_value,
				"detour": detour,
			}
	return {}
