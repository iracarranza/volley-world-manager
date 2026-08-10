class_name PlayerActor3D
extends Node3D

const UIPalette := preload("res://scripts/data/ui_palette.gd")

const RallyEventModel := preload("res://scripts/models/rally_event.gd")
const BodyTypeModelsScript := preload("res://scripts/data/body_type_models.gd")
const FaceExpressionsScript := preload("res://scripts/data/face_expressions.gd")
const GaitBiomechanicsScript := preload("res://scripts/data/gait_biomechanics.gd")
const BlockBiomechanicsScript := preload("res://scripts/data/block_biomechanics.gd")
const LandingBiomechanicsScript := preload(
	"res://scripts/data/landing_biomechanics.gd"
)
const ServeBiomechanicsScript := preload(
	"res://scripts/data/serve_biomechanics.gd"
)
const SetBiomechanicsScript := preload("res://scripts/data/set_biomechanics.gd")

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
@onready var signature_surge: SignatureSurge3D = $SignatureSurge3D

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
## Where the forearms must point for the ball to leave the way it did, relative
## to this voli's own facing, from `PlatformAim`. Empty until playback supplies
## one, so a portfolio plate or a pose set by hand keeps the posture's own angle.
##
## The whole reason this is state rather than an argument: `set_pose` already
## carries seven parameters and the platform is not a property of the *pose*, it
## is a property of the *ball*. `contact_posture` and `contact_recovery` are
## carried the same way for the same reason.
var contact_platform_aim: Dictionary = {}
## What the contact *did* to them, as opposed to how strained it was.
## `_reception_recovery` decides this; playback draws it and does not invent it.
## "platform", "knee", "fall" or "blown_away" -- see `rally_simulator.gd`.
## The recovery and posture together choose the physical motion: an off-axis
## fall rolls sideways, a moving/reaching fall slides forward, and a blow-away
## rolls backward. The simulation still owns the cost and severity.
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
## Which way this voli is travelling relative to the way they are facing, in
## radians: 0 straight ahead, PI a backpedal, plus or minus a right angle a
## lateral shuffle.
##
## **Travel direction and facing are two different things**, and the rig only had
## one of them. `set_tactical_position` turns a voli toward wherever they moved,
## so every journey was drawn as a forward run -- a defender opening to cover
## deep ran away from the ball with their back to it, and a passer sliding along
## the line rotated to face the sideline. Smoothed for the same reason the speed
## is: one frame of displacement is too noisy to pick a gait from.
var travel_heading_offset: float = 0.0
var locomotion_bob: float = 0.0
var has_world_position: bool = false
## How fast this voli is currently travelling, in metres per second, smoothed.
##
## Derived from the distance between successive placements rather than from the
## simulator, because playback interpolates positions and the smoothed rate of
## the drawn motion is what the gait has to match -- a gait driven by the
## simulator's own speed would be right about the player and wrong about the
## figure on screen.
var ground_speed_mps: float = 0.0
## Whether this voli was off the floor on a previous frame, and what they were
## doing when they left it. A landing is *observed* rather than announced: the
## actor already sees elevation and event type every frame, so no caller has to
## learn to report a touchdown.
var _was_airborne: bool = false
var _airborne_action: String = "default"
## Seconds remaining in the current landing, counting down from the action's own
## duration. Zero means the voli is on their feet.
var _landing_remaining: float = 0.0
## Whether the pose that just ran already put the feet on the floor itself, in
## which case `_ground_the_feet` must not do it a second time. Consumed on read.
var _feet_already_grounded: bool = false

## Thigh share of total leg length. Slightly over half, which is roughly true
## and is the ratio that keeps a folded knee reading as a knee.
const THIGH_SHARE: float = 0.54

## How far in front of the ankle the shoe sits, in rig units.
##
## Named rather than inlined because the stance solve needs it: a deeply folded
## knee swings the shoe's own forward offset sideways along with the shank, and
## leaving it out put a reaching dig's feet 12 percent wider than the stance it
## was asked for.
const SHOE_FORWARD_OFFSET: float = 0.06

## How much of the torso's height the shorts cover.
##
## Less than half, deliberately: past that the kit colour becomes the body and the
## skin becomes a collar, which inverts what a singlet is.
const SHORTS_TORSO_SHARE: float = 0.34

## How far a leg can swing out from under the hip, in degrees.
##
## Roughly what a squatting athlete has and well short of a gymnast's. It exists
## because the stance is asked for in metres and some widths are simply not
## available at some depths -- see `_stance_roll`.
const HIP_ABDUCTION_LIMIT_DEGREES: float = 42.0


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

## How far a player has to actually move before their travel sets their heading.
##
## A centimetre. Below that, the displacement between two frames is mostly
## rounding and its *direction* is noise -- which is what had players spinning on
## the spot while nominally standing still.
const TRAVEL_HEADING_FLOOR_METERS: float = 0.01
## How far off their facing a voli will travel before they give up and turn to
## run. A right angle: inside it they are shuffling or backpedalling with their
## eyes where they were, outside it the movement has become a sprint to
## somewhere and the head follows the feet.
const OPEN_UP_CONE_RADIANS: float = PI * 0.5
## And the speed past which nobody shuffles, whatever the angle. `GaitBiomechanics`
## puts a run at 4.4 m/s; this sits below it, because the last stride before a
## genuine run is already too quick to keep square.
const OPEN_UP_SPEED_MPS: float = 3.6
## How quickly the drawn travel heading catches up to the real one. Smoothed for
## the same reason ground speed is: a single frame's displacement direction is
## mostly rounding, and a gait that switched between shuffle and run on it would
## strobe.
const TRAVEL_HEADING_SMOOTHING: float = 0.28

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


## Every mesh in the rig, and the subset the arms are made of.
##
## Exposed so a caller can paint the whole body one colour and the arms another
## and read the result back as a mask. The tactic sheet needs that because an arm
## traced as part of one silhouette disappears the moment it crosses the torso --
## and a pose is mostly arms, so a figure whose arms have no edge is a figure
## whose pose cannot be read.
##
## Enumerated rather than walked, because "every MeshInstance3D under here"
## would also collect the shadow quad, the focus ring and the face features, and
## two of those are not the body.
func body_meshes() -> Array[MeshInstance3D]:
	_ensure_node_bindings()
	var out: Array[MeshInstance3D] = [torso, shorts, head]
	out.append_array(arm_meshes())
	for leg in [left_leg, right_leg]:
		for path in ["Mesh", "Joint", "Knee/Mesh", "Knee/Joint", "Knee/Shoe"]:
			var mesh := leg.get_node_or_null(path) as MeshInstance3D
			if mesh != null:
				out.append(mesh)
	for feature in _face_features():
		if feature is MeshInstance3D:
			out.append(feature as MeshInstance3D)
	for cosmetic in _cosmetics():
		if cosmetic is MeshInstance3D:
			out.append(cosmetic as MeshInstance3D)
	return out


func arm_meshes() -> Array[MeshInstance3D]:
	_ensure_node_bindings()
	var out: Array[MeshInstance3D] = []
	for arm in [left_arm, right_arm]:
		for path in ["Mesh", "Joint", "Elbow/Mesh", "Elbow/Joint"]:
			var mesh := arm.get_node_or_null(path) as MeshInstance3D
			if mesh != null:
				out.append(mesh)
	return out


## Paint every mesh flat, for a mask pass. `apply_ui_palette` puts it all back.
func paint_flat(meshes: Array[MeshInstance3D], color: Color) -> void:
	for mesh in meshes:
		var material := StandardMaterial3D.new()
		material.albedo_color = color
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mesh.material_override = material
		## **The line goes with the part it belongs to.**
		##
		## The mask pass paints the body black and the arms white and reads the
		## result back. An ink twin is a child of the mesh it outlines and is not
		## in either list, so left alone it would stay dark over a white arm and
		## eat the edge of the very region being measured. Painting it the same
		## colour means an arm's mask includes its own line, which is what the
		## trace should see -- the line is part of the arm, not a thing lying on
		## top of it.
		var ink := mesh.get_node_or_null("Ink") as MeshInstance3D
		if ink != null:
			var ink_material := StandardMaterial3D.new()
			ink_material.albedo_color = color
			ink_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			ink_material.cull_mode = BaseMaterial3D.CULL_FRONT
			ink_material.grow = true
			ink_material.grow_amount = ink_metres \
				if str(mesh.name) in INK_BODY_PARTS else crown_ink_metres
			ink.material_override = ink_material


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
		## The joints are skin too. Left out of this list they kept the default
		## grey and turned every shoulder and elbow into a bead -- a worse read
		## than the gap they were added to close.
		_paint_joint(arm, skin_color)
		_paint_joint(arm.get_node("Elbow"), skin_color)
	for leg in [left_leg, right_leg]:
		## Two bones and a shoe. The shoe hangs off the knee now, not the hip.
		_apply_material_color(leg.get_node("Mesh"), skin_color)
		_apply_material_color(leg.get_node("Knee/Mesh"), skin_color)
		_paint_joint(leg, skin_color)
		_paint_joint(leg.get_node("Knee"), skin_color)
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
		## Speed, smoothed, before anything reads it.
		##
		## A single frame's displacement is far too noisy to drive a gait -- one
		## long frame would flip a walker into a sprint and back. The smoothing is
		## asymmetric on purpose: quick to pick speed up and slower to let it go,
		## so a player who is genuinely accelerating gets their run immediately
		## and one who stops decelerates out of it over a step rather than
		## freezing mid-stride.
		var frame_time := maxf(get_process_delta_time(), 0.0001)
		var instant_speed := travelled / frame_time
		var smoothing := 0.45 if instant_speed > ground_speed_mps else 0.18
		ground_speed_mps = lerpf(ground_speed_mps, instant_speed, smoothing)
		if travelled > 0.0001:
			stride_cycle += travelled / maxf(stride_length_m, 0.30)

		## Face where you are going -- but only when you are going somewhere.
		##
		## The threshold used to be the same 0.1 mm that advances the stride, and
		## at that scale the displacement between two frames is mostly rounding.
		## Its *direction* is then almost pure noise, so a player standing still
		## was handed a new random heading every frame and spun on the spot. It
		## read as endearing, apparently, which is the most dangerous kind of
		## bug: a player rotating while running is not a style, it is the facing
		## system being driven by numerical dust.
		##
		## A centimetre of travel is well under a single frame of real running
		## and far above the noise floor.
		if travelled > TRAVEL_HEADING_FLOOR_METERS:
			## Before any of this existed, facing came only from a contact
			## direction and only the contact actor was posed -- so every other
			## player translated without ever turning, and a setter walking back
			## to their release seat slid there backwards.
			##
			## Rate-limited by the same turn speed a contact facing uses, so a
			## player rounding a corner leans into it rather than snapping. The
			## contact actor's own facing is applied afterwards in `set_pose` and
			## still wins, which is correct: someone playing the ball faces the
			## ball, not their footwork.
			var travel_yaw := atan2(
				-(world_position.x - self.position.x),
				-(world_position.z - self.position.z),
			)
			## Measured before the turn below, because afterwards the two agree
			## by construction and the answer is always "forwards".
			travel_heading_offset = lerp_angle(
				travel_heading_offset,
				angle_difference(facing_yaw, travel_yaw),
				TRAVEL_HEADING_SMOOTHING,
			)
			## **Opening up is a decision, and it was being made for everybody.**
			##
			## Turning to face wherever you moved is right for a setter jogging
			## back to their seat and wrong for almost everything else a defender
			## does. A player watching the ball who has to cover two metres of
			## deep court does not turn their back on it -- they open their hips
			## and backpedal, or they shuffle along the line. Facing followed
			## travel unconditionally, so the game had no such thing as moving
			## without turning, and every journey was a forward run.
			##
			## The bound is speed rather than distance because it is speed that
			## forces the issue: you can shuffle, and you cannot shuffle quickly.
			## Past a run a player has to open up and go, which is exactly what a
			## defender chasing a ball into the corner actually does.
			if absf(angle_difference(facing_yaw, travel_yaw)) <= OPEN_UP_CONE_RADIANS \
					or ground_speed_mps >= OPEN_UP_SPEED_MPS:
				_turn_toward(travel_yaw)
	has_world_position = true
	tactical_position = position
	self.position = world_position


