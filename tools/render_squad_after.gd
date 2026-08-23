extends SceneTree

## Ten Simi colourways, each drawn twice: bare, and wearing the family's own
## subtlest coat. Speckle is the stress test -- the mark ink flips derivation at
## a coat luminance of 0.22, so a ladder that runs near-black to cream crosses
## that boundary and shows whether the mark survives at both ends.

const ACTOR_SCENE := preload("res://scenes/components/player_actor_3d.tscn")
const BodyTypeModelsScript := preload("res://scripts/data/body_type_models.gd")

const FAMILIES := ["Feli", "Cani", "Avi", "Ursi", "Simi", "Vegi"]
const PALETTE_COUNT: int = 10
const OUTPUT_DIR := "res://artifacts/squad-after"
const FOCUS := Vector3(0.0, 1.82, 0.0)


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	var viewport := SubViewport.new()
	viewport.size = Vector2i(512, 512)
	viewport.transparent_bg = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.own_world_3d = true
	root.add_child(viewport)
	var world := World3D.new()
	viewport.world_3d = world
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.0, 0.0, 0.0, 0.0)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("ffffff")
	environment.ambient_light_energy = 0.74
	world.environment = environment
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 0.92
	camera.position = FOCUS + Vector3(0.0, 0.0, -4.2)
	viewport.add_child(camera)
	camera.look_at(FOCUS, Vector3.UP)
	camera.current = true
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-34.0, -30.0, 0.0)
	key.light_energy = 1.08
	viewport.add_child(key)
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-18.0, 140.0, 0.0)
	fill.light_energy = 0.40
	viewport.add_child(fill)

	var actor := ACTOR_SCENE.instantiate()
	viewport.add_child(actor)
	(actor.get_node("Shadow") as Node3D).visible = false
	(actor.get_node("FocusRing") as Node3D).visible = false
	(actor.get_node("IdentityLabel") as Node3D).visible = false

	## A squad the way the world makes one: family from an RNG exactly as
	## `PlayerGenerator.assign_body_type` does, and produce/colourway/coat all
	## hashed off the voli's own id.
	var rng := RandomNumberGenerator.new()
	rng.seed = 20260822
	print("%-3s %-6s %-10s %-9s %s" % ["#", "family", "skin", "coat", "produce"])
	var seen := {}
	for index in range(12):
		var player_id: int = 77000 + index * 13
		var family: String = str(FAMILIES[rng.randi_range(0, FAMILIES.size() - 1)])
		actor.configure(player_id, true, "V%d" % index, "Right", {
			"body_type": family, "appearance": {},
			"height_cm": 188.0, "wingspan_cm": 191.0,
		})
		actor.rotation_degrees = Vector3(0.0, 30.0, 0.0)
		for _settle in range(4):
			await process_frame
		await RenderingServer.frame_post_draw
		var sil: Dictionary = actor.silhouette
		var skin: Color = sil.get("skin", Color.BLACK)
		var coat := str(BodyTypeModelsScript.marking_for(family, player_id))
		var produce := str(sil.get("produce", "-"))
		seen["%s|%s|%s" % [family, skin.to_html(false), produce]] = true
		print("%-3d %-6s %-10s %-9s %s" % [
			index, family, skin.to_html(false), coat, produce])
		var image := viewport.get_texture().get_image()
		image.save_png("%s/%02d_%s.png" % [OUTPUT_DIR, index, family.to_lower()])
	print("--- %d distinct (family, colour, produce) looks in a squad of 12" % seen.size())
	quit()
