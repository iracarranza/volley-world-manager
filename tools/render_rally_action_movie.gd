extends SceneTree

## Movie Maker harness for the procedural rally-action choreography.
##
## One invocation records one continuous action from the same fixed Cani actor,
## camera, floor, palette, and light rig used by the still-frame acceptance
## gallery. Only the presentation phase changes during the clip.
##
##   godot --write-movie out.avi --fixed-fps 30 \
##     --script tools/render_rally_action_movie.gd -- serve_jump_topspin

const SIZE := Vector2i(960, 540)
const FPS := 30
const ACTOR := preload("res://scenes/components/player_actor_3d.tscn")
const RallyEventModel := preload("res://scripts/models/rally_event.gd")
const IdleBiomechanics := preload("res://scripts/data/idle_biomechanics.gd")

const ACTION_SECONDS := 2.4
const HOLD_SECONDS := 0.35
const IDLE_SECONDS := 4.0
const BLINK_SECONDS := 1.25

const ACTIONS := {
	"serve_standing": {
		"event": RallyEventModel.EventType.SERVE,
		"context": {"serve_style": "Standing", "action_power": 0.72},
	},
	"serve_jump_topspin": {
		"event": RallyEventModel.EventType.SERVE,
		"context": {"serve_style": "Jump Topspin", "action_power": 0.84},
	},
	"serve_jump_float": {
		"event": RallyEventModel.EventType.SERVE,
		"context": {"serve_style": "Jump Float", "action_power": 0.68},
	},
	"serve_hybrid": {
		"event": RallyEventModel.EventType.SERVE,
		"context": {"serve_style": "Hybrid", "action_power": 0.76},
	},
	"serve_sky_ball": {
		"event": RallyEventModel.EventType.SERVE,
		"context": {"serve_style": "Sky Ball", "action_power": 0.62},
	},
	"receive_dive": {
		"event": RallyEventModel.EventType.RECEPTION,
		"posture": "reaching",
		"recovery": "fall",
	},
	"set_front": {
		"event": RallyEventModel.EventType.SET,
		"context": {"set_posture": "standing", "back_set": false},
	},
	"set_back": {
		"event": RallyEventModel.EventType.SET,
		"context": {"set_posture": "standing", "back_set": true},
	},
	"attack_power": {
		"event": RallyEventModel.EventType.ATTACK,
		"context": {"attack_type": "Power swing", "action_power": 0.82},
	},
	"attack_roll": {
		"event": RallyEventModel.EventType.ATTACK,
		"context": {"attack_type": "Roll shot", "action_power": 0.62},
	},
	"attack_dink": {
		"event": RallyEventModel.EventType.ATTACK,
		"context": {"attack_type": "Dink", "action_power": 0.38},
	},
	"idle_breath_sway": {"idle": true},
	"standing_to_ready": {"ready": true},
	"blink": {"blink": true, "closeup": true},
}


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var action_name := "" if args.is_empty() else str(args[0]).to_lower()
	if not ACTIONS.has(action_name):
		push_error("Unknown rally action movie '%s'." % action_name)
		quit(2)
		return

	root.size = SIZE
	var spec: Dictionary = ACTIONS[action_name]
	var actor := _build_stage(action_name, bool(spec.get("closeup", false)))
	await process_frame
	await process_frame

	if bool(spec.get("idle", false)):
		await _record_idle(actor)
	elif bool(spec.get("ready", false)):
		await _record_ready(actor)
	elif bool(spec.get("blink", false)):
		await _record_blink(actor)
	else:
		await _record_action(actor, spec)
	quit()


