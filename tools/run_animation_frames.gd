extends Node

## Every animation as a strip of frames, so a motion can be judged as a motion.
##
##     xvfb-run -a godot --path . res://tools/animation_frames.tscn \
##       -- --strip=attack_power --camera=three_quarter
##
## `run_voli_portfolio.gd` photographs *poses* -- one instant per subject -- and
## that is the right instrument for asking whether a body reads. It is the wrong
## one for asking whether a **movement** reads, because the failure mode of an
## animation is almost never a bad frame. It is a good frame in the wrong place:
## a roll that starts before the body has fallen, a recovery that returns to
## standing halfway through, a phase whose middle is a straight line between two
## poses nobody would pass through.
##
## So this walks one body through a single motion and photographs it at even
## intervals along the phase, laid out left to right. The subject, camera and
## lighting are held identical across the row -- the only thing that changes
## between frames is the number the animation is driven by, which is what makes
## the row readable as a sequence rather than as five separate photographs.
##
## Two cameras per motion, because a fall is a movement in depth as much as in
## height and a strip shot only from the side cannot show a body rolling toward
## or away from the viewer. The side view answers "does the arc look right"; the
## three-quarter answers "does it look like a person".

const ACTOR := preload("res://scenes/components/player_actor_3d.tscn")
const RallyEventModel := preload("res://scripts/models/rally_event.gd")
const BlockBiomechanics := preload("res://scripts/data/block_biomechanics.gd")
const IdleBiomechanics := preload("res://scripts/data/idle_biomechanics.gd")

const OUT := "res://artifacts/rally-action-animations"

## Frames per strip. Eight is enough to see an ease curve and few enough that
## each frame is still large enough to read at a glance.
const FRAME_COUNT: int = 8
const FRAME_SPACING: float = 1.55
## Where a recovery strip starts, in pose phase. Before the platform forms, so
## the row reads approach -> contact -> recovery rather than beginning mid-fall.
const RECOVERY_STRIP_FROM_PHASE: float = -0.34

## Side exposes lateral travel; front exposes left/right support and limb depth;
## three-quarter remains the general silhouette review.
const CAMERAS := {
	"side": [Vector3(0.0, 1.15, 9.4), Vector3(-4.0, 0.0, 0.0), 46.0],
	"front": [Vector3(0.0, 1.15, -9.4), Vector3(-4.0, 180.0, 0.0), 46.0],
	"three_quarter": [
		Vector3(5.6, 3.05, 8.2), Vector3(-15.0, 34.0, 0.0), 44.0,
	],
}

