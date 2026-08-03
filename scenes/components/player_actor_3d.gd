class_name PlayerActor3D
extends Node3D

const RallyEventModel := preload("res://scripts/models/rally_event.gd")

@onready var body_pivot: Node3D = $BodyPivot
@onready var torso: MeshInstance3D = $BodyPivot/Torso
@onready var shorts: MeshInstance3D = $BodyPivot/Shorts
@onready var head: MeshInstance3D = $BodyPivot/Head
@onready var left_arm: Node3D = $BodyPivot/LeftArm
@onready var right_arm: Node3D = $BodyPivot/RightArm
@onready var left_leg: Node3D = $BodyPivot/LeftLeg
@onready var right_leg: Node3D = $BodyPivot/RightLeg
@onready var shadow: MeshInstance3D = $Shadow
@onready var identity_label: Label3D = $IdentityLabel
@onready var focus_ring: MeshInstance3D = $FocusRing

var player_id: int = -1
var is_home_team: bool = true
var tactical_position: Vector2 = Vector2.ZERO
var dominant_hand: String = "Right"
var height_cm: float = 188.0
var wingspan_cm: float = 191.0
var stride_length_m: float = 0.83
var body_height_scale: float = 1.0
var arm_length_scale: float = 1.0
var stride_cycle: float = 0.0
var gait_blend: float = 0.0
var locomotion_bob: float = 0.0
var has_world_position: bool = false

const REFERENCE_HEIGHT_CM: float = 188.0
const REFERENCE_WINGSPAN_CM: float = 191.0
## The neutral mesh is 2.02 m from shoe to scalp. Normalize it to the 1.88 m
## reference player before applying individual height, rather than making every
## player roughly seven percent too large relative to the regulation net.
const RIG_HEIGHT_NORMALIZATION: float = 0.93


func configure(
	p_player_id: int,
	home_team: bool,
	display_name: String,
	p_dominant_hand: String = "Right",
	physical_profile: Dictionary = {},
) -> void:
	_ensure_node_bindings()
	player_id = p_player_id
	is_home_team = home_team
	dominant_hand = "Left" if p_dominant_hand == "Left" else "Right"
	_apply_physical_profile(physical_profile)
	identity_label.text = "%s · %.0f cm · %s" % [
		display_name, height_cm, dominant_hand.left(1),
	]
	identity_label.modulate = Color("f8f2d8")
	identity_label.visible = false
	var team_color := Color("1677ff") if home_team else Color("ed4b42")
	var accent_color := Color("f1d44b") if home_team else Color("f7f2e8")
	_apply_material_color(torso, team_color)
	_apply_material_color(shorts, team_color.darkened(0.38))
	_apply_material_color(head, Color("d6a06c"))
	for arm in [left_arm, right_arm]:
		_apply_material_color(arm.get_node("Mesh"), Color("d6a06c"))
	for leg in [left_leg, right_leg]:
		_apply_material_color(leg.get_node("Mesh"), Color("d6a06c"))
		_apply_material_color(leg.get_node("Shoe"), team_color.darkened(0.55))
	_apply_material_color(focus_ring, accent_color)
	set_pose(-1, 0.0, 0.0, Vector2.ZERO, false)


func set_tactical_position(position: Vector2, world_position: Vector3) -> void:
	_ensure_node_bindings()
	if has_world_position:
		var travelled := Vector2(
			world_position.x - self.position.x,
			world_position.z - self.position.z,
		).length()
		if travelled > 0.0001:
			stride_cycle += travelled / maxf(stride_length_m, 0.30)
			gait_blend = 1.0
			locomotion_bob = absf(sin(stride_cycle * TAU)) * 0.035
		else:
			gait_blend = 0.0
			locomotion_bob = 0.0
	has_world_position = true
	tactical_position = position
	self.position = world_position


func set_highlighted(highlighted: bool) -> void:
	focus_ring.visible = highlighted
	identity_label.visible = highlighted
	identity_label.outline_modulate = Color("0a101b") if highlighted else Color("00000080")
	identity_label.outline_size = 5 if highlighted else 3