## Turns the actor toward a heading at `FACING_TURN_RATE`, or adopts it outright
## if this is the first heading it has ever had.
## Turn toward a heading taken from travel rather than from a contact.
##
## Separate from `_turn_toward` only so the intent is legible at the call site:
## a contact turns a voli *to the ball*, and this turns them *the way they are
## running*. Both go through the same rate limit and the same first-heading
## adoption, because a body has one facing however it was decided.
func face_travel(target_yaw: float) -> void:
	_turn_toward(target_yaw)


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
## `weight` is how far into the platform this instant is, 0 to 1.
##
## Wrapping the blend around the whole pose rather than threading it through
## forty assignments: the joints are captured before the pose runs and eased
## back toward those captured values afterwards. What is being eased *from* is
## therefore whatever the frame already had -- the gait, mid-stride -- so a
## passer running to the ball keeps running and the platform arrives under them.
## The recovery's own progress, from a pose phase that also carries the approach.
func _recovery_clock(phase: float) -> float:
	return clampf(
		inverse_lerp(RECOVERY_START_PHASE, RECOVERY_END_PHASE, phase), 0.0, 1.0
	)


func _apply_dig_posture(
	weight: float = 1.0,
	drive: float = 0.0,
	recovery_progress: float = 0.0,
	contact_direction: Vector2 = Vector2.ZERO,
) -> void:
	var blend := clampf(weight, 0.0, 1.0)
	var push := clampf(drive, 0.0, 1.0)
	var before := _capture_joints()
	## **How far the hips drop below standing**, in metres.
	##
	## In metres for the same reason the stance is, and after the same discovery.
	## The knee angle this replaces could not reach the depth it was supposed to
	## mean: a squat folds the thigh forward and the shank back by equal amounts,
	## so the leg stays a chevron of length `span * cos(thigh_lift)` and a
	## 58-degree knee lowers a voli by **0.08 m**. The pose looked deeper than that
	## only because a separate hand-tuned `drop` pushed the whole body down and the
	## feet went through the floor with it -- 0.06 m under on a planted dig and
	## 0.19 m under on a reaching one. Depth that comes from sinking the figure
	## into the court is depth you cannot see, which is why a passer read as
	## someone leaning forward rather than someone getting low.
	##
	## Stated as a drop, the number is checkable against a photograph: a passer in
	## a serve-receive stance is a quarter of a metre below their standing height,
	## and one digging at the edge of their range is nearly half.
	var crouch_metres := 0.26
	var hip_pitch := -26.0
	## **How far apart the feet are**, as an outward roll on each leg.
	##
	## The stance had no width at all: measured, the two shoes sat 0.302 m apart in
	## every posture at every phase, which is exactly the hip width -- the legs
	## hung straight down from the pelvis and the only thing that moved was the
	## fold. A passer standing with their feet under their hips and their trunk
	## pitched forward is not low, they are *leaning*, and that is precisely how
	## the pose read.
	##
	## Rolling the legs out is also what makes the crouch cost nothing in balance:
	## a wide base is why a defender can put their shoulders in front of their toes
	## without falling over it, so the width and the depth belong together and are
	## set together per posture.
	##
	## **In metres between the shoes, not in degrees at the hip.** The roll needed
	## to hold a given width depends on how folded the knee is -- a straightening
	## leg reaches further sideways at the same angle -- so a fixed roll made the
	## feet slide apart by 22 cm as the legs drove through contact. Feet do not
	## move during a pass. The angle is solved from the width instead, which also
	## makes this a number a reader can check against a stance they have seen.
	var stance_metres := 0.76
	var platform_yaw := 0.0
	var platform_roll := 0.0
	## Whatever the platform could not be turned to, which the trunk leans into.
	var platform_residual := 0.0
	## How far the whole body twists toward the ball, and how far the *far* leg
	## steps across to let it. Zero for the two square postures.
	var torso_yaw := 0.0
	var far_leg_lead := 0.0
	## Whole-body lean, distinct from the hip pitch that folds the player up.
	##
	## Non-zero for a planted dig now. `hip_pitch * 0.24` alone left the trunk
	## almost upright, and an upright trunk is what put the platform up at chest
	## height -- the arms cannot reach down and forward from shoulders that have
	## not come down and forward themselves.
	##
	## Eased back from -11 once the knee and the stance took over the lowering.
	## Tilt and depth are two ways to get the shoulders down and they read
	## completely differently: depth reads as an athlete, tilt reads as a stoop.
	var body_tilt := -8.0
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
			crouch_metres = 0.34
			hip_pitch = -40.0
			## Widest of the four. A ball at the edge of the range is reached by
			## splitting the base, not by folding further over a narrow one, and
			## the split is what tells this apart from a deep planted dig at the
			## size a sticker is actually drawn.
			##
			## Not wider, though it should be: a folded leg cannot splay far, so
			## at this depth the hip clamp caps the base near 0.78 and asking for
			## more silently gets less. The pose a real reaching dig makes is a
			## *lunge* -- one leg folded under, one nearly straight and thrown out
			## to the side -- and this rig can only make both legs do the same
			## thing at once. Recorded in the backlog rather than faked here.
			stance_metres = 0.78
			platform_roll = 10.0
			## Enough lean to read as committed, not so much that the figure folds
			## into a ball. At -26 the torso came down over the knees and the legs
			## disappeared behind it, which loses the very thing the knee is for.
			body_tilt = -12.0
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
			crouch_metres = 0.24
			hip_pitch = -22.0
			## Wide, but not split: the reach here is sideways and it is bought with
			## the twist, not with the base.
			stance_metres = 0.72
			platform_yaw = 30.0
			platform_roll = 14.0
			torso_yaw = -22.0
			far_leg_lead = 22.0
		"moving":
			## Caught mid-step. The two legs are deliberately *unequal*: one is
			## still driving, the other is already planting, which is what makes
			## this read as arriving rather than as a shallower version of planted.
			crouch_metres = 0.21
			hip_pitch = -30.0
			## Narrowest, and for the opposite reason to the others: one foot is
			## still in the air. A player mid-step has not set their base yet, so a
			## wide one here would read as arriving and standing still at once.
			stance_metres = 0.58
			stride = 30.0
		_:
			pass
	## The drive: knees and hips extending under a platform that does not move.
	##
	## Applied after the posture is chosen rather than as four more posture
	## constants, because it is the same action whichever posture a defender got
	## there in -- a lunging dig extends out of a deeper start, not differently.
	## The trunk comes up with it, which is what carries the pass toward the target.
	##
	## The stance does *not* extend with it. Feet do not move during a pass; the
	## legs straighten between them, so the base stays as wide as it was set and
	## only the angles unwind.
	## **The ball decides the platform, when the ball is known.**
	##
	## The posture's own constant -- 0 square, 30 off-axis -- is kept as the
	## fallback and nothing more. It was the only source before, which meant every
	## square pass in the game had identical forearms whether the ball came from
	## the service line or off a blocker's hands two metres away, and an off-axis
	## one was 30 degrees to the same side regardless of which side the ball was
	## actually on.
	##
	## `PlatformAim` bisects the incoming and outgoing flights, which is where the
	## normal of a rebounding surface is. Both flights are already on the event.
	##
	## Resolved **here**, above the drive, because `body_tilt` and `torso_yaw` are
	## both consumed a dozen lines below and the first version of this wrote to
	## them after the fact -- a value computed and dropped, the failure this
	## repository logs more than any other, reproduced while fixing something else.
	if bool(contact_platform_aim.get("valid", false)):
		platform_yaw = float(contact_platform_aim.get("yaw_degrees", platform_yaw))
		platform_residual = float(
			contact_platform_aim.get("residual_degrees", 0.0)
		)
		## The trunk goes where the arms could not. A residual is by definition
		## the part of the reach the shoulders refused, so it is paid for by
		## turning the body -- which is what a passer actually does, and what
		## makes an off-axis contact read as a person rather than as a shrug.
		torso_yaw += clampf(platform_residual * 0.55, -34.0, 34.0)
		body_tilt += clampf(absf(platform_residual) * -0.16, -9.0, 0.0)

	crouch_metres = lerpf(crouch_metres, crouch_metres * 0.28, push)
	hip_pitch = lerpf(hip_pitch, hip_pitch * 0.35, push)
	body_tilt = lerpf(body_tilt, body_tilt * 0.30, push)
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
	## Legs posed, then *checked and corrected against the rig itself*.
	##
	## `_crouch_thigh_lift` is a closed form and it is close, but it is not exact:
	## the roll and the fold compose through three nested bases and the trunk pitch
	## swings the whole lower body with it, and every one of those costs the model
	## a centimetre or two. Left at the first guess, a planted dig asked for 0.26 m
	## and got 0.19.
	##
	## So the guess is posed, the hips are read where they actually landed, and the
	## residual is spent at the rate the geometry gives -- `span * sin(lift)` per
	## radian, the derivative of the chevron's own height.
	##
	## Four passes rather than one, because that rate is only right for a symmetric
	## squat. The `moving` posture splits the legs by a stride and takes the
	## trailing knee 40 percent straighter, so the step it needs is a fraction of
	## the step the formula predicts and a single correction landed it at 0.14 m
	## against the 0.21 it asked for. A slope in the right direction and the wrong
	## magnitude still converges; it just needs the iterations.
	##
	## Measured after, at the moment the platform is set: planted 0.252 against
	## 0.252 asked, reaching 0.330 against 0.330, off-axis 0.233 against 0.233,
	## and `moving` 0.176 against 0.204 -- the one posture whose legs are doing
	## two different things is the one still three centimetres shy, which is worth
	## knowing rather than rounding away.
	var span := (
		leg_bone_lengths.x + leg_bone_lengths.y
	) * leg_length_scale * body_height_scale
	var thigh_lift := _crouch_thigh_lift(crouch_metres, stance_metres)
	for _pass in 4:
		_pose_dig_legs(thigh_lift, stance_metres, far_leg_lead, stride)
		var per_degree := maxf(
			span * sin(deg_to_rad(thigh_lift)) * PI / 180.0, 0.0005
		)
		thigh_lift = clampf(
			thigh_lift + (crouch_metres - _dig_hip_drop(span)) / per_degree,
			0.0, 82.0
		)
	_pose_dig_legs(thigh_lift, stance_metres, far_leg_lead, stride)
	## The platform: two arms held *together* in front, not spread.
	##
	## The old dig swung them to -70 degrees with an 18-degree outward tilt each,
	## which under Godot's YXZ order reads as both arms straight out to the sides.
	## A platform is the opposite shape -- forearms joined, angled down and
	## forward -- so the pitch is shallower and the arms are brought inward
	## rather than splayed. `platform_yaw` then swings the whole platform off to
	## one side for a defender who could not square up, which is the thing worth
	## seeing.
	## Nearer horizontal, so the platform is a surface out in front rather than two
	## arms hanging down. Measured against the trunk's own fold: at 52 with a
	## planted hip pitch the forearms finish about eighty degrees off vertical in
	## world terms, which is a platform, and the extra reach is exactly what the
	## deeper knee is paying for.
	## Lifting a little through the drive -- the platform follows the ball toward
	## the target rather than being left behind by a body that stood up out of it.
	## Small: the arms are the one thing in a pass that is *not* supposed to travel.
	var lead := 52.0 - hip_pitch * 0.30 + 13.0 * push
	## And the platform's *tilt* comes off the same solve. A ball driven flat and
	## dug up needs a surface angled back; one dropping vertically and pushed
	## forward needs it angled down. That is the pitch of the same normal, and
	## reading only its yaw would leave the arms at one fixed rake for every ball
	## in the game -- the identical defect one axis over.
	if bool(contact_platform_aim.get("valid", false)):
		lead -= clampf(float(contact_platform_aim.get("pitch_degrees", 0.0)), -34.0, 38.0) * 0.5
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
	if blend < 0.999:
		_blend_joints_toward(before, 1.0 - blend)
	_ground_the_dig(blend)
	## Recovery starts after contact and is layered over a properly grounded dig.
	## That ordering matters: grounding a fallen pose by its shoe afterwards lifts
	## its hip back into the air, which is how the old static fall became a crouch.
	_apply_recovery_state(recovery_progress, contact_direction)