## Each strip states the whole of what it is showing.
##
##   recovery -- the floor motion driven across `recovery` 0 to 1
##   pose     -- [event type, elevation, phase] driven across `phase` instead
##   signature-- a named rule-of-cool move at full charge
##
## Semantic vocabulary index (descriptive render metadata, never selection logic):
##
## - `recovery_fall_roll`: planted/off-axis emergency pass, sideways floor roll.
## - `recovery_fall_slide`: moving/reaching emergency pass, forward floor slide.
## - `recovery_blown_away`: hard contact impact, backward fall and recovery.
## - `recovery_knee`: low controlled contact, supported kneeling recovery.
## - `gait_ready_to_run`: settled readiness continuously opening into relocation.
## - `gait_backpedal`: retreating adjustment while facing the play.
## - `gait_shuffle`: lateral positional adjustment with uncrossed feet.
## - `platform_aim`: clean settled reception contact across incoming directions.
## - `approach_three_step`: normal attack preparation from run through plant.
## - `serve_standing`: clean grounded overhead routine through step-in recovery.
## - `serve_jump_topspin`: aggressive airborne serve, full wrap and landing.
## - `serve_jump_float`: compact airborne float, arrested hand and landing.
## - `serve_hybrid`: airborne preparation with a controlled late hand action.
## - `serve_sky_ball`: grounded underhand lift and recovery.
## - `receive_dive`: emergency airborne/reaching reception into floor recovery.
## - `receive_moving`: bump while arriving and retaining the active step.
## - `receive_strained`: extended/off-balance bump outside a settled platform.
## - `set_front`: clean settled overhead set, gather through recovery.
## - `set_back`: controlled back release with a late directional reveal.
## - `set_moving`: overhead set while the final positional step is still active.
## - `attack_power`: clean committed swing, contact, continuation, and landing.
## - `attack_roll`: controlled soft attack after a power-shaped approach.
## - `attack_dink`: compact intentional tip/feint with the hand forward.
## - `attack_reaching`: extended strike after failed ideal body spacing.
## - `attack_mistimed`: compromised/cramped strike with disrupted sequencing.
## - `attack_missed`: committed swing after losing the ideal contact point.
## - `block_impact`: wall absorbs a hard ball through hands and torso.
## - `block_tool`: hand touch deflects/tooling the ball off the wall.
## - `block_beaten`: late or incomplete wall responding after the ball passes.
## - `idle_breath_sway`: settled non-contact breathing and weight drift.
## - `standing_to_ready`: continuous transition into assigned readiness.
## - `blink`: ordinary perceptive eye microexpression outside concentration.
## - `signature_*`: stylized charged continuations of their named attack/block
##   families; emphasis overlays, not alternate rally outcomes.
const STRIPS: Array[Dictionary] = [
	{
		## `posture` has to be one of the four the pose actually knows -- the
		## first version of this strip passed "diving", which matches no branch,
		## so the body never entered a dig at all and eight frames of a standing
		## figure collapsing were read as the animation being wrong.
		##
		## And `fall` is two motions, not one: a planted or off-axis voli rolls
		## sideways, a moving or reaching one slides forward. Only the first is
		## the dive roll, so it needs a planted contact to appear.
		"name": "recovery_fall_roll",
		"caption": "DEFENSE fall from planted -- the sideways roll",
		"recovery": "fall",
		"posture": "planted",
	},
	{
		"name": "recovery_fall_slide",
		"caption": "DEFENSE fall from reaching -- the forward slide",
		"recovery": "fall",
		"posture": "reaching",
	},
	{
		"name": "recovery_blown_away",
		"caption": "DEFENSE recovery: blown_away (backward)",
		"recovery": "blown_away",
		"posture": "reaching",
	},
	{
		"name": "recovery_knee",
		"caption": "DEFENSE recovery: knee",
		"recovery": "knee",
		"posture": "planted",
	},
	{
		## The stance and the three floor gaits, as one row each. Driven by
		## `ground_speed_mps` and `travel_heading_offset` rather than by a phase,
		## because that is what the gait is a function of -- a strip that swept
		## time would show one gait eight times.
		"name": "gait_ready_to_run",
		"caption": "IDLE -> RUN: the ready stance opening into a stride",
		"gait_sweep": [0.0, 4.6],
		"gait_heading": 0.0,
	},
	{
		"name": "gait_backpedal",
		"caption": "BACKPEDAL: short steps, chest up, eyes still front",
		"gait_sweep": [0.0, 3.4],
		"gait_heading": PI,
	},
	{
		"name": "gait_shuffle",
		"caption": "SHUFFLE: feet never cross, hips low and flat",
		"gait_sweep": [0.0, 3.4],
		"gait_heading": PI * 0.5,
	},
	{
		## Not a phase sweep: eight *different balls*, each at the same instant of
		## the same pass. The whole claim of `PlatformAim` is that the forearms
		## follow the ball, and a strip that varied time instead of geometry could
		## not show that either way.
		"name": "platform_aim",
		"caption": "RECEPTION: one instant, eight incoming lines",
		## At contact, not after it. `PLATFORM_DRIVE_END` is 0.34, so a phase of
		## 0.5 draws the follow-through -- the legs have already extended and the
		## voli is standing up out of the pass, which is the one instant the
		## platform is *not* the thing to look at.
		"pose": [RallyEventModel.EventType.RECEPTION, 0.0, -0.02],
		"posture": "planted",
		"platform_sweep": true,
	},
	{
		## The run-up, which until now was drawn as a jog. Swept across the pose
		## phase *before* `SpikeBiomechanics.PLANT_END`, because that is the window
		## the approach owns and the window nothing was drawing.
		"name": "approach_three_step",
		"caption": "ATTACK approach: directional, penultimate, close",
		"pose": [RallyEventModel.EventType.ATTACK, 0.0, 0.0],
		"approach_sweep": true,
	},
	{
		"name": "serve_standing", "caption": "SERVE standing: compact toss, transfer, step-in",
		"pose": [RallyEventModel.EventType.SERVE, 0.0, 0.0], "action_sweep": true,
		"context": {"serve_style": "Standing", "action_power": 0.72},
	},
	{
		"name": "serve_jump_topspin", "caption": "SERVE jump topspin: approach, bow, high contact, wrap",
		"pose": [RallyEventModel.EventType.SERVE, 0.0, 0.0], "action_sweep": true,
		"context": {"serve_style": "Jump Topspin", "action_power": 0.84},
	},
	{
		"name": "serve_jump_float", "caption": "SERVE jump float: compact rise and arrested punch",
		"pose": [RallyEventModel.EventType.SERVE, 0.0, 0.0], "action_sweep": true,
		"context": {"serve_style": "Jump Float", "action_power": 0.68},
	},
	{
		"name": "serve_hybrid", "caption": "SERVE hybrid: float preparation, late rotational carry",
		"pose": [RallyEventModel.EventType.SERVE, 0.0, 0.0], "action_sweep": true,
		"context": {"serve_style": "Hybrid", "action_power": 0.76},
	},
	{
		"name": "serve_sky_ball", "caption": "SERVE sky ball: grounded underhand high finish",
		"pose": [RallyEventModel.EventType.SERVE, 0.0, 0.0], "action_sweep": true,
		"context": {"serve_style": "Sky Ball", "action_power": 0.62},
	},
	{
		"name": "receive_dive", "caption": "RECEPTION dive: push, flight, platform, floor",
		"pose": [RallyEventModel.EventType.RECEPTION, 0.0, 0.0], "action_sweep": true,
		"posture": "reaching", "recovery": "fall",
	},
	{
		"name": "receive_moving", "caption": "RECEPTION moving: final stride, platform, carried recovery",
		"pose": [RallyEventModel.EventType.RECEPTION, 0.0, 0.0], "action_sweep": true,
		"posture": "moving", "ground_speed_mps": 3.1, "stride_cycle": 0.24,
	},
	{
		"name": "receive_strained", "caption": "RECEPTION strained: off-axis platform and unequal support",
		"pose": [RallyEventModel.EventType.RECEPTION, 0.0, 0.0], "action_sweep": true,
		"posture": "off-axis", "ground_speed_mps": 2.4, "stride_cycle": 0.74,
	},
	{
		"name": "set_front", "caption": "SET front: floor load and high outward finish",
		"pose": [RallyEventModel.EventType.SET, 0.0, 0.0], "action_sweep": true,
		"context": {"set_posture": "standing", "back_set": false},
	},
	{
		"name": "set_back", "caption": "SET back: disguised gather, arch, carry over crown",
		"pose": [RallyEventModel.EventType.SET, 0.0, 0.0], "action_sweep": true,
		"context": {"set_posture": "standing", "back_set": true},
	},
	{
		"name": "set_moving", "caption": "SET moving: hands gather over the active adjustment step",
		"pose": [RallyEventModel.EventType.SET, 0.0, 0.0], "action_sweep": true,
		"context": {"set_posture": "standing", "back_set": false},
		"ground_speed_mps": 3.0, "stride_cycle": 0.24,
	},
	{
		"name": "attack_power", "caption": "ATTACK power: bow, whip, cross-body finish",
		"pose": [RallyEventModel.EventType.ATTACK, 1.0, 0.0], "action_sweep": true,
		"context": {"attack_type": "Power swing", "action_power": 0.82},
	},
	{
		"name": "attack_roll", "caption": "ATTACK roll: sold approach and late deceleration",
		"pose": [RallyEventModel.EventType.ATTACK, 1.0, 0.0], "action_sweep": true,
		"context": {"attack_type": "Roll shot", "action_power": 0.62},
	},
	{
		"name": "attack_dink", "caption": "ATTACK dink: sold approach and compact touch",
		"pose": [RallyEventModel.EventType.ATTACK, 1.0, 0.0], "action_sweep": true,
		"context": {"attack_type": "Dink", "action_power": 0.38},
	},
	{
		"name": "attack_reaching", "caption": "ATTACK reaching: extended hand with airborne counterbalance",
		"pose": [RallyEventModel.EventType.ATTACK, 1.0, 0.0], "action_sweep": true,
		"context": {"attack_type": "Power swing", "action_power": 0.72, "attack_adjustment": "reaching"},
	},
	{
		"name": "attack_mistimed", "caption": "ATTACK mistimed: cramped contact and asymmetric recovery",
		"pose": [RallyEventModel.EventType.ATTACK, 1.0, 0.0], "action_sweep": true,
		"context": {"attack_type": "Power swing", "action_power": 0.72, "attack_adjustment": "mistimed"},
	},
	{
		"name": "attack_missed", "caption": "ATTACK missed: attempted arc and arrested unspent rotation",
		"pose": [RallyEventModel.EventType.ATTACK, 1.0, 0.0], "action_sweep": true,
		"context": {"attack_type": "Power swing", "action_power": 0.72, "attack_adjustment": "missed"},
	},
	{
		"name": "block_impact", "caption": "BLOCK impact: wall yields and absorbs the return",
		"pose": [RallyEventModel.EventType.BLOCK, 1.0, 0.0], "action_sweep": true,
		"context": {"block_response": "impact"},
	},
	{
		"name": "block_tool", "caption": "BLOCK tool: contacted hand yields after phase zero",
		"pose": [RallyEventModel.EventType.BLOCK, 1.0, 0.0], "action_sweep": true,
		"context": {"block_response": "tool"},
	},
	{
		"name": "block_beaten", "caption": "BLOCK beaten: incomplete wall withdraws into landing",
		"pose": [RallyEventModel.EventType.BLOCK, 1.0, 0.0], "action_sweep": true,
		"context": {"block_response": "beaten"},
	},
	{
		"name": "idle_breath_sway", "caption": "IDLE: breath, weight shift, arm lag",
		"idle_sweep": true,
	},
	{
		"name": "standing_to_ready", "caption": "STANCE: standing to ready and settle",
		"ready_settle": true,
	},
	{
		"name": "blink", "caption": "MICROEXPRESSION: close, hold, slower open",
		"blink_sweep": true, "closeup": true, "frame_spacing": 0.56,
	},
	{
		"name": "signature_crush",
		"caption": "ATTACK signature: crush, full charge",
		"pose": [RallyEventModel.EventType.ATTACK, 1.0, 0.0],
		"signature_move": "crush",
	},
	{
		"name": "signature_high_hands",
		"caption": "ATTACK signature: high hands, full charge",
		"pose": [RallyEventModel.EventType.ATTACK, 1.0, 0.0],
		"signature_move": "high_hands",
	},
	{
		"name": "signature_monster_block",
		"caption": "BLOCK signature: monster block, full charge",
		"pose": [RallyEventModel.EventType.BLOCK, 1.0, 0.0],
		"signature_move": "monster_block",
	},
]

