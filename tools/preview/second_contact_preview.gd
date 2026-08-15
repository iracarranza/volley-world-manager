extends Node

## The second contact and the floor, laid out flat.
##
##     xvfb-run -a godot --path . res://tools/preview/second_contact_preview.tscn
##
## `run_set_posture_shot` prints the joints and proves the postures differ as
## numbers. It cannot say whether a jump set reads as a jump set, and a table of
## shoulder angles is not a thing anybody can look at and disagree with.
##
## Six sheets:
##
##   set_standing    the push off the floor
##   set_jump        the same ball out of a body with one fewer joint working
##   set_underhand   the ball that never got to hand height
##   set_back        the arch, which is an overlay on all three
##   recover_knee    a half-kneel, and what happens after it
##   recover_roll    a rolling receive, and what happens after that
##   recover_blown   driven off the ball, which had no other side at all
##
## The last two are here because of what they show rather than what they prove.
## The recovery runs on `_recovery_clock`, which is a *phase* -- so it only
## advances while playback is still drawing this voli as the contact actor. Watch
## the last frame of each: the body is on its way up and the clock has run out.
const ACTOR := preload("res://scenes/components/player_actor_3d.tscn")
const RallyEventModel := preload("res://scripts/models/rally_event.gd")

## Six samples across the signed phase, weighted toward the contact because that
## is where every one of these actions actually differs.
const SET_PHASES: Array[float] = [-0.70, -0.30, -0.08, 0.00, 0.26, 0.62]
## The recovery clock runs 0 at contact to 1 back on the feet, so an even spread
## is the right one -- there is no landmark in it to favour.
const RECOVERY_PHASES: Array[float] = [0.00, 0.16, 0.34, 0.52, 0.70, 0.86]


func _ready() -> void:
	await get_tree().process_frame
	await _shoot_set("set_standing", "", false, "")
	await _shoot_set("set_jump", "jump", false, "")
	await _shoot_set("set_underhand", "", false, "under the hands")
	await _shoot_set("set_back", "", true, "")
	await _shoot_recovery("recover_knee", "knee", "planted")
	await _shoot_recovery("recover_roll", "fall", "off-axis")
	await _shoot_recovery("recover_blown", "blown_away", "planted")
	get_tree().quit()


## The same stage `gait_preview` uses, side-on for the same reason: a set and a
## recovery are both sagittal actions and a front-on camera hides the joints
## that carry them.
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
	## Placed once and then left alone, so the actor's own speed estimate -- which
	## comes from successive placements -- does not fight the still being taken.
	actor.set_tactical_position(
		Vector2.ZERO, Vector3(0.0, 0.0, start + spacing * float(index))
	)
	actor.identity_label.text = caption
	actor.identity_label.position.y += 0.34 if index % 2 == 0 else 0.0
	actor.set_highlighted(true)
	return actor


## One row of a set, through the phase.
##
## The posture and the arch go in through `action_context`, which is the same
## dictionary `match_screen.gd` fills from the SET event's metadata -- so this
## exercises the path that ships rather than a reimplementation of it. That
## distinction has mattered on this branch: a posture argument that never
## arrives and a posture argument that works look identical in a still.
func _shoot_set(
	shot_name: String, posture: String, back_set: bool, reason: String
) -> void:
	var stage := _stage()
	for index in range(SET_PHASES.size()):
		var phase := SET_PHASES[index]
		var actor := _place(
			stage, index, SET_PHASES.size(), "%+.2f" % phase
		)
		actor.set_pose(
			RallyEventModel.EventType.SET,
			## Elevation is the ball's, not the body's: a jump set lifts itself
			## through `rise_metres` and would be lifted twice if this carried a
			## height as well.
			0.0, phase, Vector2(0.0, -1.0), true,
			{
				"set_posture": posture,
				"set_posture_reason": reason,
				"back_set": back_set,
			},
		)
	await _capture(stage, shot_name)


## One row of a floor recovery, through its own clock.
func _shoot_recovery(
	shot_name: String, recovery: String, posture: String
) -> void:
	var stage := _stage()
	for index in range(RECOVERY_PHASES.size()):
		var phase := RECOVERY_PHASES[index]
		var actor := _place(
			stage, index, RECOVERY_PHASES.size(), "%.2f" % phase
		)
		actor.contact_recovery = recovery
		actor.contact_posture = posture
		actor.set_pose(
			RallyEventModel.EventType.DEFENSE, 0.0, phase,
			Vector2(0.7, -0.7), true,
		)
	await _capture(stage, shot_name)


func _capture(stage: Node3D, shot_name: String) -> void:
	for _frame in range(8):
		await get_tree().process_frame
	var path := "user://pose_%s.png" % shot_name
	get_tree().root.get_texture().get_image().save_png(path)
	print("saved %s" % ProjectSettings.globalize_path(path))
	stage.queue_free()
	await get_tree().process_frame
