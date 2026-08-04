extends Node

## Line the body types up and photograph them.
##
## A silhouette is a claim about what reads at a glance, and that claim can only
## be checked by looking. Renders the three modelled types plus every Vegi
## produce at a matched height, so what differs between them is shape rather
## than scale.
##
## Run:
##   xvfb-run -a godot --path . res://tools/body_type_preview.tscn

const ACTOR := preload("res://scenes/components/player_actor_3d.tscn")
const BodyTypeModelsScript := preload("res://scripts/data/body_type_models.gd")

## Body type and, for a Vegi, which produce. Named rather than given ids: the id
## that grows a pumpkin is a property of the hash, not something worth
## hand-maintaining here.
const SUBJECTS: Array = [
	["Feli", ""], ["Avi", ""],
	["Vegi", "Tomato"], ["Vegi", "Aubergine"], ["Vegi", "Pumpkin"],
	["Vegi", "Pear"], ["Vegi", "Turnip"], ["Vegi", "Stalk"],
]

## The dig row exists because the four postures are the point of the knee.
## `_reception_pass_result` decides which one a contact was, so seeing them side
## by side is how you check the deep one actually reads as forced low rather
## than as a slightly shorter player.
const POSES: Array = [
	["stand", -1, 0.0],
	["block", 5, 0.55],
	["dig", 1, 0.0],
]

## Cycled across the row on the dig pose so every stance is on screen at once.
const DIG_POSTURES: Array[String] = [
	"planted", "moving", "reaching", "off-axis",
]

var _subjects: Array = []


func _ready() -> void:
	## Resolved into a local array because `SUBJECTS` is a const, and a const
	## collection is read-only in Godot 4 -- writing a resolved id back into it
	## raises an error per attempt instead of storing anything.
	for index in range(SUBJECTS.size()):
		var entry: Array = SUBJECTS[index]
		var wanted := str(entry[1])
		var subject := {"type": str(entry[0]), "produce": wanted, "id": index + 1}
		if not wanted.is_empty():
			## Search for an id that hashes to this produce, so the preview runs
			## through the same deterministic selection a match does rather than
			## bypassing it.
			for candidate in range(1, 6000):
				if BodyTypeModelsScript.produce_for(candidate) == wanted:
					subject["id"] = candidate
					break
		_subjects.append(subject)
	await get_tree().process_frame
	for pose in POSES:
		await _shoot(pose)
	get_tree().quit()


func _shoot(pose: Array) -> void:
	var root := get_tree().root
	var stage := Node3D.new()
	root.add_child(stage)

	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-42.0, -34.0, 0.0)
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
	## Pulled back and widened when the sixth Vegi shape arrived -- the framing
	## was fitted to seven subjects and silently cropped the eighth rather than
	## failing, which is the kind of thing a preview tool must not do.
	camera.position = Vector3(0.0, 1.15, 8.4)
	camera.fov = 50.0
	stage.add_child(camera)

	var spacing := 1.25
	var start := -spacing * float(_subjects.size() - 1) * 0.5
	for index in range(_subjects.size()):
		var subject: Dictionary = _subjects[index]
		## The body type, never the produce. A Vegi is a Vegi -- the produce is
		## how the variety is generated, not a name the player is known by, and
		## printing it here was the one place in the game that turned a body into
		## a species. Six rows all reading "Vegi" is the point: they are one type
		## that grows in different shapes.
		var label := str(subject.type)
		var actor: Node3D = ACTOR.instantiate()
		stage.add_child(actor)
		actor.configure(
			int(subject.id), index % 2 == 0, label, "Right",
			{
				"height_cm": 188.0, "wingspan_cm": 191.0,
				"body_type": str(subject.type),
			},
		)
		actor.set_tactical_position(
			Vector2.ZERO, Vector3(start + spacing * float(index), 0.0, 0.0)
		)
		if str(pose[0]) == "dig":
			actor.contact_posture = DIG_POSTURES[index % DIG_POSTURES.size()]
			actor.identity_label.text = "%s · %s" % [
				str(subject.type), actor.contact_posture,
			]
		actor.set_pose(
			int(pose[1]), float(pose[2]), 0.5, Vector2.ZERO, int(pose[1]) >= 0
		)
		actor.set_highlighted(true)

	for _frame in range(8):
		await get_tree().process_frame
	var path := "user://body_types_%s.png" % str(pose[0])
	root.get_texture().get_image().save_png(path)
	print("saved %s" % ProjectSettings.globalize_path(path))
	stage.queue_free()
	await get_tree().process_frame
