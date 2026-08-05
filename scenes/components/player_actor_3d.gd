class_name PlayerActor3D
extends Node3D

const UIPalette := preload("res://scripts/data/ui_palette.gd")

const RallyEventModel := preload("res://scripts/models/rally_event.gd")
const BodyTypeModelsScript := preload("res://scripts/data/body_type_models.gd")
const FaceExpressionsScript := preload("res://scripts/data/face_expressions.gd")

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
var leg_bone_lengths: Vector2 = Vector2(0.40, 0.34)
var arm_bone_lengths: Vector2 = Vector2(0.40, 0.48)
## How strained the contact the simulator resolved was. Not a visual choice:
## `_reception_pass_result` classifies every reception and dig as planted,
## moving, reaching or off-axis from the defender's reach margin, how far into
## the edge of their range the ball was, and how well their body could face it.
## Playback reads that verdict rather than inventing a pose.
var contact_posture: String = "planted"
## Which of the five faces the actor is wearing. Purely presentational today --
## nothing in the simulator sets it yet -- so it stays a plain assignment rather
## than being derived from state that does not exist.
var expression: String = FaceExpressionsScript.NEUTRAL
## Where the actor is currently facing, kept between frames so a change of
## heading can be turned into rather than snapped to.
var facing_yaw: float = 0.0
var has_facing: bool = false
var stride_cycle: float = 0.0
var gait_blend: float = 0.0
var locomotion_bob: float = 0.0
var has_world_position: bool = false

## Thigh share of total leg length. Slightly over half, which is roughly true
## and is the ratio that keeps a folded knee reading as a knee.
const THIGH_SHARE: float = 0.54

## Upper-arm share of total arm length. Slightly under half, because the lower
## segment carries the hand as well as the forearm.
const UPPER_ARM_SHARE: float = 0.46

## How bent a resting arm is. Deliberately not zero: nobody stands with their
## elbows locked, and straight arms are most of why the idle rig read as a
## mannequin. Small enough that it never competes with a pose that means
## something.
const READY_ELBOW_BEND: float = 17.0

## How fast a player can turn, in radians per second.
##
## Facing used to be assigned outright every frame, so a player pivoted through
## any angle in one frame the instant their heading changed. That reads as a
## teleport even when the position between two points is interpolating perfectly
## -- the body arrives smoothly and the *orientation* jumps -- and it is the
## cheaper half of what "teleporting" looks like on the court.
##
## About two turns a second at full rate. Fast enough that a defender squaring
## up to a ball never looks sluggish, slow enough that the turn is visible.
const FACING_TURN_RATE: float = 12.0

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
		## Two bones, as the legs have been since the knee.
		_apply_material_color(arm.get_node("Mesh"), skin_color)
		_apply_material_color(arm.get_node("Elbow/Mesh"), skin_color)
	for leg in [left_leg, right_leg]:
		## Two bones and a shoe. The shoe hangs off the knee now, not the hip.
		_apply_material_color(leg.get_node("Mesh"), skin_color)
		_apply_material_color(leg.get_node("Knee/Mesh"), skin_color)
		_apply_material_color(leg.get_node("Knee/Shoe"), team_color.darkened(0.55))
	## A face has to read on a pale turnip and on a near-black aubergine, so the
	## colour is chosen against the skin's luminance rather than being one ink
	## that happens to suit the first body type tried.
	var face_color := Color("18131f") if skin_color.get_luminance() > 0.30 \
		else Color("f6eddc")
	for feature in _face_features():
		_apply_material_color(feature, face_color)
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
			## Face where you are going.
			##
			## Facing was only ever set from a contact direction, and only the
			## contact actor is posed -- so every other player on the court
			## translated without ever turning. A setter walking back to their
			## release seat during serve receive slid there backwards, still
			## facing the net, which is the "sliding" half of what reads as
			## teleporting.
			##
			## Rate-limited by the same turn speed a contact facing uses, so a
			## player rounding a corner leans into it rather than snapping. The
			## contact actor's own facing is applied afterwards in `set_pose` and
			## still wins, which is correct: someone playing the ball faces the
			## ball, not their footwork.
			_turn_toward(atan2(
				-(world_position.x - self.position.x),
				-(world_position.z - self.position.z),
			))
		else:
			gait_blend = 0.0
			locomotion_bob = 0.0
	has_world_position = true
	tactical_position = position
	self.position = world_position


