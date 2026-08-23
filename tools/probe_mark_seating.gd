extends SceneTree

## Does every kit mark actually touch the body it is on?
##
## The four patterns reported as "extending off the voli" were all tall ones, and
## the cause was one radius per mark on a body that is only that wide through its
## middle. This walks every built mark on every region and measures how far its
## own centre sits from the torso's surface at its own height. A seated mark is
## a few millimetres proud; a floating one is centimetres.

const ACTOR_SCENE := preload("res://scenes/components/player_actor_3d.tscn")
const RegionalKitsScript := preload("res://scripts/data/regional_kits.gd")
const BodyTypes := preload("res://scripts/data/body_type_models.gd")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(64, 64)
	viewport.own_world_3d = true
	root.add_child(viewport)
	print("%-15s %7s %8s %9s %9s  %s" % [
		"region", "marks", "proud", "max angle", "splay", "",
	])
	var bad := 0
	for region_raw in RegionalKitsScript.KITS:
		var region: String = str(region_raw)
		var actor := ACTOR_SCENE.instantiate()
		viewport.add_child(actor)
		actor.configure(90210, true, "Feli", "Right", {
			"body_type": "Feli", "club_region": region, "champion_region": "Xérvu",
			"appearance": {"palette_index": 0, "marking": "none", "build": "heavy"},
			"height_cm": 188.0, "wingspan_cm": 191.0,
		})
		await process_frame
		var torso_node := actor.get_node("BodyPivot/Torso") as MeshInstance3D
		var torso_spec: Dictionary = actor.silhouette.get("torso", {})
		var semi := float(torso_spec.get("height", 0.9)) * 0.5
		var worst := 0.0
		var widest := 0.0
		var splay := 0.0
		var count := 0
		## Grouped by authored mark, so `splay` is the bend *within* one mark --
		## the defect -- and not the spread between marks, which is the pattern.
		var lanes := {}
		for child in torso_node.get_children():
			var mark := child as MeshInstance3D
			if mark == null or not mark.has_meta("kit_mark"):
				continue
			## Distance from the body axis, against the surface at this height.
			var at: Vector3 = mark.position
			var out := Vector2(at.x, at.z).length()
			var surface := BodyTypes._torso_radius_at(
				torso_spec, at.y / maxf(semi, 0.001)
			)
			var gap := out - surface
			worst = maxf(worst, gap)
			var angle := rad_to_deg(atan2(absf(at.x), absf(at.z)))
			widest = maxf(widest, angle)
			## Segments of one authored mark share a name prefix; the spread of
			## angle within a mark is its splay, which should now be zero.
			var lane := str(mark.get_meta("kit_mark_lane", 0))
			if lanes.has(lane):
				splay = maxf(splay, absf(angle - float(lanes[lane])))
			else:
				lanes[lane] = angle
			count += 1
		if count > 0:
			print("%-15s %7d %8.3f %8.1f° %8.1f°  %s" % [
				region, count, worst, widest, splay,
				"ok" if worst < 0.02 and widest < 55.0 and splay < 3.0 \
					else "OFF",
			])
			if worst >= 0.02 or widest >= 55.0 or splay >= 3.0:
				bad += 1
		viewport.remove_child(actor)
		actor.free()
	print("")
	print("%d regions with a mark off the body, past 55 degrees, or splayed" % bad)
	quit()
