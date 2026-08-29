extends SceneTree

## In-engine UI drafts for the creation-flow seam. The first image is the live
## NewCareerScreen scene (and therefore exercises its real PlayerActor3D preview).
## The later two are deliberately draft-only review/session screens: they test
## hierarchy, density and copy without pretending the underlying flow is wired.

const OUTPUT_DIR := "res://artifacts/creation-flow-drafts"
const SIZE := Vector2i(1280, 720)
const DARK_THEME := preload("res://scenes/themes/dark_theme.tres")
const CAREER_SCENE := preload("res://scenes/screens/new_career_screen.tscn")
const ACTOR_SCENE := preload("res://scenes/components/player_actor_3d.tscn")

const BG := Color("071421")
const SURFACE := Color("0d2134")
const RAISED := Color("122b42")
const INK := Color("e7edf2")
const MUTED := Color("8fa1b6")
const ACCENT := Color("e2bd45")
const STROKE := Color("34506a")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	root.size = SIZE
	await _render_live_you()
	await _render_signature()
	await _render_save_setup()
	print("Rendered creation-flow drafts to %s" % OUTPUT_DIR)
	quit()


func _clear_root() -> void:
	for child in root.get_children():
		child.queue_free()
	await process_frame
	await process_frame


func _render_live_you() -> void:
	await _clear_root()
	var screen := CAREER_SCENE.instantiate()
	root.add_child(screen)
	await process_frame
	await process_frame
	## Give the live screen an explicit, factual 01 prompt. This is a render-only
	## copy override; implementation copy remains owned by the screen script.
	var title := screen.get_node_or_null("%QuestionTitle") as Label
	var hint := screen.get_node_or_null("%QuestionHint") as Label
	if title != null:
		title.text = "Who are you?"
	if hint != null:
		hint.text = "Choose how you look. Drag the voli to turn them. Appearance is visual only."
	await process_frame
	await RenderingServer.frame_post_draw
	_save("01_you.png")


func _base_screen(section: String, title_text: String, hint_text: String) -> Dictionary:
	var canvas := Control.new()
	canvas.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	canvas.theme = DARK_THEME
	root.add_child(canvas)

	var bg := ColorRect.new()
	bg.color = BG
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	canvas.add_child(bg)

	var rail := ColorRect.new()
	rail.color = Color("06101c")
	rail.position = Vector2.ZERO
	rail.size = Vector2(250, 720)
	canvas.add_child(rail)

	var brand := _label("VWM / CAREER BUILDER", 13, ACCENT)
	brand.position = Vector2(32, 40)
	rail.add_child(brand)
	var rail_title := _label("You're the\ncoach now!", 27, INK)
	rail_title.position = Vector2(32, 78)
	rail.add_child(rail_title)

	var steps := ["01  YOU", "02  VOLLEYBALL", "03  PLACE", "04  CLUB", "05  MANAGEMENT", "06  SIGNATURE"]
	var y := 184.0
	for step in steps:
		var active := step.begins_with(section)
		var line := _label(step, 14, ACCENT if active else MUTED)
		line.position = Vector2(34, y)
		line.size = Vector2(180, 28)
		rail.add_child(line)
		y += 42.0

	var kicker := _label("%s / 06" % section, 13, ACCENT)
	kicker.position = Vector2(292, 34)
	canvas.add_child(kicker)
	var title := _label(title_text, 31, INK)
	title.position = Vector2(292, 67)
	title.size = Vector2(900, 44)
	canvas.add_child(title)
	var hint := _label(hint_text, 14, MUTED)
	hint.position = Vector2(292, 115)
	hint.size = Vector2(870, 44)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	canvas.add_child(hint)

	var panel := PanelContainer.new()
	panel.position = Vector2(292, 171)
	panel.size = Vector2(946, 474)
	panel.add_theme_stylebox_override("panel", _box(SURFACE, STROKE, 1, 10))
	canvas.add_child(panel)
	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_%s" % side, 22)
	panel.add_child(margin)
	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 12)
	margin.add_child(body)

	var back := Button.new()
	back.text = "Previous"
	back.position = Vector2(292, 660)
	back.size = Vector2(140, 42)
	canvas.add_child(back)
	return {"canvas": canvas, "body": body}


func _render_signature() -> void:
	await _clear_root()
	var screen := _base_screen("06", "Ready to begin?", "Review what you chose. Nothing here adds a new philosophy question.")
	var body := screen.body as VBoxContainer

	var split := HBoxContainer.new()
	split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	split.add_theme_constant_override("separation", 20)
	body.add_child(split)

	var identity := VBoxContainer.new()
	identity.custom_minimum_size = Vector2(330, 0)
	identity.add_theme_constant_override("separation", 9)
	split.add_child(identity)
	identity.add_child(_label("IRA CARRANZA", 26, INK))
	identity.add_child(_label("Founder / Manager", 14, MUTED))
	identity.add_child(_rule())
	identity.add_child(_fact("HOME", "Bompaçao"))
	identity.add_child(_fact("WORK", "Spëddigh"))
	identity.add_child(_fact("CLUB", "Vål Nyr VC"))
	identity.add_child(_rule())
	identity.add_child(_label("CLUB IDENTITY", 12, ACCENT))
	var crest := PanelContainer.new()
	crest.custom_minimum_size = Vector2(0, 110)
	crest.add_theme_stylebox_override("panel", _box(RAISED, STROKE, 1, 7))
	identity.add_child(crest)
	var crest_label := _label("VÅL NYR VC\ncrest + home / change kits", 17, INK)
	crest_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	crest_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	crest.add_child(crest_label)

	var profile := VBoxContainer.new()
	profile.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	profile.add_theme_constant_override("separation", 8)
	split.add_child(profile)
	profile.add_child(_label("STARTING PROFILE", 12, ACCENT))
	profile.add_child(_profile_block("BACKGROUND", ["Former analyst", "Known"]))
	profile.add_child(_profile_block("VOLLEYBALL", ["Quick attacks · Target reception · Read the attack", "Attack in transition · Use what's available · Combination offense"]))
	profile.add_child(_profile_block("MANAGEMENT", ["Structure        Guided", "Squad building   Specialist-leaning", "Responsibility   Shared"]))

	var edits := HBoxContainer.new()
	edits.add_theme_constant_override("separation", 7)
	for text in ["Edit YOU", "Edit VOLLEYBALL", "Edit PLACE", "Edit CLUB", "Edit MANAGEMENT"]:
		var button := Button.new()
		button.text = text
		edits.add_child(button)
	profile.add_child(edits)

	var start := Button.new()
	start.text = "I'm ready to begin."
	start.custom_minimum_size = Vector2(220, 46)
	start.size_flags_horizontal = Control.SIZE_SHRINK_END
	body.add_child(start)
	await process_frame
	await RenderingServer.frame_post_draw
	_save("06_signature.png")


