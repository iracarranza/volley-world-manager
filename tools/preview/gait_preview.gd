extends Node

## Photograph a stride and a landing, frame by frame.
##
## Same argument as `spike_preview`: a pose model is a pure function, so a row of
## samples across its input *is* the animation laid out flat, and it is the only
## way to check one without watching the game.
##
## What to look for in the gait rows: at a walk the stance leg should be nearly
## straight with the body riding *high* over it, and at a run the same leg should
## be visibly compressed with the body riding *low* -- that inversion is the whole
## claim `GaitBiomechanics` makes. The swing leg's heel should come up near the
## backside in the run row and barely leave the floor in the walk row, and the
## elbows should be locked near a right angle in one and hanging in the other.
##
## In the landing rows: the knee should already be bent on the first frame, fold
## deepest about a third of the way along, and be straight again by the last --
## and the blocker's hands should still be overhead for the first two frames.
##
## Run:
##   xvfb-run -a godot --path . res://tools/preview/gait_preview.tscn

const ACTOR := preload("res://scenes/components/player_actor_3d.tscn")
const RallyEventModel := preload("res://scripts/models/rally_event.gd")
const LandingBiomechanicsScript := preload(
	"res://scripts/data/landing_biomechanics.gd"
)

## Eight frames of one stride. Evenly spaced, unlike the spike's -- a gait has no
## named landmarks worth favouring, and the point is the shape of the whole cycle.
const GAIT_FRAMES: int = 8
const LANDING_FRAMES: int = 6


func _ready() -> void:
	await get_tree().process_frame
	await _shoot_gait("walk", 1.1)
	await _shoot_gait("run", 5.2)
	await _shoot_landing("land_attack", "attack")
	await _shoot_landing("land_block", "block")
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
	## Side-on, for the same reason the spike sheet is: a stride is a sagittal
	## action and a front-on camera hides every joint that carries it.
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
	## Placed once and then overridden, so the actor's own speed estimate -- which
	## is derived from successive placements -- does not fight the speed this sheet
	## is trying to photograph.
	actor.set_tactical_position(
		Vector2.ZERO, Vector3(0.0, 0.0, start + spacing * float(index))
	)
	actor.identity_label.text = caption
	actor.identity_label.position.y += 0.34 if index % 2 == 0 else 0.0
	actor.set_highlighted(true)
	return actor


func _shoot_gait(shot_name: String, speed_mps: float) -> void:
	var stage := _stage()
	for index in range(GAIT_FRAMES):
		var cycle := float(index) / float(GAIT_FRAMES)
		var actor := _place(
			stage, index, GAIT_FRAMES,
			"%.2f  %s" % [cycle, GaitBiomechanics.gait_name(speed_mps)],
		)
		actor.stride_cycle = cycle
		actor.ground_speed_mps = speed_mps
		## Not the contact actor: this is the branch every player on the court is
		## in for most of a rally, and the one that had no gait worth the name.
		actor.set_pose(
			RallyEventModel.EventType.SERVE, 0.0, 0.0, Vector2(0.0, -1.0), false
		)
	await _capture(stage, shot_name)


func _shoot_landing(shot_name: String, action: String) -> void:
	var stage := _stage()
	var duration := LandingBiomechanicsScript.duration_seconds(action)
	for index in range(LANDING_FRAMES):
		var progress := float(index) / float(LANDING_FRAMES - 1)
		var actor := _place(
			stage, index, LANDING_FRAMES, "%s %.2f" % [action, progress]
		)
		## Driven by setting the actor's own landing clock rather than by faking a
		## descent, because the clock is what playback ends up reading and a sheet
		## that photographs a different code path proves nothing about the one that
		## ships.
		actor._airborne_action = action
		actor._was_airborne = false
		actor._landing_remaining = duration * (1.0 - progress)
		actor.ground_speed_mps = 0.0
		actor.set_pose(
			RallyEventModel.EventType.SERVE, 0.0, 0.0, Vector2(0.0, -1.0), false
		)
	await _capture(stage, shot_name)


func _capture(stage: Node3D, shot_name: String) -> void:
	for _frame in range(8):
		await get_tree().process_frame
	var path := "user://gait_%s.png" % shot_name
	get_tree().root.get_texture().get_image().save_png(path)
	print("saved %s" % ProjectSettings.globalize_path(path))
	stage.queue_free()
	await get_tree().process_frame