## How far below standing the hips currently are, in metres.
##
## Measured against the **lower** shoe, which is the one that will be on the floor
## once `_ground_the_dig` has run and therefore the one the hip height is really
## taken from. Reading a nominated leg's own shoe instead is wrong for exactly the
## posture that has a stride in it -- a foot swung forward is not under the hip,
## so `moving` asked for a 0.21 m crouch and landed on 0.11.
func _dig_hip_drop(span: float) -> float:
	return span - (
		to_local(left_leg.global_position).y - minf(
			to_local(
				(left_leg.get_node("Knee/Shoe") as Node3D).global_position
			).y,
			to_local(
				(right_leg.get_node("Knee/Shoe") as Node3D).global_position
			).y,
		)
	)


## Both legs into a squat of the given thigh angle over the given stance.
##
## **A knee folds backward.** This once had the thigh swinging back and the shank
## swinging *forward*, which puts the joint's point behind the leg -- a knee
## bending the wrong way. It survived because a crouch of roughly the right
## height is still a crouch of roughly the right height, and the tell is the one
## detail the knee was added to show.
##
## Correct squat: the thigh rotates forward as the hips drop and the shank folds
## back by twice that, so it finishes the same angle off vertical on the far side
## and the foot stays under the body at any depth.
##
## `far_lead` goes on the left leg only, because the off-axis twist is authored
## for a ball off to the player's right and the left side is the one that has to
## step across. `stride` splits the pair the other way, one forward and one back.
func _pose_dig_legs(
	thigh_lift: float, apart: float, far_lead: float, stride: float
) -> void:
	for index in [0, 1]:
		var leg: Node3D = left_leg if index == 0 else right_leg
		var lead_for_leg := (far_lead if index == 0 else 0.0) \
			+ (stride if index == 0 else -stride)
		## The trailing leg stays straighter -- it is still pushing.
		var knee_fold := -thigh_lift \
			* (0.6 if index == 1 and stride > 0.0 else 1.0) * 2.0
		(leg.get_node("Knee") as Node3D).rotation_degrees.x = knee_fold
		## Rolled out as well as folded, by however much this leg needs to put its
		## shoe on the stance line.
		##
		## Rotating a hanging leg about +Z carries its foot toward +x, so the
		## *left* leg -- which starts at negative x -- needs a negative roll to
		## travel outward and the right a positive one. Same sign trap the platform
		## fell into, and the same measurement settles it: with the roll at zero
		## the shoes sit 0.302 m apart, which is the hip width exactly.
		##
		## How far sideways a roll carries the shoe depends on the knee, because
		## only the part of the shank still pointing downward travels with it. The
		## fold is therefore resolved first and the roll solved against it -- the
		## reason the two are in this order and not the obvious one.
		leg.rotation_degrees = Vector3(
			thigh_lift + lead_for_leg, 0.0,
			_stance_roll(apart, knee_fold) * (-1.0 if index == 0 else 1.0)
		)


## The thigh angle that drops the hips by `drop` metres over a stance `apart`.
##
## A squat on this rig is a chevron: the thigh swings forward by this angle and
## the shank folds back by twice it, so the shank finishes the same angle off
## vertical on the other side and the foot stays under the hip. The pair
## therefore spans `leg * cos(lift)` vertically, and rolling the whole thing out
## to make the stance costs another `cos(roll)` on top.
##
## Two passes because the roll needed for a given width depends on how folded the
## knee is, and the fold depends on the roll. It converges immediately -- the
## second pass moves the answer by under a degree -- so a loop with an exit test
## would be more machinery than the problem has.
func _crouch_thigh_lift(drop: float, apart: float) -> float:
	var span := (
		leg_bone_lengths.x + leg_bone_lengths.y
	) * leg_length_scale
	if span < 0.01:
		return 0.0
	var lift := 0.0
	for _pass in 2:
		var roll := deg_to_rad(_stance_roll(apart, -lift * 2.0))
		var want := span - drop / maxf(body_height_scale, 0.01)
		lift = rad_to_deg(
			acos(clampf(want / maxf(span * cos(roll), 0.01), 0.0, 1.0))
		)
	return lift


## The hip roll that puts one shoe half a stance away from the centreline.
##
## `apart` is where the two shoes should be, in metres of court. The hip already
## contributes `hip_offset.x`, and the rest has to come from the leg swinging
## out: the thigh carries its full length sideways, the shank only the part of it
## still pointing downward once the knee has folded, which is why a folded leg
## needs a *larger* roll than a straight one to stand in the same place.
##
## Everything below the scale divide is in the rig's own units. `apart` is not,
## because a stance is a thing you could measure on a court with a tape, and the
## whole point of expressing it that way is that it stays checkable.
func _stance_roll(apart: float, knee_degrees: float) -> float:
	var fold := deg_to_rad(knee_degrees)
	## `leg_length_scale` is a scale on the leg node itself rather than a longer
	## pair of bones, so `leg_bone_lengths` is what was authored and not what is
	## on screen. Left out, a long-legged voli stood 5 percent wider than asked --
	## small, silent, and exactly the kind of thing a stance in metres exists to
	## make catchable.
	var reach := (
		leg_bone_lengths.x
		+ leg_bone_lengths.y * cos(fold)
		- SHOE_FORWARD_OFFSET * sin(fold)
	) * leg_length_scale
	if reach < 0.01:
		return 0.0
	var out := apart * 0.5 / maxf(body_height_scale, 0.01) - hip_offset.x
	## **A hip does not abduct to ninety degrees.** Past the limit the solve does
	## not fail, it saturates -- and a saturated `asin` returning 90 was quietly
	## catastrophic: `cos(roll)` went to zero, the depth solve divided by it and
	## the crouch collapsed to standing. The stance a deep squat can hold is
	## narrower than one taken standing up, and clamping says so instead of
	## breaking the pose that asked.
	return clampf(
		rad_to_deg(asin(clampf(out / reach, -1.0, 1.0))),
		-HIP_ABDUCTION_LIMIT_DEGREES, HIP_ABDUCTION_LIMIT_DEGREES
	)


## Put the dig's feet on the floor, and let that decide how low the hips are.
##
## This replaces four hand-tuned `drop` constants, and it replaces them because
## they were measurably wrong: the lower shoe finished **0.062 m below the floor**
## on a planted dig and **0.189 m below it** on a reaching one. A passer sunk a
## fifth of a metre into the court has the very thing the deep knee was added to
## show buried under the floorboards, which is a large part of why the pose read
## as a stoop rather than a squat.
##
## The right relationship is the other way round from the one the constants
## encoded. Hip height is not a number to pick alongside the knee angle -- it is
## the *consequence* of the knee angle, the hip fold and the stance width
## together, and any of the three moving changes it. So the shoe is read where it
## actually ended up and the pelvis is lifted until it sits at the height a
## straight leg would put it: `hip_offset.y` minus both bones, which is where the
## ankle lives when a voli is standing up.
##
## Read from the finished transforms rather than recomputed from the angles,
## because the trunk pitch rotates the legs with it on this rig and the blend
## back toward the gait moves them again. Trigonometry would have to model both;
## the transforms already have.
##
## Scaled by `blend` so a passer still mostly running is still owned by the gait,
## which does its own vertical travel through `bob_meters`.
func _ground_the_dig(blend: float) -> void:
	var rest := (
		hip_offset.y - leg_bone_lengths.x - leg_bone_lengths.y
	) * body_height_scale
	var lowest := minf(
		to_local(
			(left_leg.get_node("Knee/Shoe") as Node3D).global_position
		).y,
		to_local(
			(right_leg.get_node("Knee/Shoe") as Node3D).global_position
		).y,
	)
	body_pivot.position.y += (rest - lowest) * clampf(blend, 0.0, 1.0)
	_feet_already_grounded = true