func _build_stage(action_name: String, closeup: bool) -> PlayerActor3D:
	var stage := Node3D.new()
	root.add_child(stage)

	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-38.0, 154.0, 0.0)
	key.light_energy = 1.38
	stage.add_child(key)
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

	var camera := Camera3D.new()
	if closeup:
		camera.look_at_from_position(Vector3(2.5, 2.05, -5.0), Vector3(0.0, 1.62, 0.0))
		camera.fov = 34.0
	else:
		camera.position = Vector3(5.6, 3.05, 8.2)
		camera.rotation_degrees = Vector3(-15.0, 34.0, 0.0)
		camera.fov = 44.0
	stage.add_child(camera)

	var floor_mesh := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(16.0, 11.0)
	floor_mesh.mesh = plane
	var floor_material := StandardMaterial3D.new()
	floor_material.albedo_color = Color("16202e")
	floor_mesh.material_override = floor_material
	stage.add_child(floor_mesh)

	var actor := ACTOR.instantiate() as PlayerActor3D
	stage.add_child(actor)
	actor.configure(900, true, action_name.replace("_", " ").to_upper(), "Right", {
		"height_cm": 191.0,
		"wingspan_cm": 197.0,
		"mass_kg": 84.0,
		"body_type": "Cani",
		"expression": "neutral",
		"appearance": {"palette_index": 0, "marking": "none"},
	})
	actor.set_tactical_position(Vector2.ZERO, Vector3.ZERO)
	actor.has_facing = true
	actor.facing_yaw = 0.0
	actor.identity_label.visible = not closeup
	return actor


func _record_action(actor: PlayerActor3D, spec: Dictionary) -> void:
	actor.contact_posture = str(spec.get("posture", "planted"))
	actor.contact_recovery = str(spec.get("recovery", "platform"))
	var frames := int(ceil((ACTION_SECONDS + HOLD_SECONDS * 2.0) * FPS))
	for frame in range(frames):
		var seconds := float(frame) / float(FPS)
		var action_progress := clampf(
			(seconds - HOLD_SECONDS) / ACTION_SECONDS, 0.0, 1.0
		)
		var phase := lerpf(-1.0, 1.0, action_progress)
		var event_type := int(spec.event)
		var elevation := 0.0
		if event_type == RallyEventModel.EventType.ATTACK:
			elevation = sin(action_progress * PI)
		actor.set_pose(
			event_type,
			elevation,
			phase,
			Vector2.RIGHT,
			true,
			Dictionary(spec.get("context", {})),
		)
		await process_frame


func _record_idle(actor: PlayerActor3D) -> void:
	actor.ready_stance = "watching"
	var frames := int(ceil(IDLE_SECONDS * FPS))
	for frame in range(frames):
		actor._presentation_time_seconds = float(frame) / float(FPS)
		actor.set_pose(-1, 0.0, 0.0, Vector2.RIGHT, false)
		await process_frame


func _record_ready(actor: PlayerActor3D) -> void:
	actor._stance_remaining = 0.0
	actor.ready_stance = "watching"
	actor._stance_remaining = 0.0
	actor.set_pose(-1, 0.0, 0.0, Vector2.RIGHT, false)
	actor.ready_stance = "defending"
	var duration := maxf(actor._stance_duration, 0.25)
	var frames := int(ceil((duration + HOLD_SECONDS * 2.0) * FPS))
	for frame in range(frames):
		var seconds := float(frame) / float(FPS)
		var progress := clampf((seconds - HOLD_SECONDS) / duration, 0.0, 1.0)
		actor._stance_remaining = duration * (1.0 - progress)
		actor.set_pose(-1, 0.0, 0.0, Vector2.RIGHT, false)
		await process_frame


func _record_blink(actor: PlayerActor3D) -> void:
	var interval := IdleBiomechanics.blink_interval_seconds(actor.player_id)
	var offset := IdleBiomechanics.phase_offset(actor.player_id) * interval
	var blink_duration := IdleBiomechanics.BLINK_CLOSE_SECONDS \
		+ IdleBiomechanics.BLINK_HOLD_SECONDS \
		+ IdleBiomechanics.BLINK_OPEN_SECONDS
	var frames := int(ceil(BLINK_SECONDS * FPS))
	for frame in range(frames):
		var progress := clampf(float(frame) / maxf(float(frames - 1), 1.0), 0.0, 1.0)
		## Centre the deterministic blink inside a longer clip so open eyes are
		## visible before and after the transient overlay.
		actor._presentation_time_seconds = lerpf(-0.30, blink_duration + 0.30, progress) - offset
		actor.set_pose(-1, 0.0, 0.0, Vector2.RIGHT, false)
		await process_frame
