extends SceneTree

## Can a player tell their own squad apart at roster scale?
##
## The mark gallery pins palette and produce so the marking is the only variable,
## which is right for testing a mark and wrong for testing identity. A voli the
## world generates picks its family at random and hashes produce, colourway and
## coat off its own id, so this renders volis the way the world makes them and
## lets the whole identity budget vary at once.

const ACTOR_SCENE := preload("res://scenes/components/player_actor_3d.tscn")
const BodyTypeModelsScript := preload("res://scripts/data/body_type_models.gd")

const SQUAD_SIZE: int = 12
const FIRST_ID: int = 41_000
const FAMILIES := ["Feli", "Cani", "Avi", "Ursi", "Simi", "Vegi"]
const OUTPUT_DIR := "res://artifacts/identity-budget"
const BAKE_SIZE := Vector2i(512, 512)
const FOCUS := Vector3(0.0, 1.82, 0.0)
const WORLD_HEIGHT: float = 0.92


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	var viewport := SubViewport.new()
	viewport.size = BAKE_SIZE
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
	camera.size = WORLD_HEIGHT
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

	var seen := {}
	print("%-6s %-3s %-9s %-10s %s" % ["family", "pal", "marking", "skin", "produce"])
	var index := 0
	for family_raw in FAMILIES:
		var family: String = str(family_raw)
		for palette_index in range(4):
			var player_id: int = 41000 + index * 37
			index += 1
			actor.configure(player_id, true, "V%d" % index, "Right", {
				"body_type": family,
				"appearance": {"palette_index": palette_index},
				"height_cm": 188.0, "wingspan_cm": 191.0,
			})
			actor.rotation_degrees = Vector3(0.0, 30.0, 0.0)
			for _settle in range(4):
				await process_frame
			await RenderingServer.frame_post_draw
			var silhouette: Dictionary = actor.silhouette
			var marking := str(BodyTypeModelsScript.marking_for(family, player_id))
			var skin: Color = silhouette.get("skin", Color.BLACK)
			seen[skin.to_html(false) + "|" + marking] = true
			print("%-6s %-3d %-9s %-10s %s" % [
				family, palette_index, marking, skin.to_html(false),
				str(silhouette.get("produce", "-")),
			])
			var image := viewport.get_texture().get_image()
			image.save_png("%s/%s_p%d_%s.png" % [
				OUTPUT_DIR, family.to_lower(), palette_index, marking,
			])
	print("--- %d distinct (skin, coat) pairs across %d volis" % [seen.size(), index])
	quit()
