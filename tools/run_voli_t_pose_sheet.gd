extends Node

## Every voli body on one sheet, arms out, at a matched height.
##
## The reference plate this repo did not have: `run_body_type_preview.gd`
## photographs poses, so every shape is seen mid-action and no image shows the
## body itself. A T-pose is the neutral reading -- limb lengths, shoulder
## placement and torso profile with nothing an action is doing on top of them.
##
## Run:
##   xvfb-run -a godot --path . res://tools/voli_t_pose_sheet.tscn

const ACTOR := preload("res://scenes/components/player_actor_3d.tscn")
const BodyTypeModelsScript := preload("res://scripts/data/body_type_models.gd")
const BodyTypeGameplayScript := preload("res://scripts/domain/body_type_gameplay.gd")
const Stage := preload("res://tools/preview/voli_sheet_stage.gd")

## Matched, so what differs across the sheet is shape rather than scale.
const HEIGHT_CM := 188.0
const WINGSPAN_CM := 191.0

const COLUMNS := 5
## Wide enough that a fully extended arm clears its neighbour, which is a bigger
## number than a standing row needs -- see the span table this prints.
const SPACING := 2.55
## Rows are stacked in Y under an orthogonal camera, where a raised subject is
## drawn at the same size rather than a smaller one.
const ROW_RISE := 3.00

## What this sheet calls a produce, where that differs from what the world calls
## it. `PRODUCE` is the authority everywhere else and is not touched: this is a
## caption table for one plate, and the entry exists because "eggplant" is what
## the reader of this sheet calls the thing.
const SHEET_NAMES := {"Aubergine": "Eggplant"}


func _ready() -> void:
	## Fixed here rather than left to the run command, so the plate is the same
	## size every time it is regenerated.
	get_window().size = Stage.RESOLUTION
	await get_tree().process_frame
	var subjects := _subjects()
	var root := get_tree().root
	var stage := Stage.build_stage(root)

	var rows := int(ceil(float(subjects.size()) / float(COLUMNS)))
	var start := -SPACING * float(COLUMNS - 1) * 0.5
	for index in range(subjects.size()):
		var subject: Dictionary = subjects[index]
		var column := index % COLUMNS
		var row := index / COLUMNS
		var actor: Node3D = ACTOR.instantiate()
		stage.add_child(actor)
		actor.configure(
			int(subject.id), true, str(subject.label), "Right",
			{
				"height_cm": HEIGHT_CM, "wingspan_cm": WINGSPAN_CM,
				"body_type": str(subject.type),
			},
		)
		## Negated with the camera, so a turned-around view still reads left to
		## right in the order the subjects are declared.
		actor.set_tactical_position(
			Vector2.ZERO,
			Vector3(
				-start - SPACING * float(column),
				ROW_RISE * float(rows - 1 - row),
				0.0,
			),
		)
		actor.set_pose(-1, 0.0, 0.0, Vector2.ZERO, false)
		_t_pose(actor)
		Stage.present(actor, str(subject.label))

	for _frame in range(8):
		await get_tree().process_frame
	var spans := _report_spans(stage)
	Stage.frame_camera(
		root, stage,
		SPACING * float(COLUMNS - 1) + float(spans.widest) + 0.8,
		ROW_RISE * float(rows - 1) + 3.2,
		1.30 + ROW_RISE * float(rows - 1) * 0.5,
	)
	for _frame in range(4):
		await get_tree().process_frame
	Stage.save(root, "voli_t_pose_sheet")
	get_tree().quit()


## Vegi is one body type that grows in several shapes, so it is the one type
## that cannot be photographed by a single subject. Every other type is itself.
func _subjects() -> Array:
	var out: Array = []
	for type in BodyTypeGameplayScript.BODY_TYPES:
		if str(type) == "Vegi":
			continue
		out.append({"type": str(type), "label": str(type), "id": out.size() + 1})
	for produce in BodyTypeModelsScript.PRODUCE:
		out.append({
			"type": "Vegi",
			"label": "Vegi (%s)" % str(SHEET_NAMES.get(produce, produce)),
			## Searched rather than assigned, so the sheet runs through the same
			## deterministic selection a match does.
			"id": _id_growing(str(produce)),
		})
	return out


func _id_growing(produce: String) -> int:
	for candidate in range(1, 6000):
		if BodyTypeModelsScript.produce_for(candidate) == produce:
			return candidate
	return 1


## What the sheet is for: the reach a straight arm actually draws, against the
## wingspan the same voli was configured with. Printed rather than drawn -- the
## plate shows the shapes, and this is the number behind the one thing about
## them a picture cannot state.
func _report_spans(stage: Node3D) -> Dictionary:
	var widest := 0.0
	print("subject | drawn span m | wingspan m | ratio")
	for actor in stage.get_children():
		if not actor.has_method("set_pose"):
			continue
		var left: Vector3 = actor._hand_world_position(actor.left_arm)
		var right: Vector3 = actor._hand_world_position(actor.right_arm)
		var span := (left - right).length()
		var wingspan := float(actor.wingspan_cm) / 100.0
		widest = maxf(widest, span)
		print("%s | %.3f | %.3f | %.2f" % [
			actor.identity_label.text, span, wingspan, span / wingspan,
		])
	return {"widest": widest}


## Arms straight out, everything else neutral. Written here rather than as a
## pose on the actor: a T-pose is a reference attitude for looking at a body,
## not something a voli ever does on court.
func _t_pose(actor: Node3D) -> void:
	actor.body_pivot.rotation = Vector3.ZERO
	for side in [["LeftArm", -90.0], ["RightArm", 90.0]]:
		var arm := actor.body_pivot.get_node(str(side[0])) as Node3D
		arm.rotation_degrees = Vector3(0.0, 0.0, float(side[1]))
		var elbow := arm.get_node_or_null("Elbow") as Node3D
		if elbow != null:
			elbow.rotation_degrees = Vector3.ZERO
	for name in ["LeftLeg", "RightLeg"]:
		var leg := actor.body_pivot.get_node(str(name)) as Node3D
		leg.rotation_degrees = Vector3.ZERO
		var knee := leg.get_node_or_null("Knee") as Node3D
		if knee != null:
			knee.rotation_degrees = Vector3.ZERO
