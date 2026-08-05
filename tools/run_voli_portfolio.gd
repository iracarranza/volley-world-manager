extends Node

## Photograph every claim the voli model makes, as a portfolio.
##
## The two preview tools this replaces each answered one narrow question and
## framed everything the same way: one row, one distance, one camera angle,
## subjects packed close enough to overlap. That is a contact sheet, and a
## contact sheet is the wrong instrument for judging whether a body reads --
## because a silhouette photographed only from the front is a silhouette you have
## checked from the front.
##
## Every plate here states its own camera, its own spacing and its own per-
## subject facing, so each exhibit is a *scenario* rather than another row. The
## angles are deliberately not shared: a pose that only works head-on is a pose
## that does not work.
##
## Run:
##   xvfb-run -a godot --path . res://tools/voli_portfolio.tscn

const ACTOR := preload("res://scenes/components/player_actor_3d.tscn")
const BodyTypeModelsScript := preload("res://scripts/data/body_type_models.gd")
const FaceExpressionsScript := preload("res://scripts/data/face_expressions.gd")

## Split into two plates rather than one row of eleven. The two groups are
## answering different questions -- whether five animals read apart from each
## other, and whether six produce read apart from each other -- and a single row
## long enough to hold both answers neither at a size worth looking at.
const ANIMAL_BODIES: Array[String] = ["Feli", "Avi", "Cani", "Ursi", "Simi"]
const VEGI_BODIES: Array[String] = [
	"Tomato", "Aubergine", "Pear", "Stalk", "Pepper",
]