## Every joint this pose writes, as it stands right now.
##
## Kept as a plain dictionary of the values rather than a Transform3D snapshot,
## because only the components the dig actually touches should come back -- the
## facing, the head look and the elevation are decided elsewhere and must
## survive the blend untouched.
func _capture_joints() -> Dictionary:
	return {
		"pivot_y": body_pivot.position.y,
		"pivot_rotation": body_pivot.rotation,
		"left_arm": left_arm.rotation_degrees,
		"right_arm": right_arm.rotation_degrees,
		"left_elbow": (left_arm.get_node("Elbow") as Node3D).rotation_degrees,
		"right_elbow": (right_arm.get_node("Elbow") as Node3D).rotation_degrees,
		"left_leg": left_leg.rotation_degrees,
		"right_leg": right_leg.rotation_degrees,
		"left_knee": (left_leg.get_node("Knee") as Node3D).rotation_degrees,
		"right_knee": (right_leg.get_node("Knee") as Node3D).rotation_degrees,
	}


## Ease back toward a captured set of joints by `amount`.
func _blend_joints_toward(captured: Dictionary, amount: float) -> void:
	var t := clampf(amount, 0.0, 1.0)
	body_pivot.position.y = lerpf(body_pivot.position.y, float(captured.pivot_y), t)
	body_pivot.rotation = body_pivot.rotation.lerp(Vector3(captured.pivot_rotation), t)
	left_arm.rotation_degrees = left_arm.rotation_degrees.lerp(
		Vector3(captured.left_arm), t
	)
	right_arm.rotation_degrees = right_arm.rotation_degrees.lerp(
		Vector3(captured.right_arm), t
	)
	var left_elbow := left_arm.get_node("Elbow") as Node3D
	var right_elbow := right_arm.get_node("Elbow") as Node3D
	left_elbow.rotation_degrees = left_elbow.rotation_degrees.lerp(
		Vector3(captured.left_elbow), t
	)
	right_elbow.rotation_degrees = right_elbow.rotation_degrees.lerp(
		Vector3(captured.right_elbow), t
	)
	left_leg.rotation_degrees = left_leg.rotation_degrees.lerp(
		Vector3(captured.left_leg), t
	)
	right_leg.rotation_degrees = right_leg.rotation_degrees.lerp(
		Vector3(captured.right_leg), t
	)
	var left_knee := left_leg.get_node("Knee") as Node3D
	var right_knee := right_leg.get_node("Knee") as Node3D
	left_knee.rotation_degrees = left_knee.rotation_degrees.lerp(
		Vector3(captured.left_knee), t
	)
	right_knee.rotation_degrees = right_knee.rotation_degrees.lerp(
		Vector3(captured.right_knee), t
	)


## Pure directional plan for a recovery. Keeping this separate from the rig
## makes "which way did they go?" a testable fact while the joint posing below
## remains free to change with the model.
static func recovery_motion(
	recovery_state: String,
	posture: String,
	progress: float,
	contact_direction: Vector2 = Vector2.ZERO,
	handedness: String = "Right",
) -> Dictionary:
	var recovery := clampf(progress, 0.0, 1.0)
	var down := smoothstep(0.0, 0.34, recovery)
	var travel := smoothstep(0.08, 0.82, recovery)
	var roll := smoothstep(0.18, 0.88, recovery)
	## **When the legs come in.** Late, and deliberately after the roll has
	## started.
	##
	## The legs used to fold on `down` -- 0 to 0.34 -- so the body balled up in
	## the first third and the 112-degree roll then turned a ball. Photographed as
	## a strip that reads as a forward tumble, which is what it was: the rotation
	## was there all along and had nothing extended to rotate.
	##
	## A dive roll extends into the contact, takes the floor on the platform and
	## the outside hip, and gathers the legs over the top as it comes round. So
	## the gather trails the roll instead of leading it.
	var gather := smoothstep(0.46, 0.96, recovery)
	## **The roll, as the sequence it actually is.**
	##
	## A rolling receive is not a fall with a rotation on it. In order: the arms
	## lead to the ball; the platform breaks; the body is guided onto its lateral
	## line -- hip, glute, back, shoulder -- keeping the elbows and knees *off*
	## the floor, with a hand down only if it is needed; the core stays stable
	## until after impact and only then lets the limbs tuck; the trailing leg and
	## the near shoulder turn the body together; and the legs and core bring it
	## back upright.
	##
	## The previous version was two curves -- a pitch and a 112-degree tip -- and
	## it ended lying on the floor. Nothing in it broke the platform, nothing
	## chose which surfaces took the load, and there was no way back to the feet,
	## which is why the last three frames of every strip were a body lying still.
	##
	## The bands overlap on purpose. A roll is continuous, and a stage that waits
	## for the previous one to finish is a sequence of poses rather than a
	## movement.
	var platform_hold := 1.0 - smoothstep(0.05, 0.21, recovery)
	var lateral_line := smoothstep(0.09, 0.44, recovery)
	var core_release := smoothstep(0.15, 0.36, recovery)
	var tuck := smoothstep(0.26, 0.63, recovery)
	var turn := smoothstep(0.14, 0.88, recovery)
	var rise := smoothstep(0.66, 1.0, recovery)
	var side := signf(contact_direction.x)
	if is_zero_approx(side):
		side = -1.0 if handedness == "Left" else 1.0
	var mode := recovery_state
	var pitch := 0.0
	var body_roll := 0.0
	var offset := Vector3.ZERO
	match recovery_state:
		"knee":
			pitch = deg_to_rad(-14.0) * down
		"fall":
			if posture in ["moving", "reaching"]:
				mode = "slide_forward"
				pitch = deg_to_rad(-56.0) * down
				body_roll = deg_to_rad(7.0) * side * roll
				offset.z = -0.48 * travel
			else:
				mode = "roll_sideways"
				## A full turn, because the roll ends on the feet. The old
				## 112 degrees was a body tipping over and staying there.
				body_roll = deg_to_rad(360.0) * side * turn
				## Forward at the contact, unwinding as the core brings the body
				## back up. Pitch that only ever increases is a player who folded.
				pitch = deg_to_rad(-26.0) * lateral_line * (1.0 - rise)
				## The lateral travel is bought during the contact and stops once
				## the turn is carrying the body instead of the floor.
				offset.x = 0.42 * side * lateral_line
		"blown_away":
			mode = "roll_backward"
			pitch = deg_to_rad(106.0) * roll
			body_roll = deg_to_rad(13.0) * side * down
			offset.z = 0.42 * travel
	return {
		"mode": mode,
		"down": down,
		"travel": travel,
		"roll": roll,
		"gather": gather,
		"platform_hold": platform_hold,
		"lateral_line": lateral_line,
		"core_release": core_release,
		"tuck": tuck,
		"turn": turn,
		"rise": rise,
		"side": side,
		"pitch_radians": pitch,
		"roll_radians": body_roll,
		"offset": offset,
	}


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
func _apply_recovery_state(
	progress: float = 1.0,
	contact_direction: Vector2 = Vector2.ZERO,
) -> void:
	var recovery := clampf(progress, 0.0, 1.0)
	if contact_recovery == "platform" or recovery <= 0.0001:
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
	var motion := recovery_motion(
		contact_recovery, contact_posture, recovery,
		contact_direction, dominant_hand,
	)
	var down := float(motion.down)
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
			body_pivot.rotation.x += float(motion.pitch_radians)
			left_leg.rotation_degrees.x = lerpf(
				left_leg.rotation_degrees.x, -12.0, down
			)
			(left_leg.get_node("Knee") as Node3D).rotation_degrees.x = lerpf(
				(left_leg.get_node("Knee") as Node3D).rotation_degrees.x, -100.0, down
			)
			right_leg.rotation_degrees.x = lerpf(
				right_leg.rotation_degrees.x, 75.0, down
			)
			(right_leg.get_node("Knee") as Node3D).rotation_degrees.x = lerpf(
				(right_leg.get_node("Knee") as Node3D).rotation_degrees.x, -43.0, down
			)
		"fall":
			## One severity, three honest directions. Off-axis contacts have already
			## said the miss was lateral, moving/reaching contacts have committed
			## forward, and a planted fall has only the lateral escape left. Nothing
			## here reclassifies the contact or changes its recovery cost.
			if str(motion.mode) == "slide_forward":
				## A forward pancake-like slide: chest and hips travel through the
				## platform while the legs trail rather than folding under it.
				body_pivot.rotation.x += float(motion.pitch_radians)
				body_pivot.position += Vector3(motion.offset)
				body_pivot.rotation.z += float(motion.roll_radians)
			else:
				## **The rolling receive, stage by stage.**
				var lateral := float(motion.lateral_line)
				var roll_rise := float(motion.rise)
				var hold := float(motion.platform_hold)
				var roll_side := float(motion.side)
				body_pivot.rotation.x += float(motion.pitch_radians)
				body_pivot.rotation.z += float(motion.roll_radians)
				body_pivot.position += Vector3(motion.offset)
				## **The core is stable until after impact.** Until it releases,
				## the trunk resists the tip instead of collapsing into it, which
				## is the difference between a controlled roll and being knocked
				## over. Counter-rotating a share of the roll is how a held core
				## reads from outside.
				body_pivot.rotation.z -= float(motion.roll_radians) \
					* (1.0 - float(motion.core_release)) * 0.55
				## **The hips take the floor first, and only as low as the lateral
				## line needs.** Dropping to the floor and staying there is what
				## made this a fall; the body comes back up on the legs below.
				body_pivot.position.y -= lerpf(0.0, 0.46, lateral) * (1.0 - roll_rise)

				## **The platform breaks after the ball has gone.** Holding two
				## arms locked together through a roll is the pose that reads as a
				## mannequin tipping over -- and it is also how an elbow ends up
				## taking the load.
				var break_weight := 1.0 - hold
				left_arm.rotation_degrees = left_arm.rotation_degrees.lerp(
					## Near arm sweeps across the chest as the body turns; the
					## hand is available to the floor without the elbow going
					## anywhere near it.
					Vector3(-24.0, 42.0 * roll_side, -46.0 * roll_side), break_weight
				)
				right_arm.rotation_degrees = right_arm.rotation_degrees.lerp(
					## Trailing arm opens away and *up*, which is what keeps the
					## shoulder rather than the elbow presenting to the floor.
					Vector3(-96.0, -30.0 * roll_side, 38.0 * roll_side), break_weight
				)
				## Elbows deliberately close to straight. A bent elbow under a
				## rolling body is the injury this technique exists to avoid, and
				## a drawing that shows it teaches the wrong thing.
				_set_elbow(left_arm, lerpf(
					(left_arm.get_node("Elbow") as Node3D).rotation_degrees.x,
					-14.0, break_weight
				))
				_set_elbow(right_arm, lerpf(
					(right_arm.get_node("Elbow") as Node3D).rotation_degrees.x,
					-8.0, break_weight
				))
				## **Step 5: the chin tucks.**
				##
				## The head keeps tracking the ball through every other pose, which
				## is right -- and wrong here. With the trunk pitched and rolled
				## past ninety degrees, a head still aimed at the ball is a head
				## driven back through the shoulders, which is the geometry behind
				## the frames where it disappears into the torso.
				##
				## Nobody rolls looking at the ball anyway. The tuck is the first
				## thing taught about going to the floor, so damping the look by
				## the roll is both the fix and the correct behaviour.
				var tuck := 1.0 - float(motion.roll)
				look_yaw *= tuck
				look_pitch = lerpf(look_pitch, 0.42, float(motion.roll))
				_apply_head_look()
			## Thighs well past horizontal, so the folded legs finish at hip height
			## and the *hip* becomes the lowest thing on the body. With the legs
			## reaching lower than the hip the floor solve plants a shoe instead
			## and leaves the body standing over it, which is a crouch.
			## **The legs.** Two different jobs, and the old single fold did
			## neither: it drove both knees to 118 and 126 degrees in the first
			## third, putting the knees on the floor during the load and leaving
			## the body folded for the rest.
			##
			## The trailing leg turns the body with the shoulder -- that pair is
			## what makes the rotation smooth rather than a topple -- and the near
			## leg gathers under the hips so there is something to stand up on.
			## Both stay well clear of a knee-first landing.
			if str(motion.mode) == "roll_sideways":
				var turn_drive := float(motion.turn)
				var gather_in := float(motion.tuck)
				var stand := float(motion.rise)
				## Trailing leg: extended through the load, swinging across to
				## carry the turn, then coming under for the rise.
				right_leg.rotation_degrees.x = lerpf(
					lerpf(-16.0, 62.0, turn_drive), 8.0, stand
				)
				right_leg.rotation_degrees.z = lerpf(
					0.0, -28.0 * float(motion.side), turn_drive
				)
				(right_leg.get_node("Knee") as Node3D).rotation_degrees.x = lerpf(
					lerpf(-6.0, -54.0, turn_drive), -18.0, stand
				)
				## Near leg: tucks in, then plants.
				left_leg.rotation_degrees.x = lerpf(
					lerpf(-8.0, 96.0, gather_in), 14.0, stand
				)
				(left_leg.get_node("Knee") as Node3D).rotation_degrees.x = lerpf(
					lerpf(-4.0, -104.0, gather_in), -26.0, stand
				)
			else:
				var fold := float(motion.gather)
				left_leg.rotation_degrees.x = lerpf(
					left_leg.rotation_degrees.x, 128.0, fold
				)
				(left_leg.get_node("Knee") as Node3D).rotation_degrees.x = lerpf(
					(left_leg.get_node("Knee") as Node3D).rotation_degrees.x, -118.0, fold
				)
				right_leg.rotation_degrees.x = lerpf(
					right_leg.rotation_degrees.x, 138.0, fold
				)
				(right_leg.get_node("Knee") as Node3D).rotation_degrees.x = lerpf(
					(right_leg.get_node("Knee") as Node3D).rotation_degrees.x, -126.0, fold
				)
		"blown_away":
			## Not a play, an impact. The body pitches *backward* -- the only pose
			## in the game that does, since a block bends forward at -0.12 -- the
			## arms are driven up and back off the ball rather than held on it, and
			## the legs come up in front. The backward pitch is the entire tell:
			## everything else a defender does goes toward the ball.
			body_pivot.rotation.x += float(motion.pitch_radians)
			body_pivot.rotation.z += float(motion.roll_radians)
			body_pivot.position += Vector3(motion.offset)
			left_arm.rotation_degrees = left_arm.rotation_degrees.lerp(
				Vector3(-138.0, 0.0, -34.0), down
			)
			right_arm.rotation_degrees = right_arm.rotation_degrees.lerp(
				Vector3(-146.0, 0.0, 30.0), down
			)
			_set_elbow(left_arm, lerpf(
				(left_arm.get_node("Elbow") as Node3D).rotation_degrees.x, 52.0, down
			))
			_set_elbow(right_arm, lerpf(
				(right_arm.get_node("Elbow") as Node3D).rotation_degrees.x, 44.0, down
			))
			## Past horizontal, so the feet finish *above* the hip and the body
			## plants on its back rather than on a shoe.
			left_leg.rotation_degrees.x = lerpf(
				left_leg.rotation_degrees.x, 110.0, down
			)
			right_leg.rotation_degrees.x = lerpf(
				right_leg.rotation_degrees.x, 95.0, down
			)
			(left_leg.get_node("Knee") as Node3D).rotation_degrees.x = lerpf(
				(left_leg.get_node("Knee") as Node3D).rotation_degrees.x, -60.0, down
			)
			(right_leg.get_node("Knee") as Node3D).rotation_degrees.x = lerpf(
				(right_leg.get_node("Knee") as Node3D).rotation_degrees.x, -50.0, down
			)
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


