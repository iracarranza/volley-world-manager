extends Node

## Getting into a stance, and getting up off the floor.
##
##     xvfb-run -a godot --path . res://tools/preview/transition_preview.tscn
##
## Five sheets, and the first three are the ones that had no pictures because
## they had no frames: a stance change was one assignment and happened between
## them.
##
##   ready_from_stand   watching -> defending, dropping into the crouch
##   stand_from_ready   defending -> watching, unwinding out of it
##   floor_from_net     blocking -> defending, a middle dropping off the tape
##   up_from_knee       the half-kneel standing back up
##   up_from_roll       the rolling receive standing back up
##   up_from_blown      driven off the ball onto your back, and getting up
##
## **Both clocks are forced rather than waited on**, the same way `gait_preview`
## photographs a landing: these run in seconds, and a still sheet has no seconds
## in it. What is being exercised is still the shipped path -- the blend, the
## overlay, the settle curve -- with only the clock's remaining time written by
## hand. A preview that reimplemented the blend would prove nothing about it.
const ACTOR := preload("res://scenes/components/player_actor_3d.tscn")
const RallyEventModel := preload("res://scripts/models/rally_event.gd")

## Even, because a transition has no landmark in it -- unlike a swing, which has
## a contact. The ends are included so the sheet shows what it starts and
## finishes as rather than only the middle.
const STEPS: Array[float] = [0.0, 0.2, 0.4, 0.6, 0.8, 1.0]

## Where a contact window typically hands over to the overlay: a little under
## half way through the recovery. Chosen rather than measured, and the number the
## floor sheets start their span at.
const HANDOVER: float = 0.42


func _ready() -> void:
	await get_tree().process_frame
	await _shoot_stance("ready_from_stand", "watching", "defending")
	await _shoot_stance("stand_from_ready", "defending", "watching")
	await _shoot_stance("floor_from_net", "blocking", "defending")
	await _shoot_floor("up_from_knee", "knee", "planted")
	await _shoot_floor("up_from_roll", "fall", "off-axis")
	await _shoot_floor("up_from_blown", "blown_away", "planted")
	get_tree().quit()


func _stage() -> Node3D:
	var stage := Node3D.new()
	get_tree().root.add_child(stage)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-38.0, 152.0, 0.0)
	light.light_energy = 1.3
	stage.add_child(light)
	var environment := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("101722")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("53637d")
	env.ambient_light_energy = 0.9
	environment.environment = env
	stage.add_child(environment)
	var camera := Camera3D.new()
	camera.position = Vector3(-9.2, 1.35, 0.0)
	camera.rotation_degrees = Vector3(0.0, -90.0, 0.0)
	camera.fov = 34.0
	stage.add_child(camera)
	return stage


func _place(stage: Node3D, index: int, count: int, caption: String) -> Node3D:
	var spacing := 1.32
	var start := -spacing * float(count - 1) * 0.5
	var actor: Node3D = ACTOR.instantiate()
	stage.add_child(actor)
	actor.configure(
		index + 1, true, "Voli", "Right",
		{"height_cm": 190.0, "wingspan_cm": 194.0, "body_type": "Feli"},
	)
	actor.set_tactical_position(
		Vector2.ZERO, Vector3(0.0, 0.0, start + spacing * float(index))
	)
	actor.identity_label.text = caption
	actor.identity_label.position.y += 0.34 if index % 2 == 0 else 0.0
	actor.set_highlighted(true)
	return actor


## One row of a stance change, through its own clock.
func _shoot_stance(shot_name: String, from_stance: String, to_stance: String) -> void:
	var stage := _stage()
	var seconds := StanceTransition.seconds_between(
		ReadyStance.joints(from_stance), ReadyStance.joints(to_stance)
	)
	for index in range(STEPS.size()):
		var progress := STEPS[index]
		var actor := _place(
			stage, index, STEPS.size(),
			"%.2f  %.0fms" % [progress, seconds * 1000.0],
		)
		## Landed on the starting stance first and *then* asked for the new one,
		## so the blend has a real body to leave rather than the default the rig
		## spawns in. Zeroing the clock in between is what makes the second
		## assignment a transition from the first stance rather than from
		## partway into it.
		actor.ready_stance = from_stance
		actor._stance_remaining = 0.0
		actor.ready_stance = to_stance
		actor._stance_remaining = actor._stance_duration * (1.0 - progress)
		actor.set_pose(
			RallyEventModel.EventType.SERVE, 0.0, 0.0, Vector2(0.0, -1.0), false
		)
	await _capture(stage, shot_name)


## One row of a floor recovery finishing *after* its contact window has closed.
##
## Posed twice on purpose. The first call is the last frame of the window: it is
## what arms the overlay and captures the pose the floor left the body in. The
## second is a frame of ordinary off-ball playback, which is where the getting-up
## now happens and where nothing happened before.
func _shoot_floor(shot_name: String, recovery: String, posture: String) -> void:
	var stage := _stage()
	var seconds := StanceTransition.floor_seconds(recovery)
	for index in range(STEPS.size()):
		## **The span is the tail, not the whole recovery.**
		##
		## Stepping the overlay from 0 re-runs the fall from the beginning, which
		## is what the first version of this sheet did and it read as a body
		## going *down* -- the opposite of what is being shown. The overlay
		## resumes at whatever clock the contact window ended on, so the sheet
		## has to start there too.
		var progress := lerpf(HANDOVER, 1.0, STEPS[index])
		var actor := _place(
			stage, index, STEPS.size(),
			"%.2f  %.0fms" % [progress, seconds * (1.0 - HANDOVER) * 1000.0],
		)
		actor.contact_recovery = recovery
		actor.contact_posture = posture
		actor.set_pose(
			RallyEventModel.EventType.DIG, 0.0,
			PlayerActor3D.RECOVERY_END_PHASE * HANDOVER,
			Vector2(0.7, -0.7), true,
		)
		actor._floor_direction = Vector2(0.7, -0.7)
		actor._floor_remaining = actor._floor_duration * (1.0 - progress)
		actor.set_pose(
			RallyEventModel.EventType.SERVE, 0.0, 0.0, Vector2(0.0, -1.0), false
		)
	await _capture(stage, shot_name)


func _capture(stage: Node3D, shot_name: String) -> void:
	for _frame in range(8):
		await get_tree().process_frame
	var path := "user://move_%s.png" % shot_name
	get_tree().root.get_texture().get_image().save_png(path)
	print("saved %s" % ProjectSettings.globalize_path(path))
	stage.queue_free()
	await get_tree().process_frame