## Turns the actor toward a heading at `FACING_TURN_RATE`, or adopts it outright
## if this is the first heading it has ever had.
func _turn_toward(target_yaw: float) -> void:
	if not has_facing:
		facing_yaw = target_yaw
		has_facing = true
	else:
		var step := FACING_TURN_RATE * get_process_delta_time()
		var difference := angle_difference(facing_yaw, target_yaw)
		facing_yaw = target_yaw if absf(difference) <= step \
			else facing_yaw + signf(difference) * step
	rotation.y = facing_yaw


func set_highlighted(highlighted: bool) -> void:
	focus_ring.visible = highlighted
	identity_label.visible = highlighted
	identity_label.outline_modulate = Color("0a101b") if highlighted else Color("00000080")
	identity_label.outline_size = 5 if highlighted else 3


## The four postures the resolver distinguishes, drawn as four stances.
##
## `planted` is a defender who got there: a normal athletic dig, knees bent,
## platform square in front. `moving` is one still travelling through the
## contact. `reaching` is one at the limit of their range, which in this sport
## means going down -- deep knee, hips low, the shape a player makes when the
## ball is barely gettable. `off-axis` is one who got there but could not turn
## their body to face it, so the platform goes out to the side and the shoulders
## tilt with it.
##
## The depths are ordered so the two that matter tactically -- planted against
## reaching -- are unmistakably different at a glance from a court camera.
func _apply_dig_posture() -> void:
	var knee_bend := 34.0
	var hip_pitch := -18.0
	var drop := 0.10
	var platform_yaw := 0.0
	var platform_roll := 0.0
	match contact_posture:
		"reaching":
			## Forced down. The knee folds nearly double and the hips go with it,
			## which is the whole point of having the joint.
			knee_bend = 96.0
			hip_pitch = -42.0
			drop = 0.30
			platform_roll = 10.0
		"off-axis":
			## Got there, could not square up. Platform to the side.
			knee_bend = 52.0
			hip_pitch = -24.0
			drop = 0.16
			platform_yaw = 34.0
			platform_roll = 22.0
		"moving":
			knee_bend = 44.0
			hip_pitch = -22.0
			drop = 0.14
		_:
			pass
	body_pivot.position.y -= drop * body_height_scale
	body_pivot.rotation.x = deg_to_rad(hip_pitch * 0.24)
	for leg in [left_leg, right_leg]:
		## Thigh forward, shank back under it. Splitting the fold across both
		## bones is what keeps the foot near the floor instead of swinging the
		## whole leg out in front.
		leg.rotation_degrees.x = -knee_bend * 0.45
		var knee := leg.get_node("Knee") as Node3D
		knee.rotation_degrees.x = knee_bend
	## The platform: two arms held *together* in front, not spread.
	##
	## The old dig swung them to -70 degrees with an 18-degree outward tilt each,
	## which under Godot's YXZ order reads as both arms straight out to the sides.
	## A platform is the opposite shape -- forearms joined, angled down and
	## forward -- so the pitch is shallower and the arms are brought inward
	## rather than splayed. `platform_yaw` then swings the whole platform off to
	## one side for a defender who could not square up, which is the thing worth
	## seeing.
	## **Positive, and that is a fix.** Rotating an arm about +X by theta puts its
	## tip at (up, z) = (-cos theta, -sin theta), and the rig faces -Z -- so a
	## *negative* lead swings the platform out behind the player. It had been
	## negative since the pose existed, along with every other arm angle in this
	## file, and it was invisible because the only tool that photographed a dig
	## stood behind the row. The instrument was wrong, so what it certified was
	## wrong. See `docs/design/POSE_ORIENTATION.md`.
	var lead := 46.0 - hip_pitch * 0.30
	## Converging, not splayed -- and this sign was inverted too. Rotating an arm
	## about +Z by theta moves its hand to x = sin theta, so the *left* arm needs a
	## positive roll to bring its hand toward the centreline and the right arm a
	## negative one. Reversed, as it was, the two hands travel apart and the pose
	## becomes a shrug.
	##
	## Large enough that the forearms actually meet. Seven degrees was tuned by
	## eye against a camera standing behind the player, where two arms swung out
	## behind the back happen to overlap and read as joined.
	var spread := 26.0
	left_arm.rotation_degrees = Vector3(
		lead, platform_yaw, spread + platform_roll
	)
	right_arm.rotation_degrees = Vector3(
		lead, platform_yaw, -spread + platform_roll
	)
	## **Locked.** This is the one pose in the game whose elbows are deliberately
	## straighter than a resting arm, and it is the whole reason a platform is a
	## platform: two forearms joined into one flat surface. Bend either one and
	## the ball leaves at an angle nobody chose.
	##
	## It also does the legibility work the knee does lower down. A dig and a set
	## are both "arms in front of the body"; locked against folded is what makes
	## them different actions rather than two similar frames.
	_set_elbow(left_arm, 0.0)
	_set_elbow(right_arm, 0.0)