func _render_save_setup() -> void:
	await _clear_root()
	var canvas := Control.new()
	canvas.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	canvas.theme = DARK_THEME
	root.add_child(canvas)
	var bg := ColorRect.new()
	bg.color = BG
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	canvas.add_child(bg)

	var kicker := _label("SAVE SETUP", 13, ACCENT)
	kicker.position = Vector2(84, 62)
	canvas.add_child(kicker)
	var title := _label("Before the first day", 34, INK)
	title.position = Vector2(84, 91)
	canvas.add_child(title)
	var hint := _label("Session settings only. Your manager, club and starting circumstances are already set.", 15, MUTED)
	hint.position = Vector2(84, 140)
	hint.size = Vector2(900, 34)
	canvas.add_child(hint)

	var panel := PanelContainer.new()
	panel.position = Vector2(84, 194)
	panel.size = Vector2(1112, 398)
	panel.add_theme_stylebox_override("panel", _box(SURFACE, STROKE, 1, 10))
	canvas.add_child(panel)
	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_%s" % side, 26)
	panel.add_child(margin)
	var rows := VBoxContainer.new()
	rows.add_theme_constant_override("separation", 16)
	margin.add_child(rows)
	rows.add_child(_setting_row("Save name", "Ira Carranza · Vål Nyr VC · 2026", "Editable; generated automatically"))
	rows.add_child(_setting_row("World variation", "Canonical world + seeded variation", "Same institutions; reproducible variation"))
	rows.add_child(_setting_row("Seed", "482901", "Advanced · optional"))
	rows.add_child(_setting_row("Autosave", "Every week", "Session preference"))
	rows.add_child(_setting_row("Match default", "Watch key moments", "Can be changed later"))

	var note := _label("No Easy / Normal / Hard selector. Starting difficulty already comes from standing, job access, club condition and founding resources.", 13, MUTED)
	note.position = Vector2(84, 610)
	note.size = Vector2(870, 40)
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	canvas.add_child(note)
	var start := Button.new()
	start.text = "Enter Day 1"
	start.position = Vector2(1014, 632)
	start.size = Vector2(182, 46)
	canvas.add_child(start)
	await process_frame
	await RenderingServer.frame_post_draw
	_save("save_setup.png")


func _setting_row(name_text: String, value_text: String, note_text: String) -> Control:
	var row := HBoxContainer.new()
	row.custom_minimum_size = Vector2(0, 52)
	row.add_theme_constant_override("separation", 18)
	var name := _label(name_text, 14, INK)
	name.custom_minimum_size = Vector2(180, 0)
	row.add_child(name)
	var value := Button.new()
	value.text = value_text
	value.alignment = HORIZONTAL_ALIGNMENT_LEFT
	value.custom_minimum_size = Vector2(430, 42)
	row.add_child(value)
	var note := _label(note_text, 13, MUTED)
	note.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	note.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(note)
	return row


func _profile_block(title_text: String, lines: Array[String]) -> Control:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _box(RAISED, Color(0, 0, 0, 0), 0, 6))
	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_%s" % side, 12)
	panel.add_child(margin)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	margin.add_child(box)
	box.add_child(_label(title_text, 11, ACCENT))
	for line in lines:
		box.add_child(_label(line, 14, INK))
	return panel


func _fact(name_text: String, value_text: String) -> Control:
	var row := HBoxContainer.new()
	var name := _label(name_text, 11, MUTED)
	name.custom_minimum_size = Vector2(70, 24)
	row.add_child(name)
	var value := _label(value_text, 15, INK)
	row.add_child(value)
	return row


func _rule() -> HSeparator:
	var rule := HSeparator.new()
	rule.custom_minimum_size = Vector2(0, 8)
	return rule


func _label(text_value: String, size_value: int, colour: Color) -> Label:
	var label := Label.new()
	label.text = text_value
	label.add_theme_font_size_override("font_size", size_value)
	label.add_theme_color_override("font_color", colour)
	return label


func _box(fill: Color, border: Color, width: int, radius: int) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = fill
	box.border_color = border
	box.set_border_width_all(width)
	box.set_corner_radius_all(radius)
	return box


func _save(file_name: String) -> void:
	var image := root.get_texture().get_image()
	var path := "%s/%s" % [OUTPUT_DIR, file_name]
	var err := image.save_png(path)
	if err != OK:
		push_error("Could not save %s: %s" % [path, error_string(err)])
		quit(1)