func set_pose(
	event_type: int,
	elevation: float,
	phase: float,
	contact_direction: Vector2,
	is_contact_actor: bool,
) -> void:
	_ensure_node_bindings()
	var lift := clampf(elevation, 0.0, 1.0) * 0.82
	body_pivot.position = Vector3(0.0, lift + locomotion_bob, 0.0)
	body_pivot.rotation = Vector3.ZERO
	body_pivot.scale = Vector3.ONE * body_height_scale
	left_arm.rotation_degrees = Vector3(0.0, 0.0, -12.0)
	right_arm.rotation_degrees = Vector3(0.0, 0.0, 12.0)
	left_arm.position = Vector3(-0.40, 1.52, 0.0)
	right_arm.position = Vector3(0.40, 1.52, 0.0)
	var gait_angle := sin(stride_cycle * TAU) * 32.0 * gait_blend
	left_leg.rotation_degrees = Vector3(gait_angle, 0.0, 0.0)
	right_leg.rotation_degrees = Vector3(-gait_angle, 0.0, 0.0)
	shadow.scale = Vector3.ONE * lerpf(1.0, 1.35, elevation)
	shadow.transparency = lerpf(0.0, 0.58, elevation)
	if contact_direction.length_squared() > 0.0001:
		## Godot's forward is -Z, and this rig genuinely faces that way -- both
		## shoes sit at z = -0.06. Rotating by theta about Y puts local -Z at
		## world (-sin theta, -cos theta), so facing (dx, dz) needs
		## atan2(-dx, -dz). Passing (dx, dz) instead yields theta + PI, which
		## drew every server, setter and attacker with their back to the ball.
		##
		## The direction is still in normalized court space, where x spans 9 m
		## and y spans 18 m, so the angle remains slightly aspect-compressed.
		## That is a much smaller error than the sign and is left for a caller
		## that knows the court dimensions.
		rotation.y = atan2(-contact_direction.x, -contact_direction.y)
	if not is_contact_actor:
		return
	var striking_arm := left_arm if dominant_hand == "Left" else right_arm
	var guide_arm := right_arm if dominant_hand == "Left" else left_arm
	match event_type:
		RallyEventModel.EventType.SERVE:
			body_pivot.rotation.x = -0.10
			striking_arm.rotation_degrees.x = -145.0 * clampf(phase * 1.8, 0.0, 1.0)
			guide_arm.rotation_degrees.x = -72.0
		RallyEventModel.EventType.RECEPTION, RallyEventModel.EventType.DEFENSE:
			body_pivot.position.y -= 0.30 * body_height_scale
			body_pivot.scale.y *= 0.82
			left_leg.rotation_degrees.x = -22.0
			right_leg.rotation_degrees.x = -22.0
			left_arm.rotation_degrees = Vector3(-70.0, 0.0, -18.0)
			right_arm.rotation_degrees = Vector3(-70.0, 0.0, 18.0)
		RallyEventModel.EventType.SET:
			left_arm.rotation_degrees = Vector3(-160.0, 0.0, -25.0)
			right_arm.rotation_degrees = Vector3(-160.0, 0.0, 25.0)
		RallyEventModel.EventType.ATTACK:
			body_pivot.rotation.x = -0.16
			left_leg.rotation_degrees.x = 18.0
			right_leg.rotation_degrees.x = -26.0
			guide_arm.rotation_degrees.x = -95.0
			striking_arm.rotation_degrees.x = -175.0 \
				+ 95.0 * clampf(phase, 0.0, 1.0)
		RallyEventModel.EventType.BLOCK:
			left_leg.rotation_degrees.x = 12.0
			right_leg.rotation_degrees.x = 12.0
			left_arm.position.y = 1.58
			right_arm.position.y = 1.58
			left_arm.rotation_degrees = Vector3(-175.0, 0.0, -8.0)
			right_arm.rotation_degrees = Vector3(-175.0, 0.0, 8.0)


func _apply_material_color(mesh: MeshInstance3D, color: Color) -> void:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.72
	mesh.material_override = material


func _apply_physical_profile(profile: Dictionary) -> void:
	height_cm = clampf(float(profile.get("height_cm", REFERENCE_HEIGHT_CM)), 150.0, 220.0)
	wingspan_cm = clampf(float(profile.get("wingspan_cm", REFERENCE_WINGSPAN_CM)), 150.0, 235.0)
	stride_length_m = clampf(float(profile.get("stride_length_m", 0.83)), 0.55, 1.15)
	body_height_scale = height_cm / REFERENCE_HEIGHT_CM * RIG_HEIGHT_NORMALIZATION
	var reference_ratio := REFERENCE_WINGSPAN_CM / REFERENCE_HEIGHT_CM
	arm_length_scale = clampf(
		(wingspan_cm / height_cm) / reference_ratio, 0.78, 1.24
	)
	for arm_path in ["BodyPivot/LeftArm/Mesh", "BodyPivot/RightArm/Mesh"]:
		var arm_mesh := get_node(arm_path) as MeshInstance3D
		arm_mesh.scale.y = arm_length_scale
		arm_mesh.position.y = -0.38 * arm_length_scale
	identity_label.position.y = 2.28 * body_height_scale


func _ensure_node_bindings() -> void:
	if body_pivot != null:
		return
	body_pivot = get_node("BodyPivot")
	torso = get_node("BodyPivot/Torso")
	shorts = get_node("BodyPivot/Shorts")
	head = get_node("BodyPivot/Head")
	left_arm = get_node("BodyPivot/LeftArm")
	right_arm = get_node("BodyPivot/RightArm")
	left_leg = get_node("BodyPivot/LeftLeg")
	right_leg = get_node("BodyPivot/RightLeg")
	shadow = get_node("Shadow")
	identity_label = get_node("IdentityLabel")
	focus_ring = get_node("FocusRing")
