extends SceneTree

## Build every selected regional strip on every body family.
##
## This is the structural companion to `render_all_kits.gd`: the gallery proves
## the designs read, while this proves all 84 combinations build real geometry
## and that Vegi carry regional marks only on clothing, never on produce.

const ACTOR_SCENE := preload("res://scenes/components/player_actor_3d.tscn")
const RegionalKitsScript := preload("res://scripts/data/regional_kits.gd")

const PROFILES := [
	{"body_type": "Vegi", "height_cm": 188.0, "wingspan_cm": 188.0,
		"mass_kg": 82.0, "appearance": {"produce": "Stalk", "marking": "none"}},
	{"body_type": "Feli", "height_cm": 188.0, "wingspan_cm": 191.0, "mass_kg": 82.0},
	{"body_type": "Avi", "height_cm": 204.0, "wingspan_cm": 212.0, "mass_kg": 70.0},
	{"body_type": "Cani", "height_cm": 171.0, "wingspan_cm": 168.0, "mass_kg": 74.0},
	{"body_type": "Ursi", "height_cm": 196.0, "wingspan_cm": 201.0, "mass_kg": 112.0},
	{"body_type": "Simi", "height_cm": 183.0, "wingspan_cm": 218.0, "mass_kg": 78.0},
]


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(64, 64)
	viewport.own_world_3d = true
	root.add_child(viewport)
	var failures: Array[String] = []
	var built := 0
	for region_raw in RegionalKitsScript.KITS:
		var region := str(region_raw)
		for profile_raw in PROFILES:
			var profile: Dictionary = profile_raw.duplicate(true)
			profile["club_region"] = region
			profile["champion_region"] = "Xérvu"
			var actor := ACTOR_SCENE.instantiate()
			viewport.add_child(actor)
			actor.configure(90210, true, str(profile.body_type), "Right", profile)
			await process_frame
			var marks: Array = actor._kit_marks()
			if marks.is_empty():
				failures.append("%s %s built no kit marks" % [region, profile.body_type])
			for mark_raw in marks:
				var mark := mark_raw as MeshInstance3D
				if mark == null or mark.mesh == null or mark.mesh.get_aabb().size.length() <= 0.0:
					failures.append("%s %s built an empty mark" % [region, profile.body_type])
			if str(profile.body_type) == "Vegi":
				var torso := actor.get_node("BodyPivot/Torso")
				for mark_raw in marks:
					var mark := mark_raw as MeshInstance3D
					if mark != null and mark.get_parent() == torso:
						failures.append("%s paints a mark onto Vegi produce" % region)
			built += 1
			viewport.remove_child(actor)
			actor.free()
	print("built %d regional kit/body combinations" % built)
	for failure in failures:
		push_error(failure)
	print("%d structural failures" % failures.size())
	quit(1 if not failures.is_empty() else 0)
