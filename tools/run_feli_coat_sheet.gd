extends Node

## Every Feli colourway, each wearing a different coat.
##
## Colour and marking are drawn from two separate hashes precisely so they do
## not correlate, which means no roster ever lays them out against each other.
## This does: ten colourways along the sheet, the marking cycling underneath, so
## a palette is seen carrying more than one coat and a coat is seen on more than
## one palette.
##
## Run:
##   xvfb-run -a godot --path . res://tools/feli_coat_sheet.tscn

const ACTOR := preload("res://scenes/components/player_actor_3d.tscn")
const BodyTypeModelsScript := preload("res://scripts/data/body_type_models.gd")
const Stage := preload("res://tools/preview/voli_sheet_stage.gd")

const BODY := "Feli"
const HEIGHT_CM := 188.0

const COLUMNS := 5
const SPACING := 1.45
const ROW_RISE := 2.95


func _ready() -> void:
	get_window().size = Stage.RESOLUTION
	await get_tree().process_frame
	var root := get_tree().root
	var stage := Stage.build_stage(root)

	## Deduplicated by `marking_options`, which is the picker's view of
	## `MARKINGS`. The weighted table lists `none` twice and `tabby` twice; a
	## sheet wants each coat once.
	var coats := BodyTypeModelsScript.marking_options(BODY)
	var palettes := BodyTypeModelsScript.palette_count(BODY)
	print("%s: %d colourways, %d coats -- %s" % [
		BODY, palettes, coats.size(), ", ".join(coats),
	])

	var rows := int(ceil(float(palettes) / float(COLUMNS)))
	var start := -SPACING * float(COLUMNS - 1) * 0.5
	for index in range(palettes):
		var column := index % COLUMNS
		var row := index / COLUMNS
		var coat := str(coats[index % coats.size()])
		var actor: Node3D = ACTOR.instantiate()
		stage.add_child(actor)
		actor.configure(
			index + 1, true, BODY, "Right",
			{
				"height_cm": HEIGHT_CM, "wingspan_cm": 191.0,
				"body_type": BODY,
				## Chosen rather than hashed. `chosen_palette` and
				## `chosen_marking` are the same doors the character creator
				## uses, so nothing here reaches past the model to paint a voli
				## the world could not generate.
				"appearance": {"palette_index": index, "marking": coat},
			},
		)
		actor.set_tactical_position(
			Vector2.ZERO,
			Vector3(
				-start - SPACING * float(column),
				ROW_RISE * float(rows - 1 - row),
				0.0,
			),
		)
		actor.set_pose(-1, 0.0, 0.0, Vector2.ZERO, false)
		Stage.present(actor, "%02d · %s" % [index + 1, coat])

	for _frame in range(8):
		await get_tree().process_frame
	Stage.frame_camera(
		root, stage,
		SPACING * float(COLUMNS - 1) + 2.0,
		ROW_RISE * float(rows - 1) + 4.0,
		1.25 + ROW_RISE * float(rows - 1) * 0.5,
	)
	for _frame in range(4):
		await get_tree().process_frame
	Stage.save(root, "feli_coat_sheet")
	get_tree().quit()