## Bend one arm at the elbow. Positive folds the forearm forward, matching the
## knee's convention of positive folding the shank back -- both are "toward the
## way the joint actually goes".
func _set_elbow(arm: Node3D, bend_degrees: float) -> void:
	var elbow := arm.get_node_or_null("Elbow") as Node3D
	if elbow != null:
		elbow.rotation_degrees = Vector3(bend_degrees, 0.0, 0.0)


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
	var gait_angle := sin(stride_cycle * TAU) * 32.0 * gait_blend
	## Arms counter-swing against the legs, which is what walking looks like and
	## what a pair of hanging sticks does not. Opposite arm to leg, and shallower,
	## because an arm swings less than the leg driving it.
	left_arm.rotation_degrees = Vector3(-gait_angle * 0.46, 0.0, -12.0)
	right_arm.rotation_degrees = Vector3(gait_angle * 0.46, 0.0, 12.0)
	left_arm.position = Vector3(-shoulder_offset.x, shoulder_offset.y, 0.0)
	right_arm.position = Vector3(shoulder_offset.x, shoulder_offset.y, 0.0)
	left_leg.rotation_degrees = Vector3(gait_angle, 0.0, 0.0)
	right_leg.rotation_degrees = Vector3(-gait_angle, 0.0, 0.0)
	## Knees straighten every frame before a pose folds them, so a dig does not
	## leave the defender walking around bent for the rest of the rally.
	for leg in [left_leg, right_leg]:
		(leg.get_node("Knee") as Node3D).rotation_degrees = Vector3.ZERO
	## Elbows go back to the ready bend for the same reason -- and the ready bend
	## is not zero, because a nobody stands with their arms locked straight. It
	## deepens a little as the arms swing, which is what a moving player's do.
	var swing_bend := absf(gait_angle) * 0.30
	_set_elbow(left_arm, READY_ELBOW_BEND + swing_bend)
	_set_elbow(right_arm, READY_ELBOW_BEND + swing_bend)
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
		## The contact actor faces the ball, which overrides whatever their
		## footwork was pointing them at.
		_turn_toward(atan2(-contact_direction.x, -contact_direction.y))
	if not is_contact_actor:
		return
	var striking_arm := left_arm if dominant_hand == "Left" else right_arm
	var guide_arm := right_arm if dominant_hand == "Left" else left_arm
	match event_type:
		RallyEventModel.EventType.SERVE:
			body_pivot.rotation.x = -0.10
			var serve_swing := clampf(phase * 1.8, 0.0, 1.0)
			## Up and a little in front at contact, and the toss arm raised in
			## front rather than behind the shoulder.
			striking_arm.rotation_degrees.x = -190.0 * serve_swing
			guide_arm.rotation_degrees.x = 100.0
			## Cocked, then thrown. The arm straightens *through* the swing rather
			## than travelling as a rigid stick, which is where the whip comes
			## from -- and it is the reason a serve now reads as a serve at the
			## moment before contact rather than only at contact.
			_set_elbow(striking_arm, lerpf(96.0, 8.0, serve_swing))
			## The toss arm stays long. A toss with a bent elbow is a bad toss.
			_set_elbow(guide_arm, 12.0)
		RallyEventModel.EventType.RECEPTION, RallyEventModel.EventType.DEFENSE:
			## A dig is drawn by bending, not by squashing.
			##
			## This used to scale the whole actor on one axis -- head, produce
			## torso, beak and all -- because the leg was a single capsule with
			## nothing to bend. It now has a knee, and how far that knee folds is
			## the simulator's own verdict on the contact rather than a constant.
			##
			## Being forced low is tactically real: a defender who had to drop to
			## reach a ball played it differently from one who stayed on their
			## feet, and `_reception_pass_result` already decided which happened.
			## `contact_posture` is that decision, built from the defender's reach
			## margin, how deep into the edge of their range the ball was, and how
			## well their body could face it. Playback reads it; it does not
			## invent it.
			_apply_dig_posture()
		RallyEventModel.EventType.SET:
			## Hands at the forehead, elbows out. The upper arms come up less far
			## than they used to and the forearms finish the reach, which is what
			## makes a set a set: the classic triangle of two folded arms over the
			## face, rather than two straight arms held overhead like a block.
			## Upper arms forward and nearly level, forearms vertical. The elbow
			## adds to the shoulder's pitch, so the forearm's true angle is roughly
			## 100 + 90 = 190 -- straight up and a shade back, which puts the hands
			## over the forehead. Raising the shoulder further, as a first pass did
			## at 118, folds the forearm *over and behind* the head and the pose
			## reads as a flex rather than a set.
			left_arm.rotation_degrees = Vector3(100.0, 0.0, -18.0)
			right_arm.rotation_degrees = Vector3(100.0, 0.0, 18.0)
			_set_elbow(left_arm, 90.0)
			_set_elbow(right_arm, 90.0)
		RallyEventModel.EventType.ATTACK:
			body_pivot.rotation.x = -0.16
			left_leg.rotation_degrees.x = 18.0
			right_leg.rotation_degrees.x = -26.0
			guide_arm.rotation_degrees.x = -95.0
			var swing := clampf(phase, 0.0, 1.0)
			## Sweeps *over the top*: cocked up and back at -160, carrying on
			## through vertical to -260, which is forward and slightly up. Going
			## the other way -- increasing toward -80 -- swung the arm down behind
			## the player, which is what it used to do.
			striking_arm.rotation_degrees.x = -160.0 - 100.0 * swing
			## Elbow high and folded behind the head, opening through contact. A
			## straight arm rotating from behind the ear is a windmill; a hitter is
			## a whip, and the difference is visible from any distance the attack
			## is watched at.
			_set_elbow(striking_arm, lerpf(112.0, 6.0, swing))
			## The guide arm pulls down bent, which is what it actually does.
			_set_elbow(guide_arm, 46.0)
		RallyEventModel.EventType.BLOCK:
			left_leg.rotation_degrees.x = 12.0
			right_leg.rotation_degrees.x = 12.0
			left_arm.position.y = shoulder_offset.y + 0.06
			right_arm.position.y = shoulder_offset.y + 0.06
			left_arm.rotation_degrees = Vector3(175.0, 0.0, -8.0)
			right_arm.rotation_degrees = Vector3(175.0, 0.0, 8.0)
			## Straight, and deliberately so. A block that bends at the elbow is a
			## block that gets driven back through the net, and keeping these at
			## nearly zero is what makes a block read as a *wall* next to a set's
			## folded triangle -- the two poses put the arms in nearly the same
			## place, and the elbow is the only thing telling them apart.
			_set_elbow(left_arm, 4.0)
			_set_elbow(right_arm, 4.0)


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

	## The arm is two bones now, for the same reason the leg is.
	##
	## A single capsule from shoulder to hand cannot bend, so every action was
	## drawn with a straight stick and the difference between a *locked* platform
	## and a *folded* set had nowhere to live. Elbow bend is diagnostic of what a
	## voli is doing: a dig has the elbows locked straight because that is what
	## makes a platform flat, a set has them folded out at the temples, a swing
	## has them cocked behind the head. Those are not stylings, they are how you
	## tell the three apart from the stands.
	##
	## Upper arm slightly shorter than the forearm-and-hand it carries, which is
	## roughly true and keeps the elbow reading as an elbow rather than as a
	## midpoint.
	var arm_spec: Dictionary = silhouette.get("arm", {})
	arm_spec["shape"] = "cylinder"
	var arm_height := float(arm_spec.get("height", 0.88))
	var upper_length := arm_height * UPPER_ARM_SHARE
	var fore_length := arm_height - upper_length
	arm_bone_lengths = Vector2(upper_length, fore_length)
	var upper_spec := arm_spec.duplicate()
	upper_spec["height"] = upper_length
	## The forearm picks up where the upper arm left off, so the two read as one
	## limb rather than as two cylinders of unrelated width.
	var fore_spec := arm_spec.duplicate()
	fore_spec["height"] = fore_length
	fore_spec["top_radius"] = arm_spec.get("bottom_radius", 0.08)
	for arm in [left_arm, right_arm]:
		var arm_mesh := arm.get_node("Mesh") as MeshInstance3D
		arm_mesh.mesh = BodyTypeModelsScript.build_mesh(upper_spec)
		arm_mesh.position = Vector3(0.0, -upper_length * 0.5, 0.0)
		var elbow := arm.get_node("Elbow") as Node3D
		elbow.position = Vector3(0.0, -upper_length, 0.0)
		elbow.rotation_degrees = Vector3.ZERO
		var fore_mesh := elbow.get_node("Mesh") as MeshInstance3D
		fore_mesh.mesh = BodyTypeModelsScript.build_mesh(fore_spec)
		fore_mesh.position = Vector3(0.0, -fore_length * 0.5, 0.0)

	## Legs are placed so the foot lands just above the floor whatever the hip
	## height and shank length are, rather than by the pair of literals that
	## happened to suit the one rig.
	var leg_spec: Dictionary = silhouette.get("leg", {})
	leg_spec["shape"] = "cylinder"
	var leg_height := float(leg_spec.get("height", 0.74))
	var shoe_spec: Dictionary = silhouette.get("shoe", {})
	## The leg is two bones now, not one.
	##
	## A single capsule from hip to shoe cannot be bent, which is why a dig used
	## to be drawn by squashing the whole actor on one axis. Being forced low is
	## a tactical fact -- a defender who had to go to their knees to reach a ball
	## did something different from one who stayed on their feet -- so it needs a
	## joint that can say so rather than a scale factor that flattens the head
	## along with everything else.
	##
	## Thigh slightly longer than shank, which is both roughly true and the ratio
	## that keeps the knee reading as a knee when it folds.
	var thigh_length := leg_height * THIGH_SHARE
	var shank_length := leg_height - thigh_length
	leg_bone_lengths = Vector2(thigh_length, shank_length)
	var thigh_spec := leg_spec.duplicate()
	thigh_spec["height"] = thigh_length
	## The shank tapers on from where the thigh left off, so the two bones read
	## as one limb rather than two stacked cylinders of unrelated width.
	var shank_spec := leg_spec.duplicate()
	shank_spec["height"] = shank_length
	shank_spec["top_radius"] = leg_spec.get("bottom_radius", 0.07)
	for index in [0, 1]:
		var leg: Node3D = left_leg if index == 0 else right_leg
		var side := -1.0 if index == 0 else 1.0
		leg.position = Vector3(side * hip_offset.x, hip_offset.y, 0.0)
		var leg_mesh := leg.get_node("Mesh") as MeshInstance3D
		leg_mesh.mesh = BodyTypeModelsScript.build_mesh(thigh_spec)
		leg_mesh.position = Vector3(0.0, -thigh_length * 0.5, 0.0)
		var knee := leg.get_node("Knee") as Node3D
		knee.position = Vector3(0.0, -thigh_length, 0.0)
		knee.rotation_degrees = Vector3.ZERO
		var shank_mesh := knee.get_node("Mesh") as MeshInstance3D
		shank_mesh.mesh = BodyTypeModelsScript.build_mesh(shank_spec)
		shank_mesh.position = Vector3(0.0, -shank_length * 0.5, 0.0)
		var shoe := knee.get_node("Shoe") as MeshInstance3D
		shoe.mesh = BodyTypeModelsScript.build_mesh(shoe_spec)
		shoe.position = Vector3(0.0, -shank_length, -0.06)
		## A box foot is authored lying flat already; only the capsule shoe
		## needs standing on its side to become a foot rather than a leg.
		shoe.rotation_degrees = Vector3(
			90.0 if str(shoe_spec.get("shape", "capsule")) == "capsule" else 0.0,
			0.0, 0.0
		)
	_build_cosmetics()
	_build_face()


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


