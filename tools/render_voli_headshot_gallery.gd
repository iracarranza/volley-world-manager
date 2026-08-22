extends SceneTree

## In-engine portrait diagnostic for UI-scale Voli likenesses.
##
## These are not generated illustrations and not reconstructed 2D avatars. Each
## PNG is the real PlayerActor3D rig, materials, anatomy and surface markings,
## viewed through a tighter camera suitable for dialogue, reports and roster UI.

const ACTOR_SCENE := preload("res://scenes/components/player_actor_3d.tscn")

const CASES := [
	["Feli", "none"], ["Feli", "tabby"], ["Feli", "patch"], ["Feli", "scar"],
	["Cani", "none"], ["Cani", "spots"], ["Cani", "blaze"], ["Cani", "patch"], ["Cani", "scar"],
	["Avi", "none"], ["Avi", "speckle"], ["Avi", "blaze"], ["Avi", "scar"],
	["Ursi", "none"], ["Ursi", "blaze"], ["Ursi", "patch"], ["Ursi", "scar"],
	["Simi", "none"], ["Simi", "patch"], ["Simi", "speckle"], ["Simi", "scar"],
	["Vegi", "none"], ["Vegi", "speckle"], ["Vegi", "blaze"], ["Vegi", "scar"],
]

## Front is useful for mark legibility checks; 30 degrees is the intended default
## conversational/profile framing because it keeps both eyes readable while
## showing muzzle/beak/head depth that a flat front view hides.
const VIEWS := {
	"front": 0.0,
	"three_quarter": 30.0,
}

const OUTPUT_DIR := "res://artifacts/headshot-previews"
const BAKE_SIZE := Vector2i(512, 512)


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
	camera.size = 1.40
	camera.position = Vector3(0.0, 1.66, -4.2)
	viewport.add_child(camera)
	camera.look_at(Vector3(0.0, 1.66, 0.0), Vector3.UP)
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

	var player_id := 9200
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
			if _opaque_sample_count(image) < 180:
				push_error("Blank/near-blank Voli headshot: %s" % path)
				quit(1)
				return
			var err := image.save_png(path)
			if err != OK:
				push_error("Could not save %s: %s" % [path, error_string(err)])
				quit(1)
				return

	print("Rendered %d in-engine Voli headshots to %s" % [CASES.size() * VIEWS.size(), OUTPUT_DIR])
	quit()


func _opaque_sample_count(image: Image) -> int:
	var count := 0
	for y in range(0, image.get_height(), 4):
		for x in range(0, image.get_width(), 4):
			if image.get_pixel(x, y).a > 0.04:
				count += 1
	return count
