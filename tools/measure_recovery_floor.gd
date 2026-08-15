extends Node3D

## How far each recovery state sinks its subject through the floor.
##
## Tuning drops by eye off a portfolio plate means reading a 1280px render of a
## floor ellipse against a shoe, and I got it wrong twice that way. This asks the
## geometry instead: build the actor, apply the state, then walk every visual and
## take the lowest corner of its global AABB. Zero is standing on the court; a
## negative number is how far underground the pose currently is, and a large
## positive number on a fallen state means it is hovering.

const ACTOR := preload("res://scenes/components/player_actor_3d.tscn")
const BodyTypeModelsScript := preload("res://scripts/data/body_type_models.gd")

## The 09b plate's own cast, so the numbers describe the picture being tuned.
const SUBJECTS: Array[String] = ["Pear", "Cani", "Pepper", "Ursi"]
const STATES: Array[String] = ["platform", "knee", "fall", "blown_away"]
const POSTURES: Array[String] = ["planted", "moving", "off-axis", "planted"]


func _ready() -> void:
	print("state        " + "  ".join(SUBJECTS))
	for state_index in STATES.size():
		var line := "%-11s" % STATES[state_index]
		for index in SUBJECTS.size():
			var actor: Node3D = ACTOR.instantiate()
			add_child(actor)
			var wanted := SUBJECTS[index]
			var body_type := wanted if wanted in BodyTypeModelsScript.MODELLED \
				else "Vegi"
			var actor_id := index + 1
			if body_type == "Vegi":
				for candidate in range(1, 6000):
					if BodyTypeModelsScript.produce_for(candidate) == wanted:
						actor_id = candidate
						break
			actor.configure(
				actor_id, index % 2 == 0, wanted, "Right",
				{
					"height_cm": 188.0,
					"wingspan_cm": 191.0,
					"stride_length_m": 0.81,
					"body_type": body_type,
				},
			)
			actor.contact_posture = POSTURES[state_index]
			actor.contact_recovery = STATES[state_index]
			actor.set_pose(1, 0.0, 0.0, Vector2.ZERO, true)
			await get_tree().process_frame
			var lowest := _lowest_with_name(actor)
			line += "  %6.3f (%s)" % [lowest, _lowest_name]
			actor.queue_free()
		print(line)
	get_tree().quit()


## Which part reached lowest, so a bad number says *what* is underground rather
## than only that something is. Guessing that from a render is how a shoe gets
## blamed for a hip.
var _lowest_name: String = ""


func _lowest_point(node: Node) -> float:
	var lowest := 1000.0
	if node is VisualInstance3D and (node as VisualInstance3D).visible:
		var visual := node as VisualInstance3D
		## Labels and the floor markers are not the body, and the focus ring sits
		## at the floor by definition -- including them would measure nothing.
		if not (visual is Label3D) and visual.name not in ["Shadow", "FocusRing"]:
			var box := visual.get_aabb()
			var placement := visual.global_transform
			for corner in 8:
				var corner_y := (placement * box.get_endpoint(corner)).y
				if corner_y < lowest:
					lowest = corner_y
					_lowest_name = str(visual.get_parent().name) + "/" + str(visual.name)
	for child in node.get_children():
		lowest = minf(lowest, _lowest_point(child))
	return lowest


## Walks the tree against one running minimum, so the recorded name belongs to
## the part that actually reached lowest. The obvious recursive version -- each
## call starting its own minimum and folding with `minf` -- reports whichever
## node was merely visited last, which named the neck as the lowest point on a
## standing player.
func _lowest_with_name(node: Node) -> float:
	_lowest_name = ""
	var lowest := 1000.0
	var pending: Array[Node] = [node]
	while not pending.is_empty():
		var current: Node = pending.pop_back()
		for child in current.get_children():
			pending.append(child)
		if not (current is VisualInstance3D):
			continue
		var visual := current as VisualInstance3D
		if not visual.visible or visual is Label3D \
				or visual.name in ["Shadow", "FocusRing"]:
			continue
		var box := visual.get_aabb()
		var placement := visual.global_transform
		for corner in 8:
			var corner_y := (placement * box.get_endpoint(corner)).y
			if corner_y < lowest:
				lowest = corner_y
				_lowest_name = "%s/%s" % [visual.get_parent().name, visual.name]
	return lowest
