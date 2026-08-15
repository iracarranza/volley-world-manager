extends Node

## The career builder, as pictures and as a check that the picker reaches the rig.
##
##     xvfb-run -a godot --path . res://tools/character_creation_shot.tscn
##
## Two questions, and the second is the one worth the harness. A screenshot says
## whether the layout holds; it cannot say whether *choosing* a colourway changed
## the body, because two reds an hour apart look the same in two files. So the
## silhouette is read back out of the rig after each choice and compared against
## the choice that was made -- the same argument `run_set_posture_shot` makes
## about postures, for the same reason: a picker whose value never arrives and a
## picker that works look identical in a still.
const SCREEN := preload("res://scenes/screens/new_career_screen.tscn")
const BodyTypesScript := preload("res://scripts/data/body_type_models.gd")

## Four bodies that differ on every axis at once, so a shot that shows one of
## them showing through would be obvious.
const LOOKS := [
	{"body_type": "Vegi", "produce": "Tomato", "palette_index": 0,
		"marking": "none", "expression": "neutral", "height_cm": 186.0},
	{"body_type": "Feli", "produce": "Tomato", "palette_index": 2,
		"marking": "tabby", "expression": "devious", "height_cm": 172.0},
	{"body_type": "Avi", "produce": "Tomato", "palette_index": 1,
		"marking": "speckle", "expression": "happy", "height_cm": 204.0},
	{"body_type": "Ursi", "produce": "Tomato", "palette_index": 3,
		"marking": "blaze", "expression": "tired", "height_cm": 219.0},
]


func _ready() -> void:
	await get_tree().process_frame
	var screen: Control = SCREEN.instantiate()
	screen.theme = load("res://scenes/themes/dark_theme.tres")
	screen.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(screen)
	for _frame in range(4):
		await get_tree().process_frame

	print("=== does a chosen body reach the rig?")
	print("%-8s %-9s %-8s %-9s %8s %8s  %s" % [
		"body", "marking", "face", "skin", "height", "drawn", "verdict",
	])
	var signatures := {}
	for index in range(LOOKS.size()):
		var look: Dictionary = LOOKS[index]
		screen.appearance = ManagerProfile.sanitise_appearance(look)
		screen._sync_voli_controls()
		screen._refresh_preview()
		for _frame in range(3):
			await get_tree().process_frame
		var actor: Node3D = screen._preview_actor
		var skin: Color = actor.silhouette.get("skin", Color.BLACK)
		## The height the rig actually drew, recovered from the scale it chose,
		## rather than the height it was handed. A profile that never arrives
		## leaves the previous body standing there at the previous size.
		var drawn := float(actor.body_height_scale) * float(
			actor.silhouette.get("rig_height", 1.88)
		) * 100.0
		## **Counted against the same body wearing nothing**, not by inspecting a
		## key on each part. The first version filtered `extras` on
		## `color_key == "literal"` and got zero for every coat -- the key is not
		## on the part -- so a working picker reported as broken. A count is only
		## a measurement next to the count it is being compared with.
		var plain: int = Array(BodyTypesScript.silhouette(
			str(look.body_type), 0, {"marking": "none"}
		).get("extras", [])).size()
		var marks: int = Array(
			actor.silhouette.get("extras", [])
		).size() - plain
		var expected_marks := str(look.marking) != "none"
		var honest := absf(drawn - float(look.height_cm)) < 1.0 \
			and str(actor.body_type) == str(look.body_type) \
			and str(actor.expression) == str(look.expression) \
			and (marks > 0) == expected_marks
		print("%-8s %-9s %-8s %-9s %8.0f %8.0f  %s" % [
			str(actor.body_type), str(look.marking), str(actor.expression),
			skin.to_html(false), float(look.height_cm), drawn,
			"drawn" if honest else "NOT REACHED",
		])
		signatures["%d" % index] = "%s|%s|%s|%.1f|%d" % [
			str(actor.body_type), str(actor.expression), skin.to_html(false),
			drawn, marks,
		]
		await _capture(screen, "career_you_%d" % index)

	var keys: Array = signatures.keys()
	var identical := 0
	for first in range(keys.size()):
		for second in range(first + 1, keys.size()):
			identical += int(signatures[keys[first]] == signatures[keys[second]])
	print("--- %d identical bodies (want 0)" % identical)

	## And the region step, both tiers, because the whole point of splitting the
	## question is that the second page differs by more than a badge.
	print("")
	print("=== the tier decides the page")
	screen.current_step = 2
	screen._show_step()
	for tier in [VolleyballRegions.TIER_MAJOR, VolleyballRegions.TIER_MINOR]:
		screen._select_tier(tier)
		for _frame in range(3):
			await get_tree().process_frame
		var listed: Array[String] = []
		for child in screen.region_grid.get_children():
			listed.append(str(child.get_meta("value", "")))
		print("%-6s %d regions: %s" % [
			str(tier), listed.size(), ", ".join(listed),
		])
		await _capture(screen, "career_origin_%s" % str(tier))

	## And the whole way through, because every check above is about the screen
	## and none of them is about the save. A picker that reaches the rig and not
	## the career is a character creator that forgets you the moment you press
	## Continue.
	print("")
	print("=== the body reaches the save")
	screen.appearance = ManagerProfile.sanitise_appearance(LOOKS[2])
	screen.manager_name = "Probe"
	screen.career_name_edit.text = "Creation Probe"
	screen.organization_name_edit.text = "Probe VC"
	screen._create_career()
	var career: Resource = get_node("/root/CareerManager").career
	if career == null:
		print("  no career was created: %s" % screen.error_label.text)
	else:
		var stored: Dictionary = career.manager_appearance
		print("  manager %s of %s, %s %s, %s face, %.0f cm -- %s" % [
			str(career.manager_name), str(career.manager_region),
			str(stored.get("body_type", "?")), str(stored.get("marking", "?")),
			str(stored.get("expression", "?")),
			float(stored.get("height_cm", 0.0)),
			"stored" if str(stored.get("body_type", "")) == str(LOOKS[2].body_type)
				and str(career.manager_name) == "Probe" else "NOT STORED",
		])
	get_tree().quit()


func _capture(screen: Control, shot_name: String) -> void:
	for _frame in range(3):
		await get_tree().process_frame
	var path := "user://%s.png" % shot_name
	get_viewport().get_texture().get_image().save_png(path)
	print("  saved %s" % ProjectSettings.globalize_path(path))
