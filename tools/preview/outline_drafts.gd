extends Node3D

## Four drafts of a drawn voli, side by side.
##
## Run it:
##
##     xvfb-run -a godot --path . res://tools/preview/outline_drafts.tscn
##
## and it writes `user://outline_drafts.png`.
##
## The technique is an inverted hull: every mesh in the rig gets a twin, grown
## outward by a fixed amount, painted flat black and rendered inside-out so only
## its far side is visible. What you see of that twin is a band around the
## silhouette of the part it belongs to -- so the line follows each limb, and an
## arm crossing the torso keeps its own edge instead of merging into it. That is
## the "separately" the sticker trace does in 2D, done in 3D for free.
##
## `grow_amount` is in metres, which is the useful part: the line is a constant
## thickness in world space, so it does not thin out as a voli moves upcourt.
const ActorScene := preload("res://scenes/components/player_actor_3d.tscn")
const RallyEventModel := preload("res://scripts/models/rally_event.gd")

const DRAFTS: Array[Dictionary] = [
	{"label": "A: no line, flat", "grow": 0.0, "flat": true},
	{"label": "B: fine line", "grow": 0.008, "flat": true},
	{"label": "C: thick line", "grow": 0.018, "flat": true},
	{"label": "D: thick line, lit", "grow": 0.018, "flat": false},
]

var _frame: int = 0


func _ready() -> void:
	var environment := WorldEnvironment.new()
	var settings := Environment.new()
	settings.background_mode = Environment.BG_COLOR
	settings.background_color = Color(0.96, 0.95, 0.92)
	settings.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	settings.ambient_light_color = Color(0.86, 0.9, 0.98)
	settings.ambient_light_energy = 1.0
	environment.environment = settings
	add_child(environment)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-40.0, 150.0, 0.0)
	light.light_energy = 1.2
	add_child(light)
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 3.0
	camera.position = Vector3(0.0, 1.15, 5.0)
	camera.look_at(Vector3(0.0, 1.05, 0.0))
	add_child(camera)

	for index in range(DRAFTS.size()):
		var draft: Dictionary = DRAFTS[index]
		var actor := ActorScene.instantiate() as PlayerActor3D
		actor.flat_shading = bool(draft.flat)
		add_child(actor)
		actor.position = Vector3(float(index) * 1.05 - 1.58, 0.0, 0.0)
		actor.configure(5, true, "M", "Right", {
			"height_cm": 192.0, "wingspan_cm": 198.0, "stride_length_m": 0.86,
			"body_type": "Cani",
			"standing_reach_meters": 2.50, "jumping_reach_meters": 3.24,
		})
		actor.rotation_degrees = Vector3(0.0, 152.0, 0.0)
		actor.set_pose(RallyEventModel.EventType.DEFENSE, 0.0, -0.08,
			Vector2(0.0, 1.0), true)
		actor.rotation_degrees = Vector3(0.0, 152.0, 0.0)
		if float(draft.grow) > 0.0:
			_ink(actor, float(draft.grow))
		print("%s" % str(draft.label))


## A grown, inside-out twin of every mesh under `node`.
func _ink(node: Node, grow: float) -> void:
	for child in node.get_children():
		_ink(child, grow)
	var mesh_instance := node as MeshInstance3D
	if mesh_instance == null or mesh_instance.mesh == null:
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
	get_viewport().get_texture().get_image().save_png("user://outline_drafts.png")
	get_tree().quit()
