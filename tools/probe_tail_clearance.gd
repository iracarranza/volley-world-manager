extends SceneTree

## Does the tail hang below the kit?
##
## Also: does the torso end inside the shorts, or does its lower cap hang out of
## them? The shorts are a *section of the torso profile* positioned so their
## bottom aligns with the torso's -- two surfaces meeting exactly, which is never
## what "inside" means and is a coin-flip for whichever wins the depth test.
##
## "Not visible from beneath" is two different claims and only one of them is
## reasonable. A tail that *sweeps back* will always appear outside the body's
## plan outline when viewed from directly underneath -- that is just a tail
## existing. What the shorts hem is entitled to is that nothing dangles *below*
## it. So the measurement is a height comparison, not a silhouette test.

const ACTOR_SCENE := preload("res://scenes/components/player_actor_3d.tscn")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(64, 64)
	viewport.own_world_3d = true
	root.add_child(viewport)
	print("%-6s %10s %10s %10s %10s  %s" % [
		"body", "tail_low", "shorts_hem", "torso_low", "clearance", "verdict",
	])
	for family in ["Feli", "Cani"]:
		var actor := ACTOR_SCENE.instantiate()
		viewport.add_child(actor)
		actor.configure(90210, true, family, "Right", {
			"body_type": family, "club_region": "Ĭspayk",
			"appearance": {"palette_index": 0, "marking": "none", "build": "heavy"},
			"height_cm": 188.0, "wingspan_cm": 191.0,
		})
		await process_frame
		var tail_low := _lowest(actor, "Tail")
		var hem := _lowest(actor, "ShortsLegLeft")
		var torso_low := _lowest(actor, "Torso")
		var clearance := torso_low - hem
		print("%-6s %10.3f %10.3f %10.3f %10.3f  %s" % [
			family, tail_low, hem, torso_low, clearance,
			"torso ends inside the shorts" if clearance >= 0.0 \
				else "TORSO EXTRUDES %.3f m below the shorts" % -clearance,
		])
		viewport.remove_child(actor)
		actor.free()
	quit()


## The lowest point of a named mesh in the actor's own space, from its real
## transformed bounds rather than from the position it was authored at -- a
## rotated cylinder's low end is nowhere near its origin.
func _lowest(node: Node, mesh_name: String) -> float:
	var found := node.find_child(mesh_name, true, false) as MeshInstance3D
	if found == null or found.mesh == null:
		return NAN
	var aabb := found.mesh.get_aabb()
	var basis := found.global_transform.basis
	var origin := found.global_transform.origin
	var lowest := INF
	for i in range(8):
		lowest = minf(lowest, (origin + basis * aabb.get_endpoint(i)).y)
	return lowest