## Two eyes and a seven-segment mouth, parented to the head so they travel with
## every turn and pose the rig already produces.
##
## Kept under a `Face` node and tagged with their own meta rather than reusing
## the cosmetic tag: `_build_cosmetics` frees everything it finds, so sharing the
## tag would mean a face that silently vanished the next time a stem or a wing
## was rebuilt.
func _build_face() -> void:
	var face := head.get_node_or_null("Face")
	if face != null:
		face.free()
	face = Node3D.new()
	face.name = "Face"
	head.add_child(face)
	var head_spec: Dictionary = silhouette.get("head", {})
	var radius := float(head_spec.get("radius", 0.13))
	## Heads are slightly wide ellipsoids, so the vertical semi-axis is half the
	## authored height rather than the radius. Using the radius for both puts the
	## eyes too high on every body type at once, which is the kind of error that
	## looks like a style until you measure it.
	var half_height := float(head_spec.get("height", radius * 2.0)) * 0.5
	for part in FaceExpressionsScript.parts(
		expression, radius, half_height, _mouth_override()
	):
		var instance := MeshInstance3D.new()
		instance.name = str(part.get("name", "Feature"))
		instance.mesh = BodyTypeModelsScript.build_mesh(part)
		instance.position = part.get("position", Vector3.ZERO)
		instance.rotation_degrees = part.get("rotation", Vector3.ZERO)
		instance.set_meta("face", true)
		face.add_child(instance)


