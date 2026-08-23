extends Node

## Every animation as a strip of frames, so a motion can be judged as a motion.
##
##     xvfb-run -a godot --path . res://tools/animation_frames.tscn
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

## Frames per strip. Eight is enough to see an ease curve and few enough that
## each frame is still large enough to read at a glance.
const FRAME_COUNT: int = 8
const FRAME_SPACING: float = 1.55
## Where a recovery strip starts, in pose phase. Before the platform forms, so
## the row reads approach -> contact -> recovery rather than beginning mid-fall.
const RECOVERY_STRIP_FROM_PHASE: float = -0.34

## The two angles every motion is shot from.
const CAMERAS := {
	"side": [Vector3(0.0, 1.15, 9.4), Vector3(-4.0, 0.0, 0.0), 46.0],
	"three_quarter": [
		Vector3(5.6, 3.05, 8.2), Vector3(-15.0, 34.0, 0.0), 44.0,
	],
}

## Each strip states the whole of what it is showing.
##
##   recovery -- the floor motion driven across `recovery` 0 to 1
##   pose     -- [event type, elevation, phase] driven across `phase` instead
##   signature-- a named rule-of-cool move at full charge
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
	for strip in STRIPS:
		for camera_name in CAMERAS:
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
	camera.position = view[0]
	camera.rotation_degrees = view[1]
	camera.fov = float(view[2])
	stage.add_child(camera)

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

	var start := FRAME_SPACING * float(FRAME_COUNT - 1) * 0.5
	for index in range(FRAME_COUNT):
		var progress := float(index) / float(FRAME_COUNT - 1)
		var actor := ACTOR.instantiate()
		stage.add_child(actor)
		actor.configure(900 + index, true, "%d%%" % roundi(progress * 100.0),
			"Right", {"height_cm": 191.0, "wingspan_cm": 197.0, "mass_kg": 84.0})
		actor.set_tactical_position(
			Vector2.ZERO, Vector3(start - FRAME_SPACING * float(index), 0.0, 0.0)
		)
		actor.has_facing = true
		actor.facing_yaw = 0.0
		if strip.has("recovery"):
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
				elevation *= sin(clampf(progress, 0.0, 1.0) * PI)
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
		actor.set_highlighted(index == FRAME_COUNT - 1)

	for _frame in range(8):
		await get_tree().process_frame
	var path := "user://frames_%s_%s.png" % [str(strip.name), camera_name]
	root.get_texture().get_image().save_png(path)
	print("saved %s  (%s)" % [
		ProjectSettings.globalize_path(path), str(strip.caption)
	])
	stage.queue_free()
	await get_tree().process_frame
