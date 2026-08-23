extends SceneTree

## Ten Simi colourways, each drawn twice: bare, and wearing the family's own
## subtlest coat. Speckle is the stress test -- the mark ink flips derivation at
## a coat luminance of 0.22, so a ladder that runs near-black to cream crosses
## that boundary and shows whether the mark survives at both ends.

const ACTOR_SCENE := preload("res://scenes/components/player_actor_3d.tscn")

const FAMILIES := ["Feli", "Cani", "Avi", "Ursi", "Simi"]
const PALETTE_COUNT: int = 10
const OUTPUT_DIR := "res://artifacts/all-colourways"
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

	print("%-6s %-4s %-10s %s" % ["family", "pal", "skin", "L"])
	for family_raw in FAMILIES:
		var family: String = str(family_raw)
		for palette_index in range(PALETTE_COUNT):
			actor.configure(60000 + palette_index, true, family, "Right", {
				"body_type": family,
				"appearance": {"palette_index": palette_index, "marking": "none"},
				"height_cm": 188.0, "wingspan_cm": 191.0,
			})
			actor.rotation_degrees = Vector3(0.0, 30.0, 0.0)
			for _settle in range(4):
				await process_frame
			await RenderingServer.frame_post_draw
			var skin: Color = actor.silhouette.get("skin", Color.BLACK)
			print("%-6s %-4d %-10s %.3f" % [
				family, palette_index, skin.to_html(false), skin.get_luminance(),
			])
			var image := viewport.get_texture().get_image()
			var opaque := 0
			for y in range(0, image.get_height(), 4):
				for x in range(0, image.get_width(), 4):
					if image.get_pixel(x, y).a > 0.04:
						opaque += 1
			if opaque < 180:
				push_error("Blank render %s p%d" % [family, palette_index])
				quit(1)
				return
			image.save_png("%s/%s_%02d.png" % [
				OUTPUT_DIR, family.to_lower(), palette_index])
	quit()
