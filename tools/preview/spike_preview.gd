extends Node

## Photograph one spike, frame by frame.
##
## Pose work is only checkable by looking, and the attack is the pose that most
## needed looking at: it held a fixed stride and a fixed lean for its entire
## duration, interpolated every joint on one value, and -- because playback fed
## it a phase that restarted at contact -- drew the hitter cocked behind their
## own head at the instant the ball left their hand.
##
## `SpikeBiomechanics` is a pure function of phase, so a row of samples across
## that phase *is* the animation, laid out flat. Read left to right: plant,
## takeoff, cock, contact, follow-through, landing. What to check is that the
## segments do not move together -- the knees should already be straightening
## while the arms are still behind, and the elbow should still be folded when
## the shoulder is most of the way to the ball.
##
## Run:
##   xvfb-run -a godot --path . res://tools/preview/spike_preview.tscn

const ACTOR := preload("res://scenes/components/player_actor_3d.tscn")
const RallyEventModel := preload("res://scripts/models/rally_event.gd")

## Sampled at the named boundaries plus the middle of each phase, so no phase is
## represented only by its endpoints. Contact is deliberately sampled twice, a
## hair either side, because that is the seam the old code tore at.
## Eight, not fifteen. A wider sheet fits more of the swing and shows less of
## it: at fifteen the figures were 60 px tall and the arms -- the entire point --
## were unreadable. One frame per named phase plus the contact.
const SAMPLES: Array[float] = [
	-1.00, -0.62, -0.40, -0.14, 0.00, 0.20, 0.45, 1.00,
]

## How high the hitter is at each sample. Playback derives this from the event's
## own elevation curve; reproduced here only so the row reads as a jump rather
## than a mime, and shaped to leave the floor at the takeoff the pose model
## itself declares.
const GROUND_PHASE: float = -0.62
const LANDING_PHASE: float = 0.45


func _ready() -> void:
	await get_tree().process_frame
	await _shoot("swing", "Right")
	await _shoot("swing_left", "Left")
	get_tree().quit()


func _shoot(name: String, hand: String) -> void:
	var root := get_tree().root
	var stage := Node3D.new()
	root.add_child(stage)

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

	## Side-on. A spike is a sagittal action -- the arch, the cock and the whip
	## all happen in the plane the camera has to be perpendicular to, and the
	## front-on framing the body-type sheet uses hides every one of them.
	var camera := Camera3D.new()
	camera.position = Vector3(-9.2, 2.05, 0.0)
	camera.rotation_degrees = Vector3(0.0, -90.0, 0.0)
	camera.fov = 34.0
	stage.add_child(camera)

	var spacing := 1.32
	var start := -spacing * float(SAMPLES.size() - 1) * 0.5
	for index in range(SAMPLES.size()):
		var phase := SAMPLES[index]
		var actor: Node3D = ACTOR.instantiate()
		stage.add_child(actor)
		actor.configure(
			index + 1, true, "Hitter", hand,
			{"height_cm": 190.0, "wingspan_cm": 194.0, "body_type": "Feli"},
		)
		actor.set_tactical_position(
			Vector2.ZERO, Vector3(0.0, 0.0, start + spacing * float(index))
		)
		actor.identity_label.text = "%+.2f %s" % [
			phase, SpikeBiomechanics.phase_name(phase),
		]
		## Staggered, because eight captions at one height overlap into a single
		## unreadable line -- which the first sheet did, and which made the row
		## look like it had fewer frames than it has.
		actor.identity_label.position.y += 0.34 if index % 2 == 0 else 0.0
		actor.set_pose(
			RallyEventModel.EventType.ATTACK, _elevation(phase), phase,
			Vector2(0.0, -1.0), true,
		)
		actor.set_highlighted(true)

	for _frame in range(8):
		await get_tree().process_frame
	var path := "user://spike_%s.png" % name
	root.get_texture().get_image().save_png(path)
	print("saved %s" % ProjectSettings.globalize_path(path))
	stage.queue_free()
	await get_tree().process_frame


## A jump, not a hover. Zero until the feet leave the floor at the end of the
## plant, peaking at contact, and back down by the end of the follow-through.
func _elevation(phase: float) -> float:
	if phase <= GROUND_PHASE:
		return 0.0
	if phase <= 0.0:
		return sin(
			(phase - GROUND_PHASE) / (0.0 - GROUND_PHASE) * PI * 0.5
		)
	if phase >= LANDING_PHASE:
		return 0.0
	return cos(phase / LANDING_PHASE * PI * 0.5)
