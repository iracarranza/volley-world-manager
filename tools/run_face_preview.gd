extends Node

## Line the five faces up and photograph them.
##
## An expression is a claim about what reads at a glance, and the only way to
## check that claim is to look -- twice, at two distances. A face tuned in a
## close-up and never seen at match scale is a face that works in exactly one
## screen.
##
## Run:
##   xvfb-run -a godot --path . res://tools/face_preview.tscn

const ACTOR := preload("res://scenes/components/player_actor_3d.tscn")
const BodyTypeModelsScript := preload("res://scripts/data/body_type_models.gd")
const FaceExpressionsScript := preload("res://scripts/data/face_expressions.gd")

## In the order they should be compared, not the order they are declared.
## neutral and flat sit next to each other on purpose -- they are the pair most
## at risk of being the same face, since the only difference is mouth width.
const ORDER: Array[String] = [
	"happy", "neutral", "flat", "worried", "cross",
]

## Close enough to judge the drawing, and far enough to judge whether it
## survives a match.
##
## Cameras sit on **negative** Z looking back toward the origin, because the rig
## faces -Z -- the shoes stick out that way. A camera on +Z photographs the backs
## of their heads, which is what the first run of this tool did, and a blank
## sphere is indistinguishable from a face that failed to build.
## Each shot varies exactly one thing.
##
##   name, camera, fov, expressions across the row, bodies across the row
##
## The first pass varied body type *and* expression at once, which meant a face
## that read badly could equally have been a bad expression or a bad fit to that
## head, and there was no way to tell which from the picture.
const SHOTS: Array = [
	## Five expressions, one body. This is the sheet that judges the drawing.
	["faces_expressions", Vector3(0.0, 1.62, -4.5), 38.0, ORDER, ["Turnip"]],
	## One expression, five bodies. This is the sheet that judges the fit -- and
	## the one that exposed the muzzle and the beak sitting on top of the mouth.
	["faces_bodies", Vector3(0.0, 1.68, -5.0), 40.0, ["happy"], BODIES],
	## The two special cases, close enough to see whether the mouth actually
	## cleared the muzzle. A muzzle is a solid, and a mouth a millimetre inside
	## one is indistinguishable in a wide shot from a mouth that was never built.
	["faces_snouts", Vector3(0.0, 1.80, -2.2), 26.0,
		["happy", "cross"], ["Feli", "Avi"]],
	## The pair whose whole difference is the direction the brows tilt, one per
	## frame and dead centre. They shipped swapped once, and neither the row
	## sheet nor a two-up close-up could settle it: a head photographed from 30
	## degrees off axis has its eyes sheared by perspective, which is the same
	## visual signal as a tilt. One subject, centred, is the only framing in
	## which this claim can be checked at all.
	["faces_brow_worried", Vector3(0.0, 1.74, -1.7), 22.0,
		["worried"], ["Turnip"]],
	["faces_brow_cross", Vector3(0.0, 1.74, -1.7), 22.0,
		["cross"], ["Turnip"]],
	## And whether any of it survives the distance a match is actually watched at.
	["faces_match", Vector3(0.0, 2.05, -9.6), 46.0, ORDER, BODIES],
]

## Produce names for the Vegi row, plus the two modelled types.
const BODIES: Array[String] = [
	"Feli", "Avi", "Turnip", "Aubergine", "Stalk",
]


func _ready() -> void:
	await get_tree().process_frame
	for shot in SHOTS:
		await _shoot(shot)
	get_tree().quit()


func _shoot(shot: Array) -> void:
	var root := get_tree().root
	var stage := Node3D.new()
	root.add_child(stage)

	## Turned to match the camera. The first run lit the row from +Z while
	## photographing it from -Z, so every face was in its own shadow and the
	## drawing could not be judged at all.
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-36.0, 158.0, 0.0)
	light.light_energy = 1.4
	stage.add_child(light)

	var environment := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("101722")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("53637d")
	env.ambient_light_energy = 1.0
	environment.environment = env
	stage.add_child(environment)

	var camera := Camera3D.new()
	camera.position = shot[1]
	camera.rotation_degrees = Vector3(0.0, 180.0, 0.0)
	camera.fov = float(shot[2])
	stage.add_child(camera)

	var expressions: Array = shot[3]
	var bodies: Array = shot[4]
	var count := maxi(expressions.size(), bodies.size())
	var spacing := 1.15
	## Negated, because a camera turned around mirrors the row -- without this the
	## five faces photograph in reverse order and the labels stop matching the
	## order they are meant to be compared in.
	var start := spacing * float(count - 1) * 0.5
	for index in range(count):
		var wanted := str(bodies[index % bodies.size()])
		var expression := str(expressions[index % expressions.size()])
		var body_type := wanted if wanted in ["Feli", "Avi"] else "Vegi"
		var actor_id := index + 1
		if body_type == "Vegi":
			## Search for an id that hashes to this produce, so the preview runs
			## the same deterministic selection a match does.
			for candidate in range(1, 6000):
				if BodyTypeModelsScript.produce_for(candidate) == wanted:
					actor_id = candidate
					break
		var actor: Node3D = ACTOR.instantiate()
		stage.add_child(actor)
		actor.configure(
			actor_id, index % 2 == 0, expression, "Right",
			{
				"height_cm": 188.0, "wingspan_cm": 191.0,
				"body_type": body_type,
			},
		)
		actor.set_tactical_position(
			Vector2.ZERO, Vector3(start - spacing * float(index), 0.0, 0.0)
		)
		actor.set_pose(-1, 0.0, 0.0, Vector2.ZERO, false)
		actor.set_expression(expression)
		## Whichever axis the shot is varying is what the caption has to say.
		actor.identity_label.text = expression if expressions.size() > 1 \
			else wanted
		actor.set_highlighted(true)

	for _frame in range(8):
		await get_tree().process_frame
	var path := "user://%s.png" % str(shot[0])
	root.get_texture().get_image().save_png(path)
	print("saved %s" % ProjectSettings.globalize_path(path))
	stage.queue_free()
	await get_tree().process_frame