## Where the hips sit relative to the actor.
##
## **Read from the leg roots, which are the hip joint.** This used to read the
## shorts, on the reasoning that they were the one mesh that *was* the hip rather
## than merely near it -- true while they were a box sitting on the joint, and
## false the moment they became the bottom section of the torso. Moving a mesh
## silently moved a measurement taken off it, and the landing poses settled to the
## wrong height for it.
##
## The joint is the honest source: it is where the legs actually hang from, it is
## not a garment, and it cannot be restyled out from under this.
func _hip_offset_from_actor() -> Vector3:
	var inverse := global_transform.affine_inverse()
	return (
		(inverse * left_leg.global_transform).origin
		+ (inverse * right_leg.global_transform).origin
	) * 0.5


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


## Keep the shoes on the floor when a pose folds a knee.
##
## This rig has a hip and a knee and no ankle, so bending the knee swings the
## whole shin backward and lifts the shoe clear of the ground. Every pose that
## crouches was doing it in mid-air: a hitter absorbing a landing four
## centimetres above the floor, a blocker loading into a squat while hovering,
## a defender digging off the ground. It was fixed once inside the landing and
## then found again in the block, which is the signal that it belongs here --
## it is a property of the *rig*, not of any one action.
##
## Two things keep it honest:
##
## **Only the extra fold counts.** `baseline_knee` is what the gait had already
## produced, and the gait owns its own vertical travel through `bob_meters`.
## Compensating the total would count a runner's stance compression twice.
##
## **Only while a foot is down.** In flight the hips are ballistic and the foot
## is free, so a tucked knee lifts the shoe rather than lowering the body --
## which is exactly what a spike's tuck and a block's flight should look like.
## `elevation` is how much of that applies.
##
## The leg that matters is the *straighter* one, because that is the one holding
## the voli up. During a stride the deeply folded leg is the swing leg with
## nothing under it.
## Where a signature effect sits for this action, in metres above the feet.
func _signature_anchor_height(event_type: int) -> float:
	var reach := REFERENCE_RIG_HEIGHT_M * maxf(body_height_scale, 0.5)
	match event_type:
		RallyEventModel.EventType.ATTACK, RallyEventModel.EventType.BLOCK, \
		RallyEventModel.EventType.SERVE:
			## At the hand, and above the jump the body is already carrying.
			return reach * 1.06 + body_pivot.position.y
		RallyEventModel.EventType.SET:
			return reach * 0.92 + body_pivot.position.y
	## A floor contact happens off the platform, out in front and low.
	return reach * 0.36 + body_pivot.position.y


func _ground_the_feet(elevation: float, baseline_knee: float) -> void:
	## **Unless the pose already did it exactly.** The dig computes its own hip
	## height from where its feet finished, and this approximation -- which knows
	## about the shank and nothing about the thigh, the stance or the trunk --
	## would then lower it again by a number that was never right for a crouch.
	if _feet_already_grounded:
		_feet_already_grounded = false
		return
	var current := maxf(
		(left_leg.get_node("Knee") as Node3D).rotation_degrees.x,
		(right_leg.get_node("Knee") as Node3D).rotation_degrees.x,
	)
	if current >= baseline_knee - 0.01:
		return
	var shank := leg_bone_lengths.y
	var before := shank * cos(deg_to_rad(baseline_knee))
	var after := shank * cos(deg_to_rad(current))
	body_pivot.position.y += (after - before) \
		* (1.0 - clampf(elevation, 0.0, 1.0))


## When in a contact's phase the player stops running and starts squaring up.
##
## Not one number, because the actions differ in a way anyone who has played
## will recognise. A defender waiting on a serve is facing the ball almost the
## whole time -- they are shuffling, not travelling, and the platform has to be
## pointed at the ball well before it arrives. A hitter is the opposite: they
## run their approach facing where they are going and only turn to the ball in
## the last stride, because turning early is how you approach badly.
##
## A blocker never turns to the ball at all. They face the net, which is where
## `contact_direction` happens to point anyway, so their value is nominal.
const SQUARE_UP_PHASE := {
	RallyEventModel.EventType.RECEPTION: -0.85,
	RallyEventModel.EventType.DEFENSE: -0.85,
	RallyEventModel.EventType.SET: -0.70,
	RallyEventModel.EventType.SERVE: -0.90,
	RallyEventModel.EventType.BLOCK: -1.0,
	RallyEventModel.EventType.ATTACK: -0.35,
}
const DEFAULT_SQUARE_UP_PHASE: float = -0.60

