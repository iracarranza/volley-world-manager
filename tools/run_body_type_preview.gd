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

## Every pose the rig can strike, not the three that happened to get captured.
##
## Serve, set and attack were never photographed at all, which meant three of the
## six things a voli does on court had no reference image and any judgement about
## them was being made from memory. The elbow lands hardest in exactly those
## three -- a cocked swing, a folded set -- so the gap and the feature met.
##
## The dig row exists because the four postures are the point of the knee.
## `_reception_pass_result` decides which one a contact was, so seeing them side
## by side is how you check the deep one actually reads as forced low rather
## than as a slightly shorter player.
##
## Attack and serve are shot mid-swing rather than at contact: the arm is
## straight at contact whatever the elbow does, so a contact-time frame is the
## one frame that cannot show whether the joint works.
const POSES: Array = [
	["stand", -1, 0.0],
	["serve", 0, 0.45],
	["set", 3, 0.5],
	["attack", 4, 0.35],
	["block", 5, 0.55],
	["dig", 1, 0.0],
]

## Where to stand to see the pose.
##
## A platform points *forward*, so from dead in front it is end-on and a dig
## photographs as two arms hanging at the sides -- which is what the first run of
## this row looked like, and it is a framing failure rather than a pose failure.
## The dig gets the elevated view a match is actually watched from, which is also
## the only angle where the four postures are distinguishable from each other.
## Raised and widened to clear a jumping attacker's hands. The row is framed for
## the *tallest thing in any pose*, not for a standing figure -- an attack lifts
## the actor 0.82 m and then puts an arm above that, and a framing fitted to a
## stand crops exactly the part the pose exists to show.
const DEFAULT_CAMERA := {
	"position": Vector3(0.0, 1.42, -8.4),
	"rotation": Vector3(0.0, 180.0, 0.0),
	"fov": 38.0,
}
const CAMERAS := {
	"dig": {
		"position": Vector3(0.0, 3.6, -7.0),
		"rotation": Vector3(-19.0, 180.0, 0.0),
		"fov": 40.0,
	},
}

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

	## Lit from the side the camera is on. This tool spent its whole life
	## photographing the backs of their heads -- the rig faces -Z and the camera
	## sat on +Z -- which was survivable while the subject was a silhouette and is
	## not once the subject is what the arms are doing.
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-40.0, 152.0, 0.0)
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
	var view: Dictionary = CAMERAS.get(str(pose[0]), DEFAULT_CAMERA)
	camera.position = view.get("position", DEFAULT_CAMERA.position)
	camera.rotation_degrees = view.get("rotation", DEFAULT_CAMERA.rotation)
	camera.fov = float(view.get("fov", DEFAULT_CAMERA.fov))
	stage.add_child(camera)

	var spacing := 1.12
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
		## Negated with the camera, so a turned-around view still reads left to
		## right in the order the subjects are declared.
		actor.set_tactical_position(
			Vector2.ZERO, Vector3(-start - spacing * float(index), 0.0, 0.0)
		)
		## `configure` writes a height and a handedness into the label, which is
		## the right caption on court and pure overlap in a row of eight. Say only
		## the thing the row is varying.
		actor.identity_label.text = label
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
