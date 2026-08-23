extends SceneTree

## How far up the body does a mark actually reach, and how much does it converge?
##
## Two complaints that sound different and may be one thing: stripes "floating
## under the head", and panels showing "clear delineation" in their curve. Both
## are about the top of a tall mark, so this reports where the topmost segment
## of each pattern sits against the landmarks it should not reach -- the neck and
## the shoulder ball -- and how far the mark has pulled inward getting there.

const ACTOR_SCENE := preload("res://scenes/components/player_actor_3d.tscn")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(64, 64)
	viewport.own_world_3d = true
	root.add_child(viewport)
	for region in ["Pāwa Hitō", "Blôc du Larg", "Rhėn Tempaol", "Tãul ys Feynt"]:
		var actor := ACTOR_SCENE.instantiate()
		viewport.add_child(actor)
		actor.configure(90210, true, "Feli", "Right", {
			"body_type": "Feli", "club_region": region,
			"appearance": {"palette_index": 0, "marking": "none", "build": "heavy"},
			"height_cm": 188.0, "wingspan_cm": 191.0,
		})
		await process_frame
		var torso := actor.get_node("BodyPivot/Torso") as MeshInstance3D
		var neck := actor.find_child("Neck", true, false) as MeshInstance3D
		var shoulder := actor.get_node("BodyPivot/LeftArm/Joint") as MeshInstance3D
		var torso_top := _top(torso)
		var neck_low := _low(neck)
		var shoulder_top := _top(shoulder)
		var mark_top := -INF
		## **Standoff, not node position.**
		##
		## This used to read `mark.position` and report the spread of those. That
		## measured something real while a mark was a stack of boxes, each one
		## placed at its own radius -- and measures *nothing* now that a mark is a
		## patch whose vertices carry the curve and whose node sits at the origin.
		## It printed `0.000..0.000, convergence 100.0%` for every region without
		## failing, which is the instrument this repository keeps being caught by:
		## a number that still prints after the thing it was reading went away.
		##
		## So the question is asked of the geometry instead, and asked the way the
		## defect was actually visible: how far is each vertex of a mark from the
		## body's own surface at that vertex's height? A mark lying on the shirt
		## holds one standoff down its whole length. A mark that steps, floats or
		## sinks does not, and the spread says by how much.
		var capsule := torso.mesh as CapsuleMesh
		var body_radius := capsule.radius if capsule != null else 0.308
		var body_semi := (capsule.height * 0.5) if capsule != null else 0.438
		var closest := INF
		var furthest := -INF
		for child in torso.get_children():
			var mark := child as MeshInstance3D
			if mark == null or not mark.has_meta("kit_mark"):
				continue
			mark_top = maxf(mark_top, _top(mark))
			for vertex in mark.mesh.get_faces():
				var surface := _capsule_radius(body_radius, body_semi, vertex.y)
				var stand := Vector2(vertex.x, vertex.z).length() - surface
				closest = minf(closest, stand)
				furthest = maxf(furthest, stand)
		print("%-15s torso top %.3f  neck low %.3f  shoulder top %.3f" % [
			region, torso_top, neck_low, shoulder_top,
		])
		print("%-15s mark top  %.3f  -> %s" % [
			"", mark_top,
			"clear" if mark_top < shoulder_top else "REACHES THE SHOULDER",
		])
		print("%-15s standoff %+.4f..%+.4f m (spread %.4f)" % [
			"", closest, furthest, furthest - closest,
		])
		viewport.remove_child(actor)
		actor.free()
	quit()


## The body's own half-width at a height, in the torso mesh's local frame.
##
## Restated here rather than borrowed from `BodyTypeModels._torso_radius_at`,
## because a probe that asks production for the answer it is checking cannot
## catch production being wrong about it -- which is how the capsule branch was
## missing for as long as it was.
func _capsule_radius(radius: float, semi: float, up: float) -> float:
	var straight := maxf(semi - radius, 0.0)
	var y := absf(up)
	if y <= straight:
		return radius
	var into_cap := minf(y - straight, radius)
	return radius * sqrt(maxf(1.0 - pow(into_cap / radius, 2.0), 0.04))


func _top(mesh: MeshInstance3D) -> float:
	return _extent(mesh, true)


func _low(mesh: MeshInstance3D) -> float:
	return _extent(mesh, false)


func _extent(mesh: MeshInstance3D, high: bool) -> float:
	if mesh == null or mesh.mesh == null:
		return NAN
	var aabb := mesh.mesh.get_aabb()
	var basis := mesh.global_transform.basis
	var origin := mesh.global_transform.origin
	var best := -INF if high else INF
	for i in range(8):
		var y := (origin + basis * aabb.get_endpoint(i)).y
		best = maxf(best, y) if high else minf(best, y)
	return best
