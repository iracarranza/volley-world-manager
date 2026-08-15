extends Node3D

## Feli, Avi and Cani in the receive pose, three ways, changing one thing a row.
##
## The previous version of this draft changed two things at once -- it hid the
## shorts *and* turned `type_expression` up -- so the legs meeting the body
## differently and an Avi's arms sitting differently could not be attributed to
## either. They were the dial: it moves `hip_x`, `hip_y`, `shoulder_x`,
## `shoulder_y` and both limb lengths. One variable a row now, and the dial stays
## where it lives.
##
## The three parts at the hip are also three parts, which the first draft ran
## together: the **shorts**, a box wider than the torso; the **hip joint balls**,
## skin-coloured spheres at each leg root; and the leg *angles*, which come from
## the pose and from `hip_x` and are not a mesh at all.
const ActorScene := preload("res://scenes/components/player_actor_3d.tscn")
const RallyEventModel := preload("res://scripts/models/rally_event.gd")

const TYPES: Array[String] = ["Feli", "Avi", "Cani"]
## Draft C, and a heavier line for the parts that say which animal this is.
##
## Everything already gets an outline -- `_ink` walks every mesh -- so ears, crest
## and beak were never missing one. What they did not have is *emphasis*. A crown
## carries the whole identity of a type and is the smallest thing on the figure,
## so it is the one place where a heavier line buys legibility rather than weight.
const INK: float = 0.018
const CROWN_INK: float = 0.030
## Everything that is not one of these is a cosmetic: an ear, a crest, a beak, a
## tail, a stem. Named as the *body* rather than as a list of cosmetics because
## the body is closed and the cosmetics are not.
const BODY_PARTS: Array[String] = [
	"Torso", "Shorts", "Head", "Mesh", "Joint", "Shoe", "Kit",
]

const ROWS: Array[Dictionary] = [
	{"label": "1  as built", "shorts": true, "hips": true},
	{"label": "2  no shorts", "shorts": false, "hips": true},
	{"label": "3  no shorts, no hip balls", "shorts": false, "hips": false},
]

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
	camera.size = 7.6
	camera.position = Vector3(0.0, 3.3, 6.0)
	camera.look_at(Vector3(0.0, 3.3, 0.0))
	add_child(camera)

	for row in range(ROWS.size()):
		var options: Dictionary = ROWS[row]
		for index in range(TYPES.size()):
			var actor := ActorScene.instantiate() as PlayerActor3D
			actor.flat_shading = true
			add_child(actor)
			actor.position = Vector3(
				float(index) * 1.30 - 1.30, float(2 - row) * 2.35, 0.0
			)
			actor.configure(5 + index, true, "M", "Right", {
				"height_cm": 190.0, "wingspan_cm": 196.0, "stride_length_m": 0.86,
				"body_type": TYPES[index],
				"standing_reach_meters": 2.48, "jumping_reach_meters": 3.20,
			})
			actor.set_pose(RallyEventModel.EventType.DEFENSE, 0.0, -0.08,
				Vector2(0.0, 1.0), true)
			actor.rotation_degrees = Vector3(0.0, 158.0, 0.0)
			if not bool(options.shorts):
				var shorts := actor.get_node_or_null(
					"BodyPivot/Shorts"
				) as MeshInstance3D
				if shorts != null:
					shorts.visible = false
			if not bool(options.hips):
				## The joint ball at each leg root only. The knee, elbow and
				## shoulder balls stay, so this row isolates the hip.
				for leg_name in ["LeftLeg", "RightLeg"]:
					var ball := actor.get_node_or_null(
						"BodyPivot/%s/Joint" % leg_name
					) as MeshInstance3D
					if ball != null:
						ball.visible = false
			_ink(actor)
		print(str(options.label))


func _ink(node: Node) -> void:
	for child in node.get_children():
		_ink(child)
	var mesh_instance := node as MeshInstance3D
	if mesh_instance == null or mesh_instance.mesh == null:
		return
	if mesh_instance.name == "Ink" or not mesh_instance.visible:
		return
	var twin := MeshInstance3D.new()
	twin.name = "Ink"
	twin.mesh = mesh_instance.mesh
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.06, 0.07, 0.10)
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.cull_mode = BaseMaterial3D.CULL_FRONT
	material.grow = true
	material.grow_amount = INK if str(mesh_instance.name) in BODY_PARTS \
		else CROWN_INK
	twin.material_override = material
	mesh_instance.add_child(twin)


func _process(_delta: float) -> void:
	_frame += 1
	if _frame != 14:
		return
	get_viewport().get_texture().get_image().save_png("user://body_type_drafts.png")
	get_tree().quit()
