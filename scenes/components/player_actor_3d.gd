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
## How long this voli's legs are for their height, from `stride_length_m`.
var leg_length_scale: float = 1.0
var leg_bone_lengths: Vector2 = Vector2(0.40, 0.34)
var arm_bone_lengths: Vector2 = Vector2(0.40, 0.48)
## How strained the contact the simulator resolved was. Not a visual choice:
## `_reception_pass_result` classifies every reception and dig as planted,
## moving, reaching or off-axis from the defender's reach margin, how far into
## the edge of their range the ball was, and how well their body could face it.
## Playback reads that verdict rather than inventing a pose.
var contact_posture: String = "planted"
## What the contact *did* to them, as opposed to how strained it was.
## `_reception_recovery` decides this; playback draws it and does not invent it.
## "platform", "knee", "fall" or "blown_away" -- see `rally_simulator.gd`.
var contact_recovery: String = "platform"
## Which of the five faces the actor is wearing. Purely presentational today --
## nothing in the simulator sets it yet -- so it stays a plain assignment rather
## than being derived from state that does not exist.
var expression: String = FaceExpressionsScript.NEUTRAL
## Where the actor is currently facing, kept between frames so a change of
## heading can be turned into rather than snapped to.
var facing_yaw: float = 0.0
var has_facing: bool = false
## Where the head is looking, relative to where the body is facing. A voli can
## watch the ball without turning to it -- a defender tracking a set across the
## net keeps their platform pointed where they expect the attack, and a setter
## reads the block over their shoulder. Separating the two is what stops every
## actor being a mannequin that swivels as one piece.
var look_yaw: float = 0.0
var look_pitch: float = 0.0
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