## Plates. Each one is a scenario, and each states everything about itself.
##
##   subjects  -- body per column
##   pose      -- [event type, phase], -1 for a standing rig
##   postures  -- dig posture per column, empty for non-dig plates
##   faces     -- expression per column
##   yaws      -- facing per column, in degrees. Varied on purpose.
##   camera    -- position, rotation, fov
##   spacing   -- metres between columns
const PLATES: Array[Dictionary] = [
	{
		"name": "01_bodies_animal",
		"caption": "body",
		"subjects": ANIMAL_BODIES,
		"pose": [-1, 0.0],
		"faces": ["neutral", "deadpan", "happy", "suspicious", "devious"],
		"yaws": [-30.0, 18.0, -20.0, 36.0, -42.0],
		"camera": [Vector3(0.0, 1.66, -8.6), Vector3(-2.0, 180.0, 0.0), 30.0],
		"spacing": 1.86,
	},
	{
		"name": "01b_bodies_vegi",
		"caption": "body",
		"subjects": VEGI_BODIES,
		"pose": [-1, 0.0],
		"faces": ["neutral"],
		"yaws": [-24.0, 30.0, -14.0, 38.0, -34.0],
		"camera": [Vector3(0.0, 1.66, -9.8), Vector3(-2.0, 180.0, 0.0), 30.0],
		"spacing": 1.80,
	},
	{
		"name": "02_expressions_open",
		"caption": "face",
		"subjects": ["Pepper", "Pear", "Tomato"],
		"pose": [-1, 0.0],
		"faces": ["happy", "neutral", "worried"],
		"yaws": [-16.0, 0.0, 18.0],
		"camera": [Vector3(0.0, 1.70, -4.6), Vector3(-2.0, 180.0, 0.0), 30.0],
		"spacing": 1.70,
	},
	{
		"name": "03_expressions_narrowed",
		"caption": "face",
		"subjects": ["Pear", "Pepper", "Aubergine"],
		"pose": [-1, 0.0],
		"faces": ["devious", "suspicious", "cross"],
		"yaws": [14.0, 0.0, -20.0],
		"camera": [Vector3(0.0, 1.70, -4.6), Vector3(-2.0, 180.0, 0.0), 30.0],
		"spacing": 1.70,
	},
	{
		"name": "04_expressions_flat",
		"caption": "face",
		"subjects": ["Stalk", "Pepper", "Feli"],
		"pose": [-1, 0.0],
		"faces": ["relaxed", "deadpan", "tired"],
		"yaws": [-14.0, 0.0, 20.0],
		"camera": [Vector3(0.0, 1.70, -4.6), Vector3(-2.0, 180.0, 0.0), 30.0],
		"spacing": 1.70,
	},
	{
		"name": "05_serve",
		"caption": "serve",
		"subjects": ["Avi", "Feli", "Pepper"],
		"pose": [0, 0.45],
		"faces": ["neutral", "cross", "deadpan"],
		"yaws": [-34.0, 0.0, 30.0],
		"camera": [Vector3(0.0, 2.10, -7.0), Vector3(-5.0, 180.0, 0.0), 30.0],
		"spacing": 2.05,
	},
	{
		"name": "06_set",
		"caption": "set",
		"subjects": ["Pear", "Pepper", "Stalk"],
		"pose": [3, 0.5],
		"faces": ["neutral", "happy", "suspicious"],
		"yaws": [26.0, -8.0, -38.0],
		"camera": [Vector3(0.0, 2.14, -7.0), Vector3(-5.0, 180.0, 0.0), 30.0],
		"spacing": 2.05,
	},
	{
		"name": "07_attack",
		"caption": "attack",
		"subjects": ["Feli", "Aubergine", "Avi"],
		"pose": [4, 0.35],
		"faces": ["cross", "devious", "worried"],
		"yaws": [-30.0, 8.0, 36.0],
		"camera": [Vector3(0.0, 2.62, -7.6), Vector3(-6.0, 180.0, 0.0), 31.0],
		"spacing": 2.15,
	},
	{
		"name": "08_block",
		"caption": "block",
		"subjects": ["Avi", "Stalk", "Pepper"],
		"pose": [5, 0.55],
		"faces": ["cross", "deadpan", "suspicious"],
		"yaws": [-12.0, 4.0, 16.0],
		"camera": [Vector3(0.0, 2.66, -7.6), Vector3(-6.0, 180.0, 0.0), 31.0],
		"spacing": 2.15,
	},
	## Proportion, which is data rather than decoration: wingspan sets arm length
	## and stride sets leg length, and until now the second of those changed how
	## a voli *moved* without changing how they were *built*. Same body, same
	## height, three sets of limbs.
	{
		"name": "08b_proportions",
		"caption": "build",
		"subjects": ["Pear", "Pear", "Pear", "Cani", "Cani", "Cani"],
		"pose": [-1, 0.0],
		"faces": ["neutral"],
		"yaws": [-16.0, 0.0, 16.0, -16.0, 0.0, 16.0],
		"builds": [
			{"label": "short legs", "stride": 0.62, "wingspan": 191.0},
			{"label": "standard", "stride": 0.81, "wingspan": 191.0},
			{"label": "long legs", "stride": 1.02, "wingspan": 191.0},
			{"label": "short reach", "stride": 0.81, "wingspan": 176.0},
			{"label": "standard", "stride": 0.81, "wingspan": 191.0},
			{"label": "long reach", "stride": 0.81, "wingspan": 212.0},
		],
		"camera": [Vector3(0.0, 1.62, -10.4), Vector3(-2.0, 180.0, 0.0), 30.0],
		"spacing": 1.72,
	},
	{
		"name": "09_dig_postures",
		"caption": "posture",
		## No Avi here on purpose: its wing fans are the largest cosmetic in the
		## game and they hide exactly the twist this plate exists to show.
		"subjects": ["Pepper", "Feli", "Pear", "Aubergine"],
		"pose": [1, 0.0],
		"postures": ["planted", "moving", "reaching", "off-axis"],
		"faces": ["deadpan", "worried", "cross", "suspicious"],
		## Each posture is asymmetric in a different way, so each is turned to the
		## angle that shows its asymmetry -- the twist on off-axis and the stride
		## on moving are both invisible from dead front.
		"yaws": [-12.0, 32.0, 20.0, 44.0],
		"camera": [Vector3(0.0, 2.70, -7.0), Vector3(-14.0, 180.0, 0.0), 31.0],
		"spacing": 2.20,
	},
]


func _ready() -> void:
	await get_tree().process_frame
	for plate in PLATES:
		await _shoot(plate)
	get_tree().quit()


