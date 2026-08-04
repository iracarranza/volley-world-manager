class_name PlayerActor3D
extends Node3D

const UIPalette := preload("res://scripts/data/ui_palette.gd")

const RallyEventModel := preload("res://scripts/models/rally_event.gd")
const BodyTypeModelsScript := preload("res://scripts/data/body_type_models.gd")

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
var body_type: String = "Vegi"
var produce: String = ""
var silhouette: Dictionary = {}
var shoulder_offset: Vector2 = Vector2(0.40, 1.52)
var hip_offset: Vector2 = Vector2(0.16, 0.48)
var body_height_scale: float = 1.0
var arm_length_scale: float = 1.0
var stride_cycle: float = 0.0
var gait_blend: float = 0.0
var locomotion_bob: float = 0.0
var has_world_position: bool = false

const REFERENCE_HEIGHT_CM: float = 188.0
const REFERENCE_WINGSPAN_CM: float = 191.0
## Each silhouette states its own shoe-to-scalp height, and every one of them is
## normalised to the 1.88 m reference player before individual height is
## applied. This used to be a single 0.93 constant describing the one rig that
## existed; with an Avi standing 2.16 m tall in mesh space and a Pumpkin 1.76 m,
## a shared constant would have made the tall type genuinely oversized against
## the regulation net rather than merely tall.
const REFERENCE_RIG_HEIGHT_M: float = 2.02


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
	body_type = str(physical_profile.get("body_type", "Vegi"))
	_build_silhouette()
	_apply_physical_profile(physical_profile)
	identity_label.text = "%s · %.0f cm · %s" % [
		display_name, height_cm, dominant_hand.left(1),
	]
	identity_label.modulate = Color("f8f2d8")
	identity_label.visible = false
	apply_ui_palette(false)
	set_pose(-1, 0.0, 0.0, Vector2.ZERO, false)


func apply_ui_palette(light_mode: bool) -> void:
	_ensure_node_bindings()
	var team_color := UIPalette.color(
		&"accent_alt" if is_home_team else &"danger", light_mode
	)
	var accent_color := UIPalette.color(
		&"accent" if is_home_team else &"ink", light_mode
	)
	## A Vegi's body is the produce, so painting the torso in team colours would
	## paint over the whole player. Those silhouettes wear their kit as a
	## separate band and keep their skin here; the others wear the torso.
	var skin_color: Color = silhouette.get("skin", Color("d6a06c"))
	var crown_color: Color = silhouette.get("crown", skin_color.lightened(0.3))
	var wears_kit := str(silhouette.get("torso_material", "kit")) == "kit"
	_apply_material_color(torso, team_color if wears_kit else skin_color)
	_apply_material_color(shorts, team_color.darkened(0.38))
	_apply_material_color(head, skin_color)
	for arm in [left_arm, right_arm]:
		_apply_material_color(arm.get_node("Mesh"), skin_color)
	for leg in [left_leg, right_leg]:
		_apply_material_color(leg.get_node("Mesh"), skin_color)
		_apply_material_color(leg.get_node("Shoe"), team_color.darkened(0.55))
	for cosmetic in _cosmetics():
		match str(cosmetic.get_meta("color_key", "skin")):
			"kit":
				_apply_material_color(cosmetic, team_color)
			"crown":
				_apply_material_color(cosmetic, crown_color)
			"literal":
				_apply_material_color(cosmetic, cosmetic.get_meta("color_value"))
			_:
				_apply_material_color(cosmetic, skin_color)
	_apply_material_color(focus_ring, accent_color)


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
	left_arm.position = Vector3(-shoulder_offset.x, shoulder_offset.y, 0.0)
	right_arm.position = Vector3(shoulder_offset.x, shoulder_offset.y, 0.0)
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
			left_arm.position.y = shoulder_offset.y + 0.06
			right_arm.position.y = shoulder_offset.y + 0.06
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
	## Scale the silhouette so its own stated height becomes this player's real
	## one. The old form multiplied by a 0.93 constant, which is exactly
	## 1.88 / 2.02 for the single rig that existed; stating it as a ratio makes
	## it correct for a 2.16 m Avi and a 1.76 m Pumpkin too.
	var rig_height := float(silhouette.get("rig_height", REFERENCE_RIG_HEIGHT_M))
	body_height_scale = (height_cm / 100.0) / maxf(rig_height, 0.5)
	var reference_ratio := REFERENCE_WINGSPAN_CM / REFERENCE_HEIGHT_CM
	arm_length_scale = clampf(
		(wingspan_cm / height_cm) / reference_ratio, 0.78, 1.24
	)
	var arm_length := float(Dictionary(silhouette.get("arm", {})).get("height", 0.88))
	for arm_path in ["BodyPivot/LeftArm/Mesh", "BodyPivot/RightArm/Mesh"]:
		var arm_mesh := get_node(arm_path) as MeshInstance3D
		arm_mesh.scale.y = arm_length_scale
		arm_mesh.position.y = -arm_length * 0.5 * arm_length_scale
	identity_label.position.y = (
		float(silhouette.get("rig_height", REFERENCE_RIG_HEIGHT_M)) + 0.26
	) * body_height_scale


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