## When a passer starts bringing their arms together, and when the platform is
## fully formed.
##
## Both on the signed contact phase, so they scale with the flight rather than
## being a fixed number of milliseconds -- a passer has as long as the ball
## takes, and a short serve leaves less of it. The platform is complete a little
## *before* contact, which is what a passer is trying to do: get set, then let
## the ball arrive at a surface that is already still.
const PLATFORM_PHASE: float = -0.34
const PLATFORM_SET_PHASE: float = -0.08
## And when the legs finish driving through it.
##
## **A pass is played with the legs.** The platform is set early and then held
## still -- coaches teach actively against swinging it, because an arm swing is
## what makes a pass unrepeatable -- and what supplies the lift and the direction
## is the knees and hips extending under a quiet platform. So the drive starts a
## little before the ball arrives, is already underway at contact, and carries on
## afterwards: the follow-through of a pass is the body rising and travelling
## toward the target, not the arms going anywhere.
##
## Before this the posture simply froze at `PLATFORM_SET_PHASE` and stayed frozen
## for the whole outgoing flight -- a passer crouched at full depth watching the
## ball they had already played.
const PLATFORM_DRIVE_START: float = -0.14
const PLATFORM_DRIVE_END: float = 0.34
## Where the recovery's own 0-to-1 lives inside the pose phase.
##
## It starts at contact rather than before it, and finishes before the pose does
## so a voli is back on their feet with a moment to spare rather than arriving
## upright exactly as the next contact begins.
const RECOVERY_START_PHASE: float = 0.0
const RECOVERY_END_PHASE: float = 0.86


func _square_up_phase(event_type: int) -> float:
	return float(SQUARE_UP_PHASE.get(event_type, DEFAULT_SQUARE_UP_PHASE))


## How high off the floor counts as airborne, in normalised elevation.
##
## Above the noise that a settling interpolation puts on a grounded player, and
## well below the elevation any real jump reaches.
const AIRBORNE_ELEVATION: float = 0.14
const GROUNDED_ELEVATION: float = 0.03


## Notice a touchdown and start the landing clock.
##
## Deliberately *observed* rather than announced. The actor is handed elevation
## and event type every frame already, so the alternative -- a caller that has to
## remember to report a landing, and a `set_pose` signature carrying the previous
## action -- would put the burden on three call sites to describe something this
## one can simply see happen.
func _track_landing(event_type: int, elevation: float) -> void:
	if elevation >= AIRBORNE_ELEVATION:
		_was_airborne = true
		_airborne_action = _landing_action_name(event_type)
	elif _was_airborne and elevation <= GROUNDED_ELEVATION:
		_was_airborne = false
		_landing_remaining = LandingBiomechanicsScript.duration_seconds(
			_airborne_action
		)
	elif _landing_remaining > 0.0:
		_landing_remaining = maxf(_landing_remaining - get_process_delta_time(), 0.0)


## Which landing an event leaves behind. A jump serve lands like a serve, a
## spike like a spike, and a block like a block; everything else that somehow
## got airborne gets the neutral absorb.
func _landing_action_name(event_type: int) -> String:
	match event_type:
		RallyEventModel.EventType.ATTACK:
			return "attack"
		RallyEventModel.EventType.BLOCK:
			return "block"
		RallyEventModel.EventType.SERVE:
			return "serve"
	return "default"


## Fold this voli into the landing they are partway through.
##
## Applied over the gait rather than instead of it, so a hitter who lands and
## immediately starts moving is absorbing *and* stepping, which is what actually
## happens. The knee takes the deeper of the two, because a leg cannot be both
## folding to absorb a landing and straight for a stride.
func _apply_landing() -> void:
	var duration := LandingBiomechanicsScript.duration_seconds(_airborne_action)
	var progress := 1.0 - _landing_remaining / maxf(duration, 0.0001)
	var landing := LandingBiomechanicsScript.resolve(progress, _airborne_action)
	body_pivot.rotation.x += float(landing.torso_pitch_radians)
	var lead_leg := left_leg if dominant_hand == "Left" else right_leg
	var trail_leg := right_leg if dominant_hand == "Left" else left_leg
	lead_leg.rotation_degrees.x += float(landing.lead_hip_degrees)
	trail_leg.rotation_degrees.x += float(landing.trail_hip_degrees)
	var fold := float(landing.knee_degrees)
	for leg in [left_leg, right_leg]:
		var knee := leg.get_node("Knee") as Node3D
		knee.rotation_degrees.x = minf(knee.rotation_degrees.x, fold)
	## A blocker's hands are still up on the touchdown frame and come down after
	## the feet; everyone else's swing down and forward for balance. `arm_hold`
	## carries which of those this is, so the two are one expression.
	##
	## Blended into the gait's swing by how much landing is left rather than
	## assigned over it. Assigned, the arms would snap from the landing's value
	## back to the stride's on the frame the timer expires -- a pop at exactly the
	## moment this overlay exists to remove one.
	var arm := float(landing.arm_degrees)
	var arm_weight := maxf(float(landing.absorb), float(landing.arm_hold))
	left_arm.rotation_degrees.x = lerpf(
		left_arm.rotation_degrees.x, arm, arm_weight
	)
	right_arm.rotation_degrees.x = lerpf(
		right_arm.rotation_degrees.x, arm, arm_weight
	)


## Bend one arm at the elbow. Positive folds the forearm forward, matching the
## knee's convention of positive folding the shank back -- both are "toward the
## way the joint actually goes".
func _set_elbow(arm: Node3D, bend_degrees: float) -> void:
	var elbow := arm.get_node_or_null("Elbow") as Node3D
	if elbow != null:
		elbow.rotation_degrees = Vector3(bend_degrees, 0.0, 0.0)


