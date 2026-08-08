extends Node3D

## Feli, Avi and Cani in the receive pose, twice.
##
## Run it:
##
##     xvfb-run -a godot --path . res://tools/preview/body_type_drafts.tscn
##
## Front row is draft C as rendered before: a 0.018 m line, flat fill, the body
## exactly as it is built today. Back row asks two questions at once -- what the
## figure looks like without the hip block that reads as a shelf, and what it
## looks like when each type is allowed to be as different as it was authored.
##
## The second question has an answer because of how the models are made: every
## type is authored as a complete skeleton and then *pulled toward* a shared one
## by `BodyTypeModels.type_expression`. At 0.45 a type keeps a minority share of
## its own proportions. Turning it up invents nothing; it stops throwing away what
## the type already says.
const ActorScene := preload("res://scenes/components/player_actor_3d.tscn")
const RallyEventModel := preload("res://scripts/models/rally_event.gd")
const Bodies := preload("res://scripts/data/body_type_models.gd")

const TYPES: Array[String] = ["Feli", "Avi", "Cani"]
const INK: float = 0.018

var _frame: int = 0


func _ready() -> void:
	var environment := WorldEnvironment.new()
	var settings := Environment.new()
	settings.background_mode = Environment.BG_COLOR
	settings.background_color = Color(0.96, 0.95, 0.92)
	settings.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	settings.ambient_light_color = Color(0.88, 0.91, 0.98)
	settings.ambient_light_energy = 1.0
	environment.environment = settings
	add_child(environment)
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 5.4
	camera.position = Vector3(0.0, 2.25, 6.0)
	camera.look_at(Vector3(0.0, 2.25, 0.0))
	add_child(camera)

	for row in range(2):
		Bodies.type_expression = 0.45 if row == 0 else 0.92
		for index in range(TYPES.size()):
			var actor := ActorScene.instantiate() as PlayerActor3D
			actor.flat_shading = true
			add_child(actor)
			## Stacked vertically rather than in depth: an orthographic camera
			## with a mild tilt puts one row exactly behind the other, which is
			## a contact sheet of three figures and three you cannot see.
			actor.position = Vector3(
				float(index) * 1.25 - 1.25, 0.0 if row == 0 else 2.35, 0.0
			)
			actor.configure(5 + index, true, "M", "Right", {
				"height_cm": 190.0, "wingspan_cm": 196.0, "stride_length_m": 0.86,
				"body_type": TYPES[index],
				"standing_reach_meters": 2.48, "jumping_reach_meters": 3.20,
			})
			actor.set_pose(RallyEventModel.EventType.DEFENSE, 0.0, -0.08,
				Vector2(0.0, 1.0), true)
			actor.rotation_degrees = Vector3(0.0, 158.0, 0.0)
			if row == 1:
				## The shelf. It is a box wider than the torso sitting at the hip,
				## and at this line weight it gets an outline of its own, which is
				## what turns it from shorts into a ledge.
				var shorts := actor.get_node_or_null("BodyPivot/Shorts") as MeshInstance3D
				if shorts != null:
					shorts.visible = false
			_ink(actor, INK)
	Bodies.type_expression = 0.45


func _ink(node: Node, grow: float) -> void:
	for child in node.get_children():
		_ink(child, grow)
	var mesh_instance := node as MeshInstance3D
	if mesh_instance == null or mesh_instance.mesh == null or not mesh_instance.visible:
		return
	if mesh_instance.name == "Ink":
		return
	var twin := MeshInstance3D.new()
	twin.name = "Ink"
	twin.mesh = mesh_instance.mesh
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.06, 0.07, 0.10)
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.cull_mode = BaseMaterial3D.CULL_FRONT
	material.grow = true
	material.grow_amount = grow
	twin.material_override = material
	mesh_instance.add_child(twin)


func _process(_delta: float) -> void:
	_frame += 1
	if _frame != 14:
		return
	get_viewport().get_texture().get_image().save_png("user://body_type_drafts.png")
	get_tree().quit()
