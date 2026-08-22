extends SceneTree

const ACTOR_SCENE := preload("res://scenes/components/player_actor_3d.tscn")

const CASES := [
	["Feli", "tabby"], ["Feli", "patch"], ["Feli", "scar"],
	["Cani", "spots"], ["Cani", "blaze"], ["Cani", "patch"], ["Cani", "scar"],
	["Avi", "speckle"], ["Avi", "blaze"], ["Avi", "scar"],
	["Ursi", "blaze"], ["Ursi", "patch"], ["Ursi", "scar"],
	["Simi", "patch"], ["Simi", "speckle"], ["Simi", "scar"],
	["Vegi", "speckle"], ["Vegi", "blaze"], ["Vegi", "scar"],
]

const VIEWS := {
	"front": 0.0,
	"three_quarter": 45.0,
	"profile": 90.0,
}

const OUTPUT_DIR := "res://artifacts/mark-previews"
const BACKGROUND := Color("d8d6cf")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))

	var viewport := SubViewport.new()
	viewport.size = Vector2i(520, 640)
	viewport.transparent_bg = false
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.own_world_3d = true
	root.add_child(viewport)

	var world := World3D.new()
	viewport.world_3d = world
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = BACKGROUND
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("ffffff")
	environment.ambient_light_energy = 0.72
	world.environment = environment

	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 2.75
	camera.position = Vector3(0.0, 1.18, -4.2)
	viewport.add_child(camera)
	camera.look_at(Vector3(0.0, 1.16, 0.0), Vector3.UP)
	## A SubViewport can render its environment without ever selecting a camera.
	## Make the diagnostic's authority explicit so a background-only frame cannot
	## masquerade as a successful appearance test.
	camera.current = true

	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-38.0, -28.0, 0.0)
	key.light_energy = 1.05
	viewport.add_child(key)
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-22.0, 145.0, 0.0)
	fill.light_energy = 0.38
	viewport.add_child(fill)

	var actor := ACTOR_SCENE.instantiate()
	viewport.add_child(actor)
	(actor.get_node("Shadow") as Node3D).visible = false
	(actor.get_node("FocusRing") as Node3D).visible = false
	(actor.get_node("IdentityLabel") as Node3D).visible = false

	var player_id := 8100
	for raw_case in CASES:
		var body_type := str(raw_case[0])
		var marking := str(raw_case[1])
		player_id += 1
		var appearance := {
			"marking": marking,
			"palette_index": 0,
		}
		if body_type == "Vegi":
			appearance["produce"] = "Pear"
		actor.configure(
			player_id, true, "%s %s" % [body_type, marking], "Right",
			{
				"body_type": body_type,
				"appearance": appearance,
				"height_cm": 188.0,
				"wingspan_cm": 191.0,
			}
		)
		actor.position = Vector3.ZERO
		for _settle in range(4):
			await process_frame
		for view_name in VIEWS:
			actor.rotation_degrees = Vector3(0.0, float(VIEWS[view_name]), 0.0)
			await process_frame
			await RenderingServer.frame_post_draw
			var image := viewport.get_texture().get_image()
			var path := "%s/%s_%s_%s.png" % [
				OUTPUT_DIR,
				body_type.to_lower(),
				marking,
				str(view_name),
			]
			if _foreground_sample_count(image) < 200:
				push_error("Blank/near-blank mark preview: %s" % path)
				quit(1)
				return
			var err := image.save_png(path)
			if err != OK:
				push_error("Could not save %s: %s" % [path, error_string(err)])
				quit(1)
				return

	print("Rendered %d surface-mark preview images to %s" % [CASES.size() * VIEWS.size(), OUTPUT_DIR])
	quit()


## Cheap guard against a diagnostic that rendered only its environment. Sampling
## every fourth pixel is enough to find a body this large without turning a
## visual probe into an image-processing benchmark.
func _foreground_sample_count(image: Image) -> int:
	var count := 0
	for y in range(0, image.get_height(), 4):
		for x in range(0, image.get_width(), 4):
			var pixel := image.get_pixel(x, y)
			var delta := absf(pixel.r - BACKGROUND.r) \
				+ absf(pixel.g - BACKGROUND.g) \
				+ absf(pixel.b - BACKGROUND.b)
			if delta > 0.10:
				count += 1
		return count