## How far a head turns off the body before the body has to come with it. A neck
## does not reach ninety degrees, and a head that does reads as broken rather
## than as attentive -- so the look is clamped rather than the target being
## assumed reachable.
const HEAD_YAW_LIMIT_DEGREES: float = 62.0
const HEAD_PITCH_LIMIT_DEGREES: float = 24.0

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
		var part_alpha := float(cosmetic.get_meta("alpha", 1.0))
		match str(cosmetic.get_meta("color_key", "skin")):
			"kit":
				_apply_material_color(cosmetic, team_color, part_alpha)
			"crown":
				_apply_material_color(cosmetic, crown_color, part_alpha)
			"literal":
				_apply_material_color(
					cosmetic, cosmetic.get_meta("color_value"), part_alpha
				)
			_:
				_apply_material_color(cosmetic, skin_color, part_alpha)
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
	## Small, because the fold now does most of the lowering itself. A squat that
	## bends the right way already shortens the leg's vertical span; the explicit
	## drop is only the extra sink the hips add, and at the old values the two
	## together pushed the feet through the floor.
	var drop := 0.035
	var platform_yaw := 0.0
	var platform_roll := 0.0
	## How far the whole body twists toward the ball, and how far the *far* leg
	## steps across to let it. Zero for the two square postures.
	var torso_yaw := 0.0
	var far_leg_lead := 0.0
	## Whole-body lean, distinct from the hip pitch that folds the player up.
	var body_tilt := 0.0
	## Mid-stride offsets, so a defender who arrived on the move is caught on the
	## move rather than standing still in a lower stance.
	var stride := 0.0
	match contact_posture:
		"reaching":
			## Forced down, and *leaning*. The knee folds nearly double and the
			## hips go with it, but the read that separates this from a deep
			## planted stance is the whole body committing forward -- a lunge is
			## a player who has given up their balance to get there, and a
			## crouch is not.
			knee_bend = 78.0
			hip_pitch = -38.0
			drop = 0.09
			platform_roll = 10.0
			## Enough lean to read as committed, not so much that the figure folds
			## into a ball. At -26 the torso came down over the knees and the legs
			## disappeared behind it, which loses the very thing the knee is for.
			body_tilt = -14.0
		"off-axis":
			## Got there, could not square up. The ball is off to one side and the
			## platform stretches out after it -- but the interesting part is what
			## the rest of the body does to keep the two forearms together.
			##
			## The **far** shoulder and the **far** leg rotate forward. That is
			## the whole trick of an off-axis dig: the near arm can reach the ball
			## on its own, and the only way the far arm joins it is if that side
			## of the body comes round. So the torso twists, the far leg steps
			## across behind the reach, and the platform ends up angled across the
			## body instead of square to it.
			##
			## Without the twist this was a player standing square with both arms
			## swung sideways, which is not a posture anybody has ever been in.
			knee_bend = 52.0
			hip_pitch = -24.0
			drop = 0.06
			platform_yaw = 30.0
			platform_roll = 14.0
			torso_yaw = -22.0
			far_leg_lead = 22.0
		"moving":
			## Caught mid-step. The two legs are deliberately *unequal*: one is
			## still driving, the other is already planting, which is what makes
			## this read as arriving rather than as a shallower version of planted.
			knee_bend = 44.0
			hip_pitch = -22.0
			drop = 0.05
			stride = 30.0
		_:
			pass
	body_pivot.position.y -= drop * body_height_scale
	body_pivot.rotation.x = deg_to_rad(hip_pitch * 0.24 + body_tilt)
	body_pivot.rotation.y = deg_to_rad(torso_yaw)
	## **The head keeps watching the ball.**
	##
	## An off-axis dig twists the whole body to get the far arm across, and the
	## head came with it -- so the defender ended up looking where they wanted
	## the ball to *go* rather than where it was coming *from*. That is backwards
	## from how anybody plays: you track the hitter and the flight, and the
	## platform is aimed by feel underneath you.
	##
	## Counter-rotating by the torso's own twist holds the head on the original
	## line, and the neck clamp decides how much survives -- past its limit the
	## head genuinely does have to travel with the shoulders, which is also true.
	look_yaw = clampf(
		-deg_to_rad(torso_yaw),
		-deg_to_rad(HEAD_YAW_LIMIT_DEGREES),
		deg_to_rad(HEAD_YAW_LIMIT_DEGREES),
	)
	## Eyes up the incoming line rather than down at the platform.
	look_pitch = deg_to_rad(-HEAD_PITCH_LIMIT_DEGREES * 0.45)
	_apply_head_look()
	for index in [0, 1]:
		var leg: Node3D = left_leg if index == 0 else right_leg
		## Thigh forward, shank back under it. Splitting the fold across both
		## bones is what keeps the foot near the floor instead of swinging the
		## whole leg out in front.
		##
		## `far_leg_lead` is added to the left leg only, because `torso_yaw` is
		## authored for a ball off to the player's right and the left side is the
		## one that has to travel. `stride` splits the pair the other way, one
		## forward and one back.
		var lead_for_leg := (far_leg_lead if index == 0 else 0.0) \
			+ (stride if index == 0 else -stride)
		## **A knee folds backward.**
		##
		## This had the thigh swinging back and the shank swinging *forward*,
		## which puts the joint's point behind the leg -- a knee bending the wrong
		## way. It survived because a crouch of roughly the right height is still a
		## crouch of roughly the right height, and the tell is the one detail the
		## knee was added to show.
		##
		## Correct squat: the thigh rotates forward as the hips drop, and the
		## shank folds back by the same amount so it finishes near vertical and
		## the foot stays under the body. Equal and opposite is what keeps the
		## foot on the floor at any depth.
		var thigh_lift := knee_bend * 0.45
		leg.rotation_degrees.x = thigh_lift + lead_for_leg
		var knee := leg.get_node("Knee") as Node3D
		## The trailing leg stays straighter -- it is still pushing.
		knee.rotation_degrees.x = -thigh_lift \
			* (0.6 if index == 1 and stride > 0.0 else 1.0) * 2.0
	## The platform: two arms held *together* in front, not spread.
	##
	## The old dig swung them to -70 degrees with an 18-degree outward tilt each,
	## which under Godot's YXZ order reads as both arms straight out to the sides.
	## A platform is the opposite shape -- forearms joined, angled down and
	## forward -- so the pitch is shallower and the arms are brought inward
	## rather than splayed. `platform_yaw` then swings the whole platform off to
	## one side for a defender who could not square up, which is the thing worth
	## seeing.
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
	## Stretched, not swung. On an off-axis dig the two arms are doing different
	## jobs: the near one is already on the ball, and the far one is chasing it
	## across the body. So the far arm carries extra yaw and converges less --
	## it has further to go and cannot afford to be pulled inward as hard.
	##
	## Both arms rotating identically is what made the old off-axis pose read as
	## a shrug with a twist. A platform that is genuinely reaching is asymmetric.
	var far_arm_yaw := platform_yaw + (16.0 if torso_yaw != 0.0 else 0.0)
	var far_arm_spread := spread * (0.45 if torso_yaw != 0.0 else 1.0)
	left_arm.rotation_degrees = Vector3(
		lead, far_arm_yaw, far_arm_spread + platform_roll
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
	_apply_recovery_state()


## The four things that can happen to a defender who plays a ball.
##
## Layered *over* the posture rather than replacing it, because the two are
## independent: a reaching contact that puts someone on one knee still started
## as a reach, and the pose should say both. So this only adds -- it drops the
## hips, folds a leg, rolls the body -- and never rewrites what the platform was
## doing.
##
## Each state is drawn as a *body*, not as a tint or a marker. A special move
## that needs an icon to be understood has not been drawn.
func _apply_recovery_state() -> void:
	if contact_recovery == "platform":
		return
	## Where the feet are *now*, before this state folds them. The posture already
	## put them on the floor, crouch and all, so this is the height the body has
	## to come back to -- measuring against a bare y = 0 instead would quietly
	## undo whatever sink the dig itself asked for.
	var contact_floor := _lowest_body_point()
	## And where the hips are, for the same reason. A roll of forty degrees turns
	## the body about the *feet*, which slides the whole rig sideways off the spot
	## it was standing on -- the fallen voli ended up beside its own floor marker
	## rather than on it.
	var contact_hips := _hip_offset_from_actor()
	match contact_recovery:
		"knee":
			## A half-kneel: one shin folded flat behind, the other leg braced in
			## front. Asymmetry is the whole read -- two knees down is kneeling,
			## one is a player who *went* down to finish a play.
			##
			## The two legs are posed to reach the *same* depth below the hip, so
			## the down knee and the braced foot arrive at the floor together. A
			## pose where one reaches further leaves the other hanging in the air
			## once the body is planted, which is what "kneeling in mid-air"
			## actually was.
			body_pivot.rotation.x -= deg_to_rad(14.0)
			left_leg.rotation_degrees.x = -12.0
			(left_leg.get_node("Knee") as Node3D).rotation_degrees.x = -100.0
			right_leg.rotation_degrees.x = 75.0
			(right_leg.get_node("Knee") as Node3D).rotation_degrees.x = -43.0
		"fall":
			## Off their feet and onto a hip, still facing the ball. Rolled rather
			## than dropped: a defender who falls has been taken sideways, and the
			## roll is what separates this from a deeper crouch. Both legs fold
			## tight so nothing props the body back up.
			body_pivot.rotation.x -= deg_to_rad(26.0)
			body_pivot.rotation.z += deg_to_rad(42.0)
			## Thighs well past horizontal, so the folded legs finish at hip height
			## and the *hip* becomes the lowest thing on the body. With the legs
			## reaching lower than the hip the floor solve plants a shoe instead
			## and leaves the body standing over it, which is a crouch.
			left_leg.rotation_degrees.x = 128.0
			(left_leg.get_node("Knee") as Node3D).rotation_degrees.x = -118.0
			right_leg.rotation_degrees.x = 138.0
			(right_leg.get_node("Knee") as Node3D).rotation_degrees.x = -126.0
		"blown_away":
			## Not a play, an impact. The body pitches *backward* -- the only pose
			## in the game that does, since a block bends forward at -0.12 -- the
			## arms are driven up and back off the ball rather than held on it, and
			## the legs come up in front. The backward pitch is the entire tell:
			## everything else a defender does goes toward the ball.
			body_pivot.rotation.x += deg_to_rad(42.0)
			body_pivot.rotation.z += deg_to_rad(12.0)
			left_arm.rotation_degrees = Vector3(-138.0, 0.0, -34.0)
			right_arm.rotation_degrees = Vector3(-146.0, 0.0, 30.0)
			_set_elbow(left_arm, 52.0)
			_set_elbow(right_arm, 44.0)
			## Past horizontal, so the feet finish *above* the hip and the body
			## plants on its back rather than on a shoe.
			left_leg.rotation_degrees.x = 110.0
			right_leg.rotation_degrees.x = 95.0
			(left_leg.get_node("Knee") as Node3D).rotation_degrees.x = -60.0
			(right_leg.get_node("Knee") as Node3D).rotation_degrees.x = -50.0
			## Eyes still up the line the ball came from, because they are being
			## pushed away from it rather than turning from it.
			look_pitch = deg_to_rad(-HEAD_PITCH_LIMIT_DEGREES)
			_apply_head_look()
		_:
			return
	_settle_to_floor(contact_floor, contact_hips)


## Drop the posed body until its lowest part rests on the court.
##
## This replaced three hand-tuned drops, and the reason is worth keeping: a drop
## written as a number is a claim about how far a *particular* pose lifts a
## *particular* body off the floor, and both halves of that claim change with
## every silhouette and every angle. The three numbers were tuned by eye on one
## portfolio plate of four subjects; measured, they put a shoe up to 0.6 m
## underground on the same four.
##
## Solving it instead makes the pose the only thing an author has to get right.
## Whatever reaches lowest -- a knee, a shoe, a hip, a hand -- is what the body
## comes to rest on, which is also what "landing" means.
func _settle_to_floor(floor_height: float, hips: Vector3) -> void:
	var drift := hips - _hip_offset_from_actor()
	body_pivot.position.x += drift.x
	body_pivot.position.z += drift.z
	body_pivot.position.y += floor_height - _lowest_body_point()


## Where the hips sit relative to the actor. Read from the shorts, which is the
## one mesh that is the hip rather than merely near it.
func _hip_offset_from_actor() -> Vector3:
	return (global_transform.affine_inverse() * shorts.global_transform).origin


## The lowest point of the body, in the actor's own space.
##
## Measured relative to `self` rather than in world space so it survives the
## actor being moved or turned on the court, and taken from mesh bounds rather
## than from bone maths because the shoe hangs off the shin and the produce
## bodies are spheres -- neither is where a limb length says it is.
func _lowest_body_point() -> float:
	var into_actor := global_transform.affine_inverse()
	var lowest := INF
	var pending: Array[Node] = [body_pivot]
	while not pending.is_empty():
		var current: Node = pending.pop_back()
		for child in current.get_children():
			pending.append(child)
		if not (current is VisualInstance3D):
			continue
		var visual := current as VisualInstance3D
		if not visual.visible or visual is Label3D:
			continue
		var box := visual.get_aabb()
		var placement := into_actor * visual.global_transform
		for corner in 8:
			lowest = minf(lowest, (placement * box.get_endpoint(corner)).y)
	return 0.0 if is_inf(lowest) else lowest


## Point the head at a spot on the court, independently of where the body faces.
##
## `world_yaw` is an absolute heading in the same convention `set_pose` uses --
## `atan2(-dx, -dz)` for a direction in court space. The turn is stored relative
## to the body and clamped, so a target behind the player turns the head as far
## as a neck goes and no further; the body has to do the rest.
func look_toward(world_yaw: float, pitch_degrees: float = 0.0) -> void:
	var relative := angle_difference(facing_yaw, world_yaw)
	look_yaw = clampf(
		relative,
		-deg_to_rad(HEAD_YAW_LIMIT_DEGREES),
		deg_to_rad(HEAD_YAW_LIMIT_DEGREES),
	)
	look_pitch = deg_to_rad(clampf(
		pitch_degrees, -HEAD_PITCH_LIMIT_DEGREES, HEAD_PITCH_LIMIT_DEGREES
	))
	_apply_head_look()


## Forget the target and face straight ahead again.
func clear_look() -> void:
	look_yaw = 0.0
	look_pitch = 0.0
	_apply_head_look()


func _apply_head_look() -> void:
	if head != null:
		head.rotation = Vector3(look_pitch, look_yaw, 0.0)


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
	## The head keeps its own heading through a pose change. Everything else here
	## is reset each frame; the look is not, because it is a decision about what
	## the voli is watching rather than a property of the action they are in.
	_apply_head_look()
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
			## A set is a *motion*, and drawing only its middle threw away the
			## half that reads. Preparation is arms up with the elbows carried
			## wide and the hands at the forehead; the release is that same shape
			## extending -- elbows opening, upper arms rising, hands finishing
			## above and in front. Phase runs one into the other rather than
			## picking a frame.
			##
			## The elbow does the work: at 98 degrees the forearms are vertical
			## beside the head, and opening toward 22 is the push. Rotating the
			## shoulder alone would swing the whole arm through the ball.
			var release := clampf(phase, 0.0, 1.0)
			var set_pitch := lerpf(96.0, 132.0, release)
			## **The hands are together, because the ball is between them.**
			##
			## The flare was signed the wrong way and spread the forearms apart
			## through the whole motion, so both halves of a set were drawn as a
			## player holding nothing. A set is two hands cupping one ball: the
			## forearms converge for the preparation *and* the push, and only the
			## follow-through opens outward once the ball has gone.
			##
			## Positive rolls the hand toward the centreline, so the left arm
			## takes `+flare` and the right `-flare` -- the opposite of what a
			## spread would use.
			var follow := clampf((release - 0.78) / 0.22, 0.0, 1.0)
			var set_flare := lerpf(lerpf(21.0, 15.0, release), -20.0, follow)
			left_arm.rotation_degrees = Vector3(set_pitch, 0.0, set_flare)
			right_arm.rotation_degrees = Vector3(set_pitch, 0.0, -set_flare)
			var set_elbow := lerpf(98.0, 22.0, release)
			_set_elbow(left_arm, set_elbow)
			_set_elbow(right_arm, set_elbow)
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
			## A block *presses*. Straight up is a player reaching; over the net
			## is a player taking space, and the difference is a slight forward
			## lean with the arms angled ahead of vertical rather than on it.
			##
			## The legs kick forward, not back. A blocker leaves the floor from a
			## squat and the shins swing under and *ahead* of the body on the way
			## up -- trailing them behind is a hurdler, not a jump.
			body_pivot.rotation.x = -0.12
			left_leg.rotation_degrees.x = 26.0
			right_leg.rotation_degrees.x = 22.0
			for leg in [left_leg, right_leg]:
				## Backward, like every other knee in the file.
				(leg.get_node("Knee") as Node3D).rotation_degrees.x = -34.0
			left_arm.position.y = shoulder_offset.y + 0.06
			right_arm.position.y = shoulder_offset.y + 0.06
			left_arm.rotation_degrees = Vector3(158.0, 0.0, -8.0)
			right_arm.rotation_degrees = Vector3(158.0, 0.0, 8.0)
			## Straight, and deliberately so. A block that bends at the elbow is
			## a block that gets driven back through the net, and keeping these
			## near zero is what makes a block read as a *wall* next to a set's
			## folded triangle -- the two poses put the arms in nearly the same
			## place, and the elbow is the only thing telling them apart.
			_set_elbow(left_arm, 4.0)
			_set_elbow(right_arm, 4.0)

func _apply_material_color(
	mesh: MeshInstance3D, color: Color, alpha: float = 1.0
) -> void:
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(color, alpha)
	material.roughness = 0.72
	if alpha < 0.999:
		## Alpha scissor rather than blend would give a stipple; blend is right
		## for a membrane. Depth draw stays on so two overlapping wings still
		## read as two, and culling goes off so a wing seen from behind is not a
		## hole.
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		material.cull_mode = BaseMaterial3D.CULL_DISABLED
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
	## **Leg length is a tracked number, so the legs are drawn from it.**
	##
	## `stride_length_m` has driven cadence since the locomotion work and has
	## never touched geometry, so two players with a 0.62 m and a 1.02 m stride
	## stood on identical legs and only *moved* differently. Stride is the leg
	## measurement this model actually carries -- there is no separate inseam --
	## and it is compared against what this player's height would ordinarily
	## produce, so the scale reads "long-legged for their size" rather than
	## "tall".
	##
	## Total height is preserved. A player with the same height and longer legs
	## has a shorter torso, not a taller body, so the hips rise by exactly what
	## the legs gained and the feet stay on the floor. Without that the rig would
	## quietly contradict `height_cm`, which every reach calculation trusts.
	var expected_stride := clampf(height_cm / 100.0 * 0.43, 0.55, 1.15)
	leg_length_scale = clampf(
		stride_length_m / maxf(expected_stride, 0.01), 0.86, 1.16
	)
	## Longer legs mean a **shorter torso**, not a higher waist on the same body.
	##
	## The first pass raised the hips and left everything above them alone, so
	## the upper body simply overlapped further and the legs barely changed --
	## the whole difference went into a gap nobody could see. Two volis of the
	## same height with a 0.62 m and a 1.02 m stride should look like two
	## genuinely different builds, and the only way that happens is if the
	## torso gives back exactly what the legs take.
	##
	## So the upper body is compressed about the raised hip by the ratio of the
	## span it has left. The crown of the head lands where it always did, which
	## is what keeps `height_cm` honest, and every part between hip and head
	## moves proportionally rather than being individually re-authored.
	var leg_span := leg_bone_lengths.x + leg_bone_lengths.y
	var leg_gain := leg_span * (leg_length_scale - 1.0)
	var hip_y := hip_offset.y + leg_gain
	for leg in [left_leg, right_leg]:
		leg.scale.y = leg_length_scale
		leg.position.y = hip_y
	var crown := float(silhouette.get("rig_height", REFERENCE_RIG_HEIGHT_M))
	var upper_span := maxf(crown - hip_offset.y, 0.1)
	var squeeze := clampf((upper_span - leg_gain) / upper_span, 0.55, 1.45)
	for part in [torso, shorts, head]:
		part.position.y = hip_y + (part.position.y - hip_offset.y) * squeeze
	torso.scale.y = squeeze
	for arm in [left_arm, right_arm]:
		arm.position.y = hip_y + (arm.position.y - hip_offset.y) * squeeze
	shoulder_offset.y = hip_y + (shoulder_offset.y - hip_offset.y) * squeeze
	hip_offset.y = hip_y

	## The hips sit on the hip joint, and this is where that is decided.
	##
	## The shorts used to be placed from the *torso's* bottom, so a body type
	## with a tall torso pushed them down past the joint they are supposed to be
	## capping -- Stalk, Aubergine, Pear and Ursi worst, because their torsos are
	## the tallest. A block floating below the pelvis does not read as hips, it
	## reads as shorts worn badly.
	##
	## Derived here rather than in `_build_silhouette` because the hip has just
	## moved: two functions both placing the shorts is exactly the
	## correct-then-clobbered shape that has bitten this file three times, so the
	## one that knows the final hip height owns it outright.
	var shorts_size: Vector3 = Vector3(
		silhouette.get("shorts", {}).get("size", Vector3(0.46, 0.20, 0.32))
	)
	shorts.position.y = hip_y + shorts_size.y * 0.34

	## Scales the *whole two-bone chain*, elbow included.
	##
	## This ran straight after `_build_silhouette` and rewrote the upper arm's
	## mesh to half the length of the entire arm -- correct while an arm was one
	## capsule, and wrong the moment it became two. The mesh then reached right
	## past the elbow, which sat at the upper bone's proper end, so every bent
	## pose came out as a T: a forearm crossing an upper arm at its middle.
	##
	## Correct-then-clobbered, and the third time in this file: something builds
	## the right thing and a later line that predates it puts the old thing back.
	## The tell is always the same -- a length is measured from a whole where the
	## code below it works in parts.
	var upper_length := arm_bone_lengths.x
	var fore_length := arm_bone_lengths.y
	for arm in [left_arm, right_arm]:
		var upper_mesh := arm.get_node("Mesh") as MeshInstance3D
		upper_mesh.scale.y = arm_length_scale
		upper_mesh.position.y = -upper_length * 0.5 * arm_length_scale
		var elbow := arm.get_node("Elbow") as Node3D
		elbow.position.y = -upper_length * arm_length_scale
		var fore_mesh := elbow.get_node("Mesh") as MeshInstance3D
		fore_mesh.scale.y = arm_length_scale
		fore_mesh.position.y = -fore_length * 0.5 * arm_length_scale
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
		if part.has("alpha"):
			instance.set_meta("alpha", float(part.alpha))
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
