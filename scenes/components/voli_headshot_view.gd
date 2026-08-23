class_name VoliHeadshotView
extends SubViewportContainer

## Live UI form of the in-engine headshot gallery: the real PlayerActor3D rig,
## the same orthographic head-and-shoulders framing, and an isolated neutral
## world. It never borrows or crops a player from the match court.

const ACTOR_SCENE := preload("res://scenes/components/player_actor_3d.tscn")
const HEADSHOT_FOCUS := Vector3(0.0, 1.82, 0.0)
const HEADSHOT_WORLD_HEIGHT: float = 0.92

var actor: PlayerActor3D
var portrait_viewport: SubViewport


func _ready() -> void:
	stretch = true
	custom_minimum_size = Vector2(68.0, 68.0)
	portrait_viewport = SubViewport.new()
	portrait_viewport.size = Vector2i(256, 256)
	portrait_viewport.transparent_bg = true
	portrait_viewport.own_world_3d = true
	portrait_viewport.render_target_update_mode = SubViewport.UPDATE_WHEN_VISIBLE
	add_child(portrait_viewport)
	var environment := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.025, 0.04, 0.065, 1.0)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("ffffff")
	env.ambient_light_energy = 0.74
	environment.environment = env
	portrait_viewport.add_child(environment)
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = HEADSHOT_WORLD_HEIGHT
	camera.position = HEADSHOT_FOCUS + Vector3(0.0, 0.0, -4.2)
	portrait_viewport.add_child(camera)
	camera.look_at(HEADSHOT_FOCUS, Vector3.UP)
	camera.current = true
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-34.0, -30.0, 0.0)
	key.light_energy = 1.08
	portrait_viewport.add_child(key)
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-18.0, 140.0, 0.0)
	fill.light_energy = 0.40
	portrait_viewport.add_child(fill)
	actor = ACTOR_SCENE.instantiate() as PlayerActor3D
	portrait_viewport.add_child(actor)


func configure_placeholder(
	identity: int, display_name: String, body_type: String, marking: String
) -> void:
	if actor == null:
		await ready
	actor.configure(identity, true, display_name, "Right", {
		"body_type": body_type,
		"appearance": {"marking": marking, "palette_index": 0},
		"height_cm": 188.0, "wingspan_cm": 191.0,
	})
	actor.position = Vector3.ZERO
	actor.rotation_degrees = Vector3(0.0, 30.0, 0.0)
	for node_name in ["Shadow", "FocusRing", "IdentityLabel", "SignatureSurge3D"]:
		var readout := actor.get_node_or_null(node_name) as Node3D
		if readout != null:
			readout.visible = false