## Some body types already have something where the mouth goes.
##
## Feli has a muzzle and Avi has a beak, both sitting exactly on the spot the
## mouth is drawn -- so the first pass produced a cat and a bird with invisible
## expressions, the mouth buried inside a solid. A muzzle wants the mouth drawn
## on it; a beak *is* the mouth, and gets none.
##
## Read off the cosmetic's own spec rather than tabulated per body type. Those
## numbers already exist in `body_type_models.gd`, and a second copy here would
## be a constant wearing the muzzle's name -- silently wrong the first time the
## muzzle moved.
func _mouth_override() -> Dictionary:
	var head_spec: Dictionary = silhouette.get("head", {})
	var head_radius := float(head_spec.get("radius", 0.13))
	for raw_part in silhouette.get("extras", []):
		var part: Dictionary = raw_part
		match str(part.get("name", "")):
			"Muzzle":
				var part_position: Vector3 = part.get("position", Vector3.ZERO)
				var part_radius := float(part.get("radius", 0.1))
				## Extras are placed in BodyPivot space; the face lives under the
				## head, so the anchor has to come back by the head's own height.
				## The muzzle's *centre*, in head-local space, plus its own
				## semi-axes -- the mouth then wraps it the same way it would wrap
				## a small head, instead of being drawn flat somewhere near it.
				return {
					"anchor": Vector3(
						0.0,
						part_position.y - head.position.y,
						part_position.z,
					),
					"radius": part_radius,
					"half_height": float(part.get("height", part_radius * 2.0)) * 0.5,
					"scale": clampf(part_radius / maxf(head_radius, 0.001), 0.2, 1.0),
				}
			"Beak":
				return {"omit": true}
	return {}


func _face_features() -> Array[MeshInstance3D]:
	var found: Array[MeshInstance3D] = []
	var face := head.get_node_or_null("Face") if head != null else null
	if face == null:
		return found
	for node in face.get_children():
		var mesh_node := node as MeshInstance3D
		if mesh_node != null:
			found.append(mesh_node)
	return found


## Swap the face. Rebuilds rather than reposing, because nine small boxes is
## cheaper to recreate than to track, and expressions change on the scale of
## weeks rather than frames.
func set_expression(new_expression: String, light_mode: bool = false) -> void:
	if not FaceExpressionsScript.has(new_expression):
		return
	expression = new_expression
	_build_face()
	apply_ui_palette(light_mode)