func _ready() -> void:
	await get_tree().process_frame
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	var requested_strip := ""
	var requested_camera := ""
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--strip="):
			requested_strip = argument.trim_prefix("--strip=")
		elif argument.begins_with("--camera="):
			requested_camera = argument.trim_prefix("--camera=")
	if requested_strip.is_empty() or not CAMERAS.has(requested_camera):
		push_error(
			"Animation frame rendering requires --strip=<name> and "
			+ "--camera=side|front|three_quarter; CI isolates each artifact in its own "
			+ "renderer process."
		)
		get_tree().quit(2)
		return
	for strip in STRIPS:
		if not requested_strip.is_empty() and str(strip.name) != requested_strip:
			continue
		for camera_name in CAMERAS:
			if str(camera_name) == requested_camera:
				await _shoot(strip, str(camera_name))
	get_tree().quit()


func _shoot(strip: Dictionary, camera_name: String) -> void:
	var root := get_tree().root
	var stage := Node3D.new()
	root.add_child(stage)

	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-38.0, 154.0, 0.0)
	light.light_energy = 1.38
	stage.add_child(light)
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-16.0, 216.0, 0.0)
	fill.light_energy = 0.45
	stage.add_child(fill)

	var world_environment := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("0d1420")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("46566e")
	env.ambient_light_energy = 1.0
	world_environment.environment = env
	stage.add_child(world_environment)

	var view: Array = CAMERAS[camera_name]
	var camera := Camera3D.new()
	if bool(strip.get("closeup", false)):
		var closeup_position := Vector3(0.0, 1.82, -5.2) if camera_name == "side" \
			else Vector3(2.5, 2.05, -5.0)
		camera.look_at_from_position(closeup_position, Vector3(0.0, 1.62, 0.0))
		camera.fov = 34.0
	else:
		camera.position = view[0]
		camera.rotation_degrees = view[1]
		camera.fov = float(view[2])
	stage.add_child(camera)
	# Each strip builds and frees its own stage. After the first camera has been
	# removed a later one is not guaranteed to become current automatically,
	# which used to make most artifacts repeat the first strip. The review image
	# must belong to the camera named in its filename.
	camera.current = true
	camera.make_current()

	## **A floor.** A recovery is a body arriving at the ground, and judging one
	## against empty space is judging half of it -- the first read of the fall was
	## "awkward" and the ground it is falling to was not in the picture.
	var floor_mesh := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(26.0, 14.0)
	floor_mesh.mesh = plane
	var floor_material := StandardMaterial3D.new()
	floor_material.albedo_color = Color("16202e")
	floor_mesh.material_override = floor_material
	stage.add_child(floor_mesh)

	# Odd action rows contain an exact middle frame, so phase zero/contact is an
	# image rather than the gap between -0.143 and +0.143.
	var frame_count := 9 if bool(strip.get("action_sweep", false)) else FRAME_COUNT
	var spacing := float(strip.get("frame_spacing", FRAME_SPACING))
	if bool(strip.get("action_sweep", false)):
		# The exact contact frame makes action rows one subject wider than the
		# older eight-frame strips. Keep the full recovery inside both review
		# cameras instead of clipping the ninth figure at the right edge.
		spacing = minf(spacing, 1.34)
	var start := spacing * float(frame_count - 1) * 0.5
	for index in range(frame_count):
		var progress := float(index) / float(frame_count - 1)
		var actor := ACTOR.instantiate()
		stage.add_child(actor)
		# Hold the athlete constant across the strip: only phase may change.
		actor.configure(900, true, "%d%%" % roundi(progress * 100.0),
			"Right", {
				"height_cm": 191.0, "wingspan_cm": 197.0, "mass_kg": 84.0,
				"body_type": "Cani", "expression": "neutral",
				"appearance": {"palette_index": 0, "marking": "none"},
			})
		assert(actor.player_id == 900 and actor.body_type == "Cani")
		actor.set_tactical_position(
			Vector2.ZERO, Vector3(-start + spacing * float(index), 0.0, 0.0)
		)
		actor.has_facing = true
		actor.facing_yaw = 0.0
		if bool(strip.get("action_sweep", false)):
			actor.ground_speed_mps = float(strip.get("ground_speed_mps", 0.0))
			actor.stride_cycle = float(strip.get("stride_cycle", 0.0))
			actor.contact_posture = str(strip.get("posture", "planted"))
			actor.contact_recovery = str(strip.get("recovery", "platform"))
			var action_pose: Array = strip.pose
			var action_phase := lerpf(-1.0, 1.0, progress)
			var action_elevation := float(action_pose[1])
			if int(action_pose[0]) == RallyEventModel.EventType.ATTACK:
				action_elevation *= SpikeBiomechanics.elevation_at(action_phase)
			elif int(action_pose[0]) == RallyEventModel.EventType.BLOCK:
				action_elevation *= BlockBiomechanics.elevation_at(action_phase)
			actor.set_pose(
				int(action_pose[0]), action_elevation, action_phase,
				Vector2.RIGHT, true, Dictionary(strip.get("context", {})),
			)
			actor.identity_label.text = "%+.2f" % action_phase
		elif bool(strip.get("idle_sweep", false)):
			actor.ready_stance = "watching"
			actor._presentation_time_seconds = progress * IdleBiomechanics.SWAY_SECONDS
			actor.set_pose(-1, 0.0, 0.0, Vector2.RIGHT, false)
			actor.identity_label.text = "%.1fs" % actor._presentation_time_seconds
		elif bool(strip.get("ready_settle", false)):
			actor._stance_remaining = 0.0
			actor.ready_stance = "watching"
			actor._stance_remaining = 0.0
			actor.set_pose(-1, 0.0, 0.0, Vector2.RIGHT, false)
			actor.ready_stance = "defending"
			actor._stance_remaining = actor._stance_duration * (1.0 - progress)
			actor.set_pose(-1, 0.0, 0.0, Vector2.RIGHT, false)
		elif bool(strip.get("blink_sweep", false)):
			var interval := IdleBiomechanics.blink_interval_seconds(actor.player_id)
			var offset := IdleBiomechanics.phase_offset(actor.player_id) * interval
			var duration := IdleBiomechanics.BLINK_CLOSE_SECONDS \
				+ IdleBiomechanics.BLINK_HOLD_SECONDS \
				+ IdleBiomechanics.BLINK_OPEN_SECONDS
			actor._presentation_time_seconds = progress * duration - offset
			actor.set_pose(-1, 0.0, 0.0, Vector2.RIGHT, false)
			actor.identity_label.visible = false
		elif strip.has("recovery"):
			actor.contact_recovery = str(strip.recovery)
			actor.contact_posture = str(strip.get("posture", "planted"))
			## Recovery is the DEFENSE pose's own phase -- `set_pose` passes it
			## straight into `_apply_dig_posture` as `recovery_progress` -- so the
			## strip walks the same number the rally walks rather than a second
			## one invented here.
			## **From before the contact, not from it.**
			##
			## The pose's platform forms across phase -0.34 to -0.08 and the
			## recovery runs from 0 to 0.86, so a strip that started at 0 could
			## only ever show the second half -- which is why the first read of
			## this animation was "nothing happens and then everything does". The
			## sweep now covers the whole action: arms to the ball, body follows,
			## then the roll resolves.
			actor.set_pose(
				RallyEventModel.EventType.DIG, 0.0,
				lerpf(RECOVERY_STRIP_FROM_PHASE, 1.0, progress),
				Vector2.RIGHT, true,
			)
		elif bool(strip.get("approach_sweep", false)):
			## Phase from -1.0 to the plant, so the row is the whole approach and
			## its last frame is the pose the swing starts from.
			## A hitter approaching is *moving*, and the stance width the gait
			## hands out at zero speed is the ready stance's. Left at rest the row
			## drew the approach with the feet planted wide apart, which is a
			## posture and not a run-up -- the strip has to supply the speed the
			## action implies or it is photographing a different pose.
			actor.ground_speed_mps = 3.6
			actor.set_pose(
				RallyEventModel.EventType.ATTACK, 0.0,
				lerpf(-1.0, SpikeBiomechanics.PLANT_END, progress),
				Vector2.RIGHT, true,
			)
			actor.identity_label.text = ApproachBiomechanics.resolve(
				progress, true
			).step_name
			actor.has_facing = true
		elif strip.has("gait_sweep"):
			## Speed rises across the row and the stride advances with it, so the
			## row reads as one continuous acceleration rather than eight
			## snapshots of unrelated velocities.
			var sweep: Array = strip.gait_sweep
			var speed := lerpf(float(sweep[0]), float(sweep[1]), progress)
			actor.ground_speed_mps = speed
			actor.travel_heading_offset = float(strip.get("gait_heading", 0.0))
			actor.stride_cycle = progress * 2.0
			actor.set_pose(-1, 0.0, 0.0, Vector2.RIGHT, false)
			actor.identity_label.text = "%.1f m/s" % speed
			actor.has_facing = true
		elif bool(strip.get("platform_sweep", false)):
			## The ball arrives from a different bearing in every frame and leaves
			## toward the same setter, so the bisector -- and therefore the
			## platform -- swings across the row while nothing else changes.
			var bearing := lerpf(-80.0, 80.0, progress)
			var incoming := {
				"start_position": Vector2(0.5, 0.5) + Vector2(
					sin(deg_to_rad(bearing)), cos(deg_to_rad(bearing))
				) * 0.42,
				"end_position": Vector2(0.5, 0.5),
				"start_height_meters": 2.4,
				"end_height_meters": 0.9,
				"duration": 0.8,
			}
			var outgoing := {
				"start_position": Vector2(0.5, 0.5),
				"end_position": Vector2(0.5, 0.34),
				"start_height_meters": 0.9,
				"end_height_meters": 2.3,
				"duration": 0.9,
			}
			actor.contact_posture = str(strip.get("posture", "planted"))
			## **Facing the ball, the way playback faces them.**
			##
			## `set_pose` turns a passer toward the incoming contact direction, so
			## measuring the residual against a body facing down-court is measuring
			## against a voli who is not there. Done that way the residual came out
			## at 46 degrees for a ball arriving 11 degrees off centre, which is
			## the test being wrong rather than the solve.
			var body_yaw := bearing + 180.0
			actor.facing_yaw = deg_to_rad(body_yaw)
			actor.rotation.y = actor.facing_yaw
			actor.contact_platform_aim = PlatformAim.relative(
				PlatformAim.solve(incoming, outgoing), body_yaw
			)
			var sweep_pose: Array = strip.pose
			actor.set_pose(
				int(sweep_pose[0]), float(sweep_pose[1]), float(sweep_pose[2]),
				Vector2.RIGHT, true,
			)
			actor.identity_label.text = "%+.0f" % bearing
			## `set_pose` would otherwise turn them again from the pose's own
			## direction and undo the facing set above.
			actor.has_facing = true
		else:
			var pose: Array = strip.pose
			var context := {}
			if strip.has("signature_move"):
				context = {
					"signature_move": str(strip.signature_move),
					"signature_charge": 0.95,
					"signature_succeeded": true,
					"action_power": 1.0,
				}
			## **Elevation from the phase, not held at 1.0.**
			##
			## Every signature frame was posed at full elevation, so the strip
			## showed a blocker who never left the floor -- eight identical
			## heights with no arc. Playback drives a block's lift from
			## `BlockBiomechanics.elevation_at(phase)`; the strip now does the
			## same, so the row shows the jump the action actually has.
			var elevation := float(pose[1])
			if int(pose[0]) == RallyEventModel.EventType.BLOCK:
				elevation *= BlockBiomechanics.elevation_at(progress)
			elif int(pose[0]) == RallyEventModel.EventType.ATTACK:
				elevation *= SpikeBiomechanics.elevation_at(progress)
			actor.set_pose(
				int(pose[0]), elevation, progress, Vector2.RIGHT, true, context
			)
		if strip.has("recovery"):
			actor.identity_label.text = "%+.2f" % lerpf(
				RECOVERY_STRIP_FROM_PHASE, 1.0, progress
			)
		elif strip.has("gait_sweep") or bool(strip.get("approach_sweep", false)):
			pass
		else:
			actor.identity_label.text = "%d%%" % roundi(progress * 100.0)
		actor.set_highlighted(index == frame_count - 1)
		if bool(strip.get("blink_sweep", false)):
			actor.identity_label.visible = false

	for _frame in range(8):
		await get_tree().process_frame
	var path := "%s/frames_%s_%s.png" % [OUT, str(strip.name), camera_name]
	root.get_texture().get_image().save_png(path)
	print("saved %s  (%s)" % [
		ProjectSettings.globalize_path(path), str(strip.caption)
	])
	stage.queue_free()
	await get_tree().process_frame
