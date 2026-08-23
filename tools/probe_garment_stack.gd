extends SceneTree

## What is painted where, from the waist down.
##
## The rendered body shows three horizontal bands below the chest and it is not
## obvious from the picture which mesh owns which. Guessing from a render is how
## the last four defects in this file survived, so this prints every torso-region
## mesh with the height range it actually occupies and the colour it is actually
## wearing.

const ACTOR_SCENE := preload("res://scenes/components/player_actor_3d.tscn")


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
		"body_type": "Feli", "club_region": "Ĭspayk",
		"appearance": {"palette_index": 0, "marking": "none", "build": "heavy"},
		"height_cm": 188.0, "wingspan_cm": 191.0,
	})
	await process_frame
	print("%-46s %8s %8s %10s %s" % ["path", "low_y", "high_y", "span", "albedo"])
	var rows: Array = []
	_collect(actor, rows)
	rows.sort_custom(func(a, b): return float(a[1]) > float(b[1]))
	for row in rows:
		print("%-46s %8.3f %8.3f %10.3f %s" % [
			str(row[0]), float(row[1]), float(row[2]),
			float(row[2]) - float(row[1]), str(row[3]),
		])
	## The bones the garments have to land between, which no mesh bound can give:
	## a cuff that should stop above the knee needs to know where the knee is.
	for path in ["BodyPivot/LeftLeg", "BodyPivot/LeftLeg/Knee", "BodyPivot/LeftArm",
			"BodyPivot/LeftArm/Elbow"]:
		var bone := actor.get_node_or_null(path) as Node3D
		if bone != null:
			print("%-24s y %.3f" % [path, bone.global_transform.origin.y])
	quit()


func _collect(node: Node, rows: Array) -> void:
	for child in node.get_children():
		var mesh := child as MeshInstance3D
		if mesh != null and mesh.mesh != null and str(mesh.name) != "Ink":
			var name := str(mesh.name)
			## Only the trunk region; limbs and head are not in question here.
			if name in ["Torso", "Shorts", "Shoe", "Neck"] \
					or name.begins_with("ShortsLeg") or name.begins_with("Sleeve") \
					or name.begins_with("Collar") or name.begins_with("Joint"):
				var aabb := mesh.mesh.get_aabb()
				var basis := mesh.global_transform.basis
				var origin := mesh.global_transform.origin
				var low := INF
				var high := -INF
				for i in range(8):
					var y := (origin + basis * aabb.get_endpoint(i)).y
					low = minf(low, y)
					high = maxf(high, y)
				var material := mesh.material_override as StandardMaterial3D
				rows.append([
					"%s/%s" % [str(mesh.get_parent().name), name], low, high,
					material.albedo_color.to_html(false) if material != null else "?",
				])
		_collect(child, rows)