## Pose this voli for one instant of one contact.
##
## **`phase` is signed, and contact is at 0.** It runs -1 at the start of the
## wind-up, through 0 at the moment the ball is struck, to +1 at the end of the
## follow-through -- which means it spans *two* playback windows: the negative
## half plays during the incoming ball's flight and the positive half during the
## outgoing one.
##
## It used to be 0 to 1 within each window independently, and the cost of that
## was not subtle. Every contact pose was drawn one whole window late: the
## attacker was cocked behind their head at the frame the ball left their hand,
## the server the same, the setter still gathering. Worse, the attacker is posed
## in *both* windows -- once as the upcoming contact and once as the current one
## -- so the entire swing played through during the approach, snapped back to
## fully cocked at the instant of contact, and played again while the ball was
## already crossing the net. Elevation was continuous across that boundary and
## only the arms teleported, which is why it read as a broken limb rather than a
## timing error.
func set_pose(
	event_type: int,
	elevation: float,
	phase: float,
	contact_direction: Vector2,
	is_contact_actor: bool,
	action_context: Dictionary = {},
) -> void:
	_ensure_node_bindings()
	_track_landing(event_type, elevation)
	var lift := clampf(elevation, 0.0, 1.0) * 0.82
	## Every joint of the walk-to-run comes from `GaitBiomechanics`, which knows
	## the difference between the two. This branch used to be a single sine at a
	## fixed 32-degree amplitude with the knees explicitly zeroed on the next
	## line, so every voli on the court walked at exactly one speed with legs
	## that never bent, whether they were strolling to a seat or sprinting for a
	## dig.
	var gait := GaitBiomechanicsScript.resolve(
		stride_cycle, ground_speed_mps, travel_heading_offset
	)
	gait_blend = float(gait.gait_blend)
	locomotion_bob = float(gait.bob_meters)
	body_pivot.position = Vector3(0.0, lift + locomotion_bob, 0.0)
	body_pivot.rotation = Vector3(float(gait.torso_pitch_radians), 0.0, 0.0)
	body_pivot.scale = Vector3.ONE * body_height_scale
	left_arm.rotation_degrees = Vector3(float(gait.left_arm_degrees), 0.0, -12.0)
	right_arm.rotation_degrees = Vector3(float(gait.right_arm_degrees), 0.0, 12.0)
	left_arm.position = Vector3(-shoulder_offset.x, shoulder_offset.y, 0.0)
	right_arm.position = Vector3(shoulder_offset.x, shoulder_offset.y, 0.0)
	left_leg.rotation_degrees = Vector3(float(gait.left_hip_degrees), 0.0, 0.0)
	right_leg.rotation_degrees = Vector3(float(gait.right_hip_degrees), 0.0, 0.0)
	## The knees now carry the gait rather than being flattened. They are still
	## rewritten from scratch every frame, which is what stops a dig leaving the
	## defender bent for the rest of the rally.
	(left_leg.get_node("Knee") as Node3D).rotation_degrees = Vector3(
		float(gait.left_knee_degrees), 0.0, 0.0
	)
	(right_leg.get_node("Knee") as Node3D).rotation_degrees = Vector3(
		float(gait.right_knee_degrees), 0.0, 0.0
	)
	## The head keeps its own heading through a pose change. Everything else here
	## is reset each frame; the look is not, because it is a decision about what
	## the voli is watching rather than a property of the action they are in.
	_apply_head_look()
	## Elbows go back to the ready bend for the same reason -- and the ready bend
	## is not zero, because a nobody stands with their arms locked straight. The
	## gait carries them from nearly straight at a walk to a runner's right angle.
	var carried_elbow := maxf(READY_ELBOW_BEND, float(gait.elbow_degrees))
	_set_elbow(left_arm, carried_elbow)
	_set_elbow(right_arm, carried_elbow)
	## The landing sits on top of the gait and under the contact pose: a voli who
	## has just come down is absorbing it whatever else they are doing, and a voli
	## who is playing the ball right now is doing that instead.
	if not is_contact_actor and _landing_remaining > 0.0:
		_apply_landing()
	## What the gait alone would have folded the supporting knee to, kept so the
	## grounding below can tell a pose's crouch apart from a stride's.
	var gait_knee := maxf(
		float(gait.left_knee_degrees), float(gait.right_knee_degrees)
	)
	shadow.scale = Vector3.ONE * lerpf(1.0, 1.35, elevation)
	shadow.transparency = lerpf(0.0, 0.58, elevation)
	var signature_move := str(action_context.get("signature_move", ""))
	var signature_charge := float(action_context.get(
		"signature_charge", 1.0 if not signature_move.is_empty() else 0.0
	))
	## Portfolio/unit callers can pose an actor before it enters the tree, while
	## @onready bindings are still null. The body pose remains pure in that case;
	## the attached court actor gains the effect as soon as it is ready.
	if signature_surge != null:
		## The effect belongs where the action does. A swing and a block are
		## struck at the top of the reach; a dig is played off the platform in
		## front of the hips. `body_pivot.position.y` already carries the jump, so
		## the anchor rises with it rather than being a constant.
		signature_surge.contact_anchor_meters = _signature_anchor_height(event_type)
		signature_surge.set_cue(
			signature_move, signature_charge,
			bool(action_context.get("signature_succeeded", false)), phase,
		)
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
		## The contact actor faces the ball -- but only once they are close
		## enough to contact to be squaring up for it.
		##
		## This override used to run for the whole window, and that is what made
		## every player strafe. A hitter is posed as the upcoming contact from
		## phase -1, so they faced across the net for the entire approach and slid
		## sideways to their mark; a receiver ran to the ball crab-wise. Facing
		## is set from travel in `set_tactical_position` every frame, and this was
		## overwriting it on every one of them.
		##
		## Nothing here interpolates the turn: `_turn_toward` is already rate
		## limited, so simply declining to override until the squaring-up point
		## produces the turn for free, at a speed a body can actually manage.
		if event_type == RallyEventModel.EventType.BLOCK:
			## A blocker faces the net. Always, and not the ball.
			##
			## Every other contact takes its heading from where the ball is
			## going, and a block was doing the same -- from the *deflection*,
			## which points wherever the ball came off the hands. A stuffed ball
			## goes back into the hitter's court, so the blocker was handed a
			## heading pointing behind them and turned through 180 degrees in
			## mid-air while the announcer read out the block forming. Posing the
			## block a window earlier made it worse: two full flights to spin in
			## rather than one.
			##
			## The net runs along z = 0, so facing it is a matter of which side
			## the blocker stands on, and nothing about the ball enters into it.
			_turn_toward(0.0 if position.z > 0.0 else PI)
		elif phase >= _square_up_phase(event_type) or not is_contact_actor:
			_turn_toward(atan2(-contact_direction.x, -contact_direction.y))
	if not is_contact_actor:
		_ground_the_feet(elevation, gait_knee)
		return
	var striking_arm := left_arm if dominant_hand == "Left" else right_arm
	var guide_arm := right_arm if dominant_hand == "Left" else left_arm
	match event_type:
		RallyEventModel.EventType.SERVE:
			## Every joint comes from `ServeBiomechanics`, for the same reason the
			## spike and the block have their own modules: this branch was two
			## lines that saturated at -0.20 and then held, so a server cocked,
			## swung, and stood frozen with their arm overhead for the whole
			## outgoing flight -- no follow-through, no weight transfer, no toss
			## arm coming down, and no legs at all.
			var toss := ServeBiomechanicsScript.resolve(
				phase, -1.0 if dominant_hand == "Left" else 1.0,
				float(action_context.get("action_power", 0.0)),
			)
			body_pivot.rotation.x = float(toss.torso_pitch_radians)
			## The trunk winding against the facing, applied here rather than by
			## turning the actor -- `_turn_toward` is where the voli is looking.
			body_pivot.rotation.y += deg_to_rad(float(toss.torso_twist_degrees))
			var serve_lead := left_leg if dominant_hand == "Left" else right_leg
			var serve_trail := right_leg if dominant_hand == "Left" else left_leg
			serve_lead.rotation_degrees.x = float(toss.lead_hip_degrees)
			serve_trail.rotation_degrees.x = float(toss.trail_hip_degrees)
			for leg in [left_leg, right_leg]:
				(leg.get_node("Knee") as Node3D).rotation_degrees.x = float(
					toss.knee_degrees
				)
			## Two axes on the hitting arm, as on the spike: the roll is what
			## carries the elbow out away from the ribs on the way back and brings
			## the hand across the body on the way down.
			striking_arm.rotation_degrees = Vector3(
				float(toss.striking_shoulder_degrees), 0.0,
				float(toss.striking_abduction_degrees)
			)
			_set_elbow(striking_arm, float(toss.striking_elbow_degrees))
			guide_arm.rotation_degrees.x = float(toss.guide_shoulder_degrees)
			_set_elbow(guide_arm, float(toss.guide_elbow_degrees))
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
			##
			## **But not for the whole flight.** A passer runs to the ball with
			## their arms swinging and forms the platform in the last stride --
			## nobody travels with their forearms already locked together. This
			## branch ran from phase -1, so a receiver crossed several metres of
			## court holding a finished platform out in front of them, which is
			## the single most obviously wrong thing a defender can do.
			##
			## Blended rather than switched, and by phase rather than by a timer,
			## so the arms come together over the approach to contact and are
			## there when the ball is. Before the blend starts the gait owns the
			## arms, which is what running looks like.
			if phase >= PLATFORM_PHASE:
				_apply_dig_posture(
					smoothstep(PLATFORM_PHASE, PLATFORM_SET_PHASE, phase),
					smoothstep(PLATFORM_DRIVE_START, PLATFORM_DRIVE_END, phase),
					## Step 3: **the recovery has its own clock, and it starts at
					## contact.**
					##
					## This was `clampf(phase, 0, 1)` -- the same number the
					## approach runs on -- so a voli began going to the floor
					## while they were still travelling to the ball. Photographed
					## as a frame strip the shape is unmistakable: nothing visible
					## for the first 15% of the phase, then the entire collapse
					## between 15% and 40%, then five frames of a body already
					## down. A fall that has finished before the ball is played is
					## not a consequence of playing it.
					##
					## Renormalised so 0 is the contact and 1 is back on the feet.
					## The recovery curves inside `recovery_motion` -- down at
					## 0-0.34, travel at 0.08-0.82, roll at 0.18-0.88 -- were
					## written against a span that means this, and were being fed
					## one that did not.
					_recovery_clock(phase), contact_direction,
				)

		RallyEventModel.EventType.SET:
			## Every joint comes from `SetBiomechanics`. What was here got the
			## preparation right and stopped: the release saturated at contact, so
			## past phase 0 the setter held the finish for the whole outgoing flight
			## with their hands stopped where the ball had been. The legs were never
			## touched at all, which left a setter standing straight-legged while
			## their arms did the work -- and a set is a push from the floor.
			var push := SetBiomechanicsScript.resolve(
				phase, -1.0 if dominant_hand == "Left" else 1.0
			)
			body_pivot.rotation.x = float(push.torso_pitch_radians)
			## Only the rise. The dip comes free from the knee fold below, which
			## `_ground_the_feet` turns into a body drop -- subtracting a crouch
			## here as well would lower the setter twice and put their shoes
			## through the floor, which is what the dig was doing.
			body_pivot.position.y += float(push.rise_metres) * body_height_scale
			var split := float(push.hip_split_degrees)
			left_leg.rotation_degrees.x = -split
			right_leg.rotation_degrees.x = split
			for leg in [left_leg, right_leg]:
				(leg.get_node("Knee") as Node3D).rotation_degrees.x = float(
					push.knee_degrees
				)
			var set_pitch := float(push.shoulder_degrees)
			var set_flare := float(push.flare_degrees)
			left_arm.rotation_degrees = Vector3(set_pitch, 0.0, set_flare)
			right_arm.rotation_degrees = Vector3(set_pitch, 0.0, -set_flare)
			_set_elbow(left_arm, float(push.elbow_degrees))
			_set_elbow(right_arm, float(push.elbow_degrees))
		RallyEventModel.EventType.ATTACK:
			## Every joint comes from `SpikeBiomechanics`, which staggers them so
			## the legs extend before the trunk arches, the trunk before the
			## shoulder, and the elbow opens last. This branch used to interpolate
			## one `swing` value into all of them at once, which moved the whole
			## body as a single rigid unit -- and held the legs at a fixed stride
			## and the torso at a fixed lean for the entire action, so a spike had
			## no jump in it at all.
			##
			## Kept in its own module rather than inline because it is the only
			## pose in the game complex enough that it cannot be checked by
			## reading it, and a pure function of phase is one the suite can test.
			var swing := SpikeBiomechanics.resolve(
				phase, -1.0 if dominant_hand == "Left" else 1.0,
				float(action_context.get("action_power", 0.0)),
			)
			body_pivot.rotation.x = float(swing.torso_pitch_radians)
			## Hip-shoulder separation. Applied here rather than by turning the
			## actor, because `_turn_toward` is where the voli is *looking* and
			## this is the trunk winding against it.
			body_pivot.rotation.y += deg_to_rad(float(swing.torso_twist_degrees))
			var lead_leg := left_leg if dominant_hand == "Left" else right_leg
			var trail_leg := right_leg if dominant_hand == "Left" else left_leg
			lead_leg.rotation_degrees.x = float(swing.lead_hip_degrees)
			trail_leg.rotation_degrees.x = float(swing.trail_hip_degrees)
			for leg in [left_leg, right_leg]:
				(leg.get_node("Knee") as Node3D).rotation_degrees.x = float(
					swing.knee_degrees
				)
			## Two axes, not one. The roll is the abduction that carries the elbow out
			## as well as back and stands the forearm up *out* of it -- without it the
			## whole swing happens in one plane and reads as a hinge.
			striking_arm.rotation_degrees = Vector3(
				float(swing.striking_shoulder_degrees), 0.0,
				float(swing.striking_abduction_degrees)
			)
			_set_elbow(striking_arm, float(swing.striking_elbow_degrees))
			guide_arm.rotation_degrees.x = float(swing.guide_shoulder_degrees)
			_set_elbow(guide_arm, float(swing.guide_elbow_degrees))
		RallyEventModel.EventType.BLOCK:
			## Every joint comes from `BlockBiomechanics`, which sequences them
			## the way `SpikeBiomechanics` sequences a swing.
			##
			## This was the last static pose in the rig -- one set of angles with
			## no phase in it -- so the arms teleported to full extension on the
			## frame playback first posed this actor, held there for the whole
			## flight, and dropped out just as abruptly. What the peak of the
			## motion looks like is unchanged; the model is the route into and
			## out of it.
			##
			## A block *presses*: straight up is a player reaching, over the net
			## is a player taking space, and the difference is a forward lean
			## plus a shoulder shrug that arrives after the arms are already up.
			## The legs kick forward, not back -- a blocker leaves the floor from
			## a squat and the shins swing under and ahead of them on the way up.
			var wall := BlockBiomechanicsScript.resolve(phase)
			body_pivot.rotation.x = float(wall.torso_pitch_radians)
			left_leg.rotation_degrees.x = float(wall.lead_hip_degrees)
			right_leg.rotation_degrees.x = float(wall.trail_hip_degrees)
			for leg in [left_leg, right_leg]:
				## Backward, like every other knee in the file.
				(leg.get_node("Knee") as Node3D).rotation_degrees.x = float(
					wall.knee_degrees
				)
			var girdle := float(wall.shoulder_lift_meters)
			left_arm.position.y = shoulder_offset.y + girdle
			right_arm.position.y = shoulder_offset.y + girdle
			var reach := float(wall.shoulder_degrees)
			var spread := float(wall.hand_spread_degrees)
			left_arm.rotation_degrees = Vector3(reach, 0.0, -spread)
			right_arm.rotation_degrees = Vector3(reach, 0.0, spread)
			## Straight at the press, and deliberately so. A block that bends at
			## the elbow is a block that gets driven back through the net, and
			## keeping it near zero *there* is what makes a block read as a wall
			## next to a set's folded triangle -- the two poses put the arms in
			## nearly the same place, and the elbow is the only thing telling
			## them apart. It folds again either side of the press, which is the
			## ready posture a blocker waits in.
			_set_elbow(left_arm, float(wall.elbow_degrees))
			_set_elbow(right_arm, float(wall.elbow_degrees))
	## Last, after whichever branch ran, so every pose that crouches does it with
	## its feet on the ground rather than above it.
	_ground_the_feet(elevation, gait_knee)


