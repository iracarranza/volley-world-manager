extends SceneTree

## One Pāwa panel, segment by segment.
##
## Three guesses at the speckling have now been wrong -- the overlap, the
## coplanar z-fight, the seating depth -- so this stops guessing and prints what
## each segment actually is: where it sits, how wide it is, and how it relates to
## its neighbour. A defect that survives three plausible explanations is one
## nobody has looked at yet.

const ACTOR_SCENE := preload("res://scenes/components/player_actor_3d.tscn")
const BodyTypes := preload("res://scripts/data/body_type_models.gd")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(64, 64)
	viewport.own_world_3d = true
	root.add_child(viewport)
	var actor := ACTOR_SCENE.instantiate()
	viewport.add_child(actor)
	actor.configure(90210, true, "Feli", "Right", {
		"body_type": "Feli", "club_region": "Pāwa Hitō",
		"appearance": {"palette_index": 0, "marking": "none", "build": "heavy"},
		"height_cm": 188.0, "wingspan_cm": 191.0,
	})
	await process_frame
	var torso := actor.get_node("BodyPivot/Torso") as MeshInstance3D
	var torso_spec: Dictionary = actor.silhouette.get("torso", {})
	var semi := float(torso_spec.get("height", 0.9)) * 0.5
	var rows: Array = []
	for child in torso.get_children():
		var mark := child as MeshInstance3D
		if mark == null or int(mark.get_meta("kit_mark_lane", 0)) != 1:
			continue
		var box := mark.mesh as BoxMesh
		rows.append([mark.position, box.size, mark.rotation_degrees.y])
	rows.sort_custom(func(a, b): return Vector3(a[0]).y > Vector3(b[0]).y)
	print("%5s %8s %8s %8s %8s %8s  %s" % [
		"seg", "y", "width", "radial", "surface", "stand", "gap to next",
	])
	for i in range(rows.size()):
		var at: Vector3 = rows[i][0]
		var size: Vector3 = rows[i][1]
		var radial := Vector2(at.x, at.z).length()
		var surface := BodyTypes._torso_radius_at(torso_spec, at.y / semi)
		var gap := NAN
		if i + 1 < rows.size():
			var next_y := Vector3(rows[i + 1][0]).y
			var next_h := Vector3(rows[i + 1][1]).y
			gap = (at.y - size.y * 0.5) - (next_y + next_h * 0.5)
		print("%5d %8.3f %8.4f %8.4f %8.4f %8.4f  %8.5f" % [
			i, at.y, size.x, radial, surface, radial - surface, gap,
		])
	quit()