## Rebuild every mesh on the rig for this player's body type.
##
## The node graph is untouched: `set_pose()` still finds a Torso, a Head, two
## arms and two legs wherever it looks, and still poses them by rotating the
## same joints. Only the geometry hanging off those joints and the points they
## attach at change -- which is what lets one pose model serve a cat, a bird and
## an aubergine without a branch anywhere in the animation code.
func _build_silhouette() -> void:
	_ensure_node_bindings()
	silhouette = BodyTypeModelsScript.silhouette(body_type, player_id)
	produce = str(silhouette.get("produce", ""))
	shoulder_offset = silhouette.get("shoulder", Vector2(0.40, 1.52))
	hip_offset = silhouette.get("hip", Vector2(0.16, 0.48))

	torso.mesh = BodyTypeModelsScript.build_mesh(silhouette.get("torso", {}))
	torso.position = Vector3(0.0, float(silhouette.get("torso_y", 1.13)), 0.0)
	shorts.mesh = BodyTypeModelsScript.build_mesh(silhouette.get("shorts", {}))
	shorts.position = Vector3(0.0, float(silhouette.get("shorts_y", 0.60)), 0.0)
	head.mesh = BodyTypeModelsScript.build_mesh(silhouette.get("head", {}))
	head.position = Vector3(0.0, float(silhouette.get("head_y", 1.82)), 0.0)

	var arm_spec: Dictionary = silhouette.get("arm", {})
	arm_spec["shape"] = "cylinder"
	var arm_height := float(arm_spec.get("height", 0.88))
	for arm in [left_arm, right_arm]:
		var arm_mesh := arm.get_node("Mesh") as MeshInstance3D
		arm_mesh.mesh = BodyTypeModelsScript.build_mesh(arm_spec)
		arm_mesh.position = Vector3(0.0, -arm_height * 0.5, 0.0)

	## Legs are placed so the foot lands just above the floor whatever the hip
	## height and shank length are, rather than by the pair of literals that
	## happened to suit the one rig.
	var leg_spec: Dictionary = silhouette.get("leg", {})
	leg_spec["shape"] = "cylinder"
	var leg_height := float(leg_spec.get("height", 0.74))
	var shoe_spec: Dictionary = silhouette.get("shoe", {})
	for index in [0, 1]:
		var leg: Node3D = left_leg if index == 0 else right_leg
		var side := -1.0 if index == 0 else 1.0
		leg.position = Vector3(side * hip_offset.x, hip_offset.y, 0.0)
		var leg_mesh := leg.get_node("Mesh") as MeshInstance3D
		leg_mesh.mesh = BodyTypeModelsScript.build_mesh(leg_spec)
		leg_mesh.position = Vector3(
			0.0, -(hip_offset.y - leg_height * 0.5 - 0.03), 0.0
		)
		var shoe := leg.get_node("Shoe") as MeshInstance3D
		shoe.mesh = BodyTypeModelsScript.build_mesh(shoe_spec)
		shoe.position = Vector3(0.0, -(hip_offset.y - 0.06), -0.06)
		## A box foot is authored lying flat already; only the capsule shoe
		## needs standing on its side to become a foot rather than a leg.
		shoe.rotation_degrees = Vector3(
			90.0 if str(shoe_spec.get("shape", "capsule")) == "capsule" else 0.0,
			0.0, 0.0
		)
	_build_cosmetics()


## Ears, beaks, wings, tails, stems and leaves.
##
## Parented by path so a wing can hang off an arm node and travel with every
## swing and block the pose code already produces, while a stem sits on the body
## and does not.
func _build_cosmetics() -> void:
	for existing in _cosmetics():
		existing.queue_free()
	for raw_part in silhouette.get("extras", []):
		var part: Dictionary = raw_part
		var parent := get_node_or_null(str(part.get("parent", "BodyPivot")))
		if parent == null:
			continue
		var instance := MeshInstance3D.new()
		instance.name = str(part.get("name", "Cosmetic"))
		instance.mesh = BodyTypeModelsScript.build_mesh(part)
		instance.position = part.get("position", Vector3.ZERO)
		instance.rotation_degrees = part.get("rotation", Vector3.ZERO)
		instance.set_meta("cosmetic", true)
		if part.has("color_value"):
			instance.set_meta("color_key", "literal")
			instance.set_meta("color_value", part.color_value)
		else:
			instance.set_meta("color_key", str(part.get("color", "skin")))
		parent.add_child(instance)


func _cosmetics() -> Array[MeshInstance3D]:
	var found: Array[MeshInstance3D] = []
	for node in find_children("*", "MeshInstance3D", true, false):
		var mesh_node := node as MeshInstance3D
		if mesh_node != null and mesh_node.has_meta("cosmetic"):
			found.append(mesh_node)
	return found