## Whether this rig is being lit or being *printed*.
##
## The tactic sheet bakes volis into stickers and the light and shade came off the
## mesh, which sounded like an argument for real form and read as mud: a hundred
## pixels of posterised directional lighting is a smudge, not a body. Unshaded, the
## render *is* the material colours -- flat regions the eye can name -- and the
## silhouette does the shaping instead, which is what the die-cut border was
## always for.
##
## A flag rather than a second rig, because it is the same voli with the same kit
## and the same body type; only the lighting is a lie.
@export var flat_shading: bool = false


func _apply_material_color(
	mesh: MeshInstance3D, color: Color, alpha: float = 1.0
) -> void:
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(color, alpha)
	material.roughness = 0.72
	if flat_shading:
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
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
	## **The shorts are the bottom of the torso, not a box on it.**
	##
	## They were a box wider than the body sitting at the waist, and under a drawn
	## line that box earned an outline of its own -- which is what turned a pair of
	## shorts into a shelf. A voli in a singlet does not have a ledge at the hip.
	##
	## So they are now a section of the torso's own profile: the same shape,
	## sampled at the height they sit at, a shade wider so they clear it without
	## fighting for pixels, and less than half its height so they read as the
	## bottom of a garment rather than as a second body. `_torso_radius_at` is the
	## same function the collar uses, for the same reason -- a band sized from the
	## widest point of a round body is a hoop somebody has been posted through.
	var torso_spec: Dictionary = silhouette.get("torso", {})
	var torso_height := float(torso_spec.get("height", 0.9)) * squeeze
	var shorts_height := torso_height * SHORTS_TORSO_SHARE
	var shorts_spec := {
		"shape": "cylinder",
		"top_radius": BodyTypeModelsScript._torso_radius_at(
			torso_spec, 0.5 - SHORTS_TORSO_SHARE
		) * 1.03,
		"bottom_radius": BodyTypeModelsScript._torso_radius_at(
			torso_spec, 0.5 - SHORTS_TORSO_SHARE * 1.9
		) * 1.03,
		"height": shorts_height,
	}
	shorts.mesh = BodyTypeModelsScript.build_mesh(shorts_spec)
	## Hung from the bottom of the torso rather than from the hip joint, because
	## it is now part of the torso and has to end where the torso does.
	shorts.position.y = torso.position.y - torso_height * 0.5 + shorts_height * 0.5

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
	## **Not a cylinder.** This line is why every voli was a produce with four rods
	## in it: whatever a body type authored, the rig overwrote it with a shape that
	## ends in a flat disc. A limb tapers and finishes in a dome -- see
	## `BodyTypeModels._limb_mesh`, which lathes one because Godot has no tapered
	## capsule to reach for.
	arm_spec["shape"] = "limb"
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
		## The shoulder and the elbow, as joints rather than as the gap between
		## two pills. Rounding the limb ends stopped them reading as rods and left
		## the other half of the problem standing: a bent elbow opens a wedge on
		## the outside of the bend, and a shoulder that only touches the torso
		## reads as an arm resting against a body rather than growing out of one.
		_joint_ball(arm, float(arm_spec.get("top_radius", 0.09)) * 1.08, 0.0)
		_joint_ball(elbow, float(arm_spec.get("bottom_radius", 0.08)) * 1.06, 0.0)

	## Legs are placed so the foot lands just above the floor whatever the hip
	## height and shank length are, rather than by the pair of literals that
	## happened to suit the one rig.
	var leg_spec: Dictionary = silhouette.get("leg", {})
	leg_spec["shape"] = "limb"
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
		_joint_ball(leg, float(leg_spec.get("top_radius", 0.11)) * 1.06, 0.0)
		_joint_ball(knee, float(leg_spec.get("bottom_radius", 0.09)) * 1.08, 0.0)
		var shoe := knee.get_node("Shoe") as MeshInstance3D
		shoe.mesh = BodyTypeModelsScript.build_mesh(shoe_spec)
		shoe.position = Vector3(0.0, -shank_length, -SHOE_FORWARD_OFFSET)
		## A box foot is authored lying flat already; only the capsule shoe
		## needs standing on its side to become a foot rather than a leg.
		shoe.rotation_degrees = Vector3(
			90.0 if str(shoe_spec.get("shape", "capsule")) == "capsule" else 0.0,
			0.0, 0.0
		)
	_build_cosmetics()
	_build_face()
	## Last, so every mesh the body build produced -- including the cosmetics and
	## the face -- gets its line.
	_apply_ink()


## The joint ball on a bone, if it has one yet.
func _paint_joint(bone: Node, color: Color) -> void:
	var ball := bone.get_node_or_null("Joint") as MeshInstance3D
	if ball != null:
		_apply_material_color(ball, color)


## How thick the drawn line is, in metres of world space.
##
## **In metres, which is the whole point.** An outline measured in pixels thins as
## a voli walks upcourt and thickens as they come toward the camera, so the
## drawing changes weight for reasons that have nothing to do with the drawing.
## In metres a line is a property of the body, and a voli at the endline carries
## the same pen as one at the net.
##
## The crown is heavier than the body because it is smaller. A crest, a pair of
## ears or a beak is the thing that says which type this is, occupies a few dozen
## pixels doing it, and is the one place where more line buys legibility instead
## of weight.
## `static var` so the two candidates -- drop the die cut, or thicken the line so
## it survives the quantiser -- can be rendered against each other rather than
## argued about.
static var ink_metres: float = 0.018
static var crown_ink_metres: float = 0.030
const INK_COLOR := Color(0.06, 0.07, 0.10)
## Everything else is a cosmetic and takes the heavier line. Named as the body
## rather than as a list of cosmetics because the body is a closed set and the
## cosmetics are not -- a new ear or tail should get the crown weight without
## anybody remembering to add it here.
const INK_BODY_PARTS: Array[String] = [
	"Torso", "Shorts", "Head", "Mesh", "Joint", "Shoe", "Kit",
]


## Draw every part of the rig with a line round it.
##
## An inverted hull: each mesh gets a twin, grown outward, painted flat and
## rendered inside-out so only its far side shows. What survives is a band around
## the silhouette of *that part*, which is why an arm crossing the torso keeps its
## own edge instead of dissolving into it -- the same separation the sticker trace
## does in 2D, obtained here for the cost of a second draw call per part.
##
## Rebuilt with the body rather than authored in the scene, because the twins have
## to follow whatever mesh each body type produced.
func _apply_ink() -> void:
	_ink_node(self)


func _ink_node(node: Node) -> void:
	for child in node.get_children():
		_ink_node(child)
	var mesh_instance := node as MeshInstance3D
	if mesh_instance == null or mesh_instance.mesh == null:
		return
	if mesh_instance.name == "Ink":
		return
	## The shadow and the focus ring are marks on the floor, not parts of a body.
	if mesh_instance == shadow or mesh_instance == focus_ring:
		return
	var existing := mesh_instance.get_node_or_null("Ink") as MeshInstance3D
	var twin := existing if existing != null else MeshInstance3D.new()
	if existing == null:
		twin.name = "Ink"
		mesh_instance.add_child(twin)
	twin.mesh = mesh_instance.mesh
	var material := StandardMaterial3D.new()
	material.albedo_color = INK_COLOR
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.cull_mode = BaseMaterial3D.CULL_FRONT
	material.grow = true
	material.grow_amount = ink_metres \
		if str(mesh_instance.name) in INK_BODY_PARTS else crown_ink_metres
	twin.material_override = material


## A ball at a joint, so two segments read as one limb bending.
##
## Named and reused rather than four near-identical blocks, and rebuilt on every
## body build rather than authored in the scene, because the radius comes from
## the body type -- a Vegi's arm and an Ursi's are not the same thickness and a
## joint sized for one is a bead or a boil on the other.
func _joint_ball(bone: Node3D, radius: float, drop: float) -> void:
	var existing := bone.get_node_or_null("Joint") as MeshInstance3D
	var ball := existing if existing != null else MeshInstance3D.new()
	if existing == null:
		ball.name = "Joint"
		bone.add_child(ball)
	var sphere := SphereMesh.new()
	sphere.radius = radius
	sphere.height = radius * 2.0
	sphere.radial_segments = 10
	sphere.rings = 5
	ball.mesh = sphere
	ball.position = Vector3(0.0, drop, 0.0)


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
		## Non-uniform scale, which the primitives cannot express on their own: a
		## `SphereMesh` has one radius for both horizontal axes, so anything that
		## has to be wider one way than the other -- a pepper's lobe bulging
		## outward, a stripe lying along a flank -- can only be got by scaling the
		## instance. Applied after the rotation, so a part turned to face outward
		## scales along its own axes rather than the world's.
		instance.scale = part.get("scale", Vector3.ONE)
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


## The cognition badge above this voli's head, created on first use.
##
## A child node and one call, deliberately: `player_actor_3d.gd` is the file the
## new 3D models and VFX are about to rewrite, and the cognition layer is meant
## to survive that. Everything it needs lives in `CognitionBillboard3D`; the
## actor only owns *where* the badge hangs, which is the one fact the component
## cannot know for itself.
var cognition_billboard: CognitionBillboard3D


func show_cognition_cue(cue: Resource) -> void:
	if cognition_billboard == null:
		if cue == null:
			return
		cognition_billboard = CognitionBillboard3D.new()
		add_child(cognition_billboard)
	cognition_billboard.show_cue(cue, _cognition_head_height())


func hide_cognition_cue() -> void:
	if cognition_billboard != null:
		cognition_billboard.hide_cue()


## Head height for this body, from the rig reference and the per-voli scale, so
## a tall middle's badge sits above their head and not through it.
func _cognition_head_height() -> float:
	return REFERENCE_RIG_HEIGHT_M * maxf(body_height_scale, 0.5)