func _shoot(plate: Dictionary) -> void:
	var root := get_tree().root
	var stage := Node3D.new()
	root.add_child(stage)

	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-38.0, 154.0, 0.0)
	light.light_energy = 1.38
	stage.add_child(light)

	var fill := DirectionalLight3D.new()
	## A second, weak light from the other side. With one key light every subject
	## turned away from it fell into a flat silhouette, which defeats the point of
	## turning them in the first place.
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

	var view: Array = plate.camera
	var camera := Camera3D.new()
	camera.position = view[0]
	camera.rotation_degrees = view[1]
	camera.fov = float(view[2])
	stage.add_child(camera)

	var subjects: Array = plate.subjects
	var faces: Array = plate.get("faces", ["neutral"])
	var postures: Array = plate.get("postures", [])
	var yaws: Array = plate.get("yaws", [0.0])
	var pose: Array = plate.pose
	var spacing := float(plate.spacing)
	## The camera is turned around, so the row has to be laid out backwards for it
	## to photograph left to right in declaration order.
	var start := spacing * float(subjects.size() - 1) * 0.5
	for index in range(subjects.size()):
		var wanted := str(subjects[index])
		## Ask the model layer which names are body types rather than listing them
		## here. A hardcoded ["Feli", "Avi"] silently photographed Cani, Ursi and
		## Simi as vegetables the first time they existed -- the tool claimed to
		## show every body the game can draw while being the only thing that did
		## not know three of them had been drawn.
		var body_type := wanted if wanted in BodyTypeModelsScript.MODELLED \
			else "Vegi"
		var actor_id := index + 1
		if body_type == "Vegi":
			## Search for an id that hashes to this produce, so the portfolio runs
			## the same deterministic selection a match does rather than bypassing
			## it.
			for candidate in range(1, 6000):
				if BodyTypeModelsScript.produce_for(candidate) == wanted:
					actor_id = candidate
					break
		var actor: Node3D = ACTOR.instantiate()
		stage.add_child(actor)
		var caption := str(plate.caption)
		var label := body_type
		match caption:
			"face":
				label = str(faces[index % faces.size()])
			"posture":
				label = str(postures[index % postures.size()])
			"body":
				label = wanted if body_type == "Vegi" else body_type
			_:
				label = wanted if body_type == "Vegi" else body_type
		var builds: Array = plate.get("builds", [])
		var build: Dictionary = builds[index] if index < builds.size() else {}
		if not build.is_empty():
			label = str(build.get("label", label))
		actor.configure(
			actor_id, index % 2 == 0, label, "Right",
			{
				"height_cm": 188.0,
				"wingspan_cm": float(build.get("wingspan", 191.0)),
				"stride_length_m": float(build.get("stride", 0.81)),
				"body_type": body_type,
			},
		)
		actor.set_tactical_position(
			Vector2.ZERO, Vector3(start - spacing * float(index), 0.0, 0.0)
		)
		if not postures.is_empty():
			actor.contact_posture = str(postures[index % postures.size()])
		actor.set_pose(
			int(pose[0]), float(pose[1]), 0.5, Vector2.ZERO, int(pose[0]) >= 0
		)
		actor.set_expression(str(faces[index % faces.size()]))
		## Applied *after* the pose, because `set_pose` clears the body pivot and
		## a dig posture writes its own twist into it. This turns the whole actor
		## rather than its pivot, so the two never fight.
		actor.rotation.y = deg_to_rad(float(yaws[index % yaws.size()]))
		actor.has_facing = true
		actor.facing_yaw = actor.rotation.y
		## `configure` writes height and handedness into the label, which is the
		## right caption on court and pure noise in a portfolio plate.
		actor.identity_label.text = label
		actor.set_highlighted(true)

	for _frame in range(8):
		await get_tree().process_frame
	var path := "user://portfolio_%s.png" % str(plate.name)
	root.get_texture().get_image().save_png(path)
	print("saved %s" % ProjectSettings.globalize_path(path))
	stage.queue_free()
	await get_tree().process_frame
