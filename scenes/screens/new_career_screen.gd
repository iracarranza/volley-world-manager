class_name VolleyballNewCareerScreen
extends Control

signal career_created
signal back_requested

const CareerManagerScript := preload("res://scripts/managers/career_manager.gd")
const TeamPrinciplesModel := preload("res://scripts/models/team_principles.gd")
const UIPalette := preload("res://scripts/data/ui_palette.gd")
const PlayerActorScene := preload("res://scenes/components/player_actor_3d.tscn")
const BodyTypesScript := preload("res://scripts/data/body_type_models.gd")
const FaceExpressionsScript := preload("res://scripts/data/face_expressions.gd")

## **You exist before the club does.**
##
## The builder opened on a region and closed on two text fields, which is a form
## about an organisation with a person implied somewhere behind it. The first
## question is now who you are -- a voli, drawn with the same rig that draws
## everybody else, because there is no second character pipeline and never was a
## reason to build one.
##
## Philosophy comes second, before the region rather than after it. That reads
## oddly until you notice what it does to the third step: choosing a region *after*
## stating what you believe makes the alignment number a consequence you walk
## into rather than a default you were handed. `identity_tracks_region` already
## re-seeds the principles when a region is chosen and nothing has been departed
## from, so the tradition shortcut still works from either direction.
const STEPS := [
	"01  YOU", "02  PHILOSOPHY", "03  ORIGIN", "04  FOUNDATION", "05  SIGNATURE",
]
const AXIS_QUESTIONS := [
	{"key": "decisiveness", "question": "How should rallies be won?", "low": "Outlast", "middle": "Adapt", "high": "Finish"},
	{"key": "pin_focus", "question": "Where should attack volume live?", "low": "Middles", "middle": "Spread", "high": "Pins"},
	{"key": "tempo_variation", "question": "How should tempo behave?", "low": "Repeatable", "middle": "Responsive", "high": "Variable"},
	{"key": "emotional_expression", "question": "What drives the group?", "low": "Discipline", "middle": "Composure", "high": "Emotion"},
	{"key": "serve_aggression", "question": "What should serving demand?", "low": "Control", "middle": "Pressure", "high": "Damage"},
	{"key": "transition_commitment", "question": "What follows a defensive touch?", "low": "Reset", "middle": "Read", "high": "Go Again"},
	{"key": "block_commitment", "question": "Where should defense commit?", "low": "Floor", "middle": "Read", "high": "Net"},
]

## What each body type is, in the two or three words a picker has room for. The
## bodies are drawn beside these, so the line names the thing the silhouette
## cannot say rather than describing the silhouette.
const BODY_BLURBS := {
	"Vegi": "grown",
	"Feli": "ears up",
	"Avi": "beak",
	"Cani": "ears down",
	"Ursi": "round",
	"Simi": "long arms",
}

## How far the preview swings either side of square, and how long a swing takes.
##
## A swing rather than a turntable, because a full rotation spends half its time
## showing the back of a head. Half of what a body type says is in its profile --
## an Avi's crest, a produce torso's whole shape -- and none of it is behind
## them, so the body turns far enough to show a three-quarter view and comes
## back. The face, which is the axis with nine settings, stays visible
## throughout.
const PREVIEW_SWING_DEGREES: float = 34.0
const PREVIEW_SWING_SECONDS: float = 7.0
const PREVIEW_FRONT_YAW_DEGREES: float = 180.0

@onready var CareerManager: CareerManagerScript = get_node("/root/CareerManager")
@onready var step_rail: VBoxContainer = %StepRail
@onready var step_kicker: Label = %StepKicker
@onready var question_title: Label = %QuestionTitle
@onready var question_hint: Label = %QuestionHint
@onready var region_grid: GridContainer = %RegionGrid
@onready var tier_row: HBoxContainer = %TierRow
@onready var tier_hint: Label = %TierHint
@onready var type_row: HBoxContainer = %TypeRow
@onready var preset_option: OptionButton = %PresetOption
@onready var identity_name_edit: LineEdit = %IdentityNameEdit
@onready var identity_tag_grid: GridContainer = %IdentityTagGrid
@onready var career_name_edit: LineEdit = %CareerNameEdit
@onready var organization_name_edit: LineEdit = %OrganizationNameEdit
@onready var review_text: RichTextLabel = %ReviewText
@onready var error_label: Label = %ErrorLabel
@onready var previous_button: Button = %PreviousButton
@onready var next_button: Button = %NextButton
@onready var voli_controls: VBoxContainer = %VoliControls
@onready var preview_viewport: SubViewport = %PreviewViewport

var current_step := 0
var selected_region := "Landavol"
var selected_tier: StringName = VolleyballRegions.TIER_MAJOR
var selected_type := "Established"
var selected_values: Dictionary = {}
var identity_tracks_region := true
var light_mode_enabled := false
var step_panels: Array[Control] = []
var step_labels: Array[Label] = []
var tag_buttons: Dictionary = {}

## The manager's own body, in the shape `ManagerProfile.sanitise_appearance`
## bounds. Held as a plain dictionary rather than as a dozen ivars because it
## travels as one -- to the preview, to `create_career`, into the save.
var appearance: Dictionary = ManagerProfile.DEFAULT_APPEARANCE.duplicate(true)
var manager_name := ""
## Whether the name field is still showing the region's suggestion. A player who
## has typed their own name keeps it when they change region; one who has not
## gets a name from wherever they just said they were from.
var manager_name_tracks_region := true

var _preview_actor: Node3D
var _preview_pivot: Node3D
var _preview_clock: float = 0.0
var _palette_row: HBoxContainer
var _produce_row: HBoxContainer
var _produce_line: Control
var _body_row: GridContainer
var _hand_row: HBoxContainer
var _marking_row: HBoxContainer
var _face_option: OptionButton
var _manager_name_edit: LineEdit
var _slider_labels: Dictionary = {}


func _ready() -> void:
	step_panels = [
		%VoliStep, %IdentityStep, %RegionStep, %TypeStep, %NamesStep,
	]
	_build_step_rail()
	_build_voli_choices()
	_build_tier_choices()
	_build_region_choices()
	_build_type_choices()
	_build_identity_choices()
	previous_button.pressed.connect(_previous)
	next_button.pressed.connect(_next)
	%CancelButton.pressed.connect(func() -> void: back_requested.emit())
	reset_form()


func _process(delta: float) -> void:
	## Only while it is on screen. A viewport told to update always is a viewport
	## rendering a rig behind four other panels for the rest of the flow.
	if _preview_pivot == null or not step_panels[0].visible:
		return
	_preview_clock = fmod(_preview_clock + delta, PREVIEW_SWING_SECONDS)
	_preview_pivot.rotation_degrees.y = PREVIEW_FRONT_YAW_DEGREES \
		+ PREVIEW_SWING_DEGREES * sin(
		TAU * _preview_clock / PREVIEW_SWING_SECONDS
	)


func reset_form() -> void:
	current_step = 0
	error_label.text = ""
	selected_region = "Landavol"
	selected_tier = VolleyballRegions.tier_of(selected_region)
	selected_type = "Established"
	identity_tracks_region = true
	manager_name_tracks_region = true
	appearance = ManagerProfile.DEFAULT_APPEARANCE.duplicate(true)
	_set_principles(VolleyballRegions.preferred_principles(selected_region), true)
	_select_button_with_metadata(tier_row, str(selected_tier))
	_fill_region_grid()
	_select_button_with_metadata(type_row, selected_type)
	preset_option.select(0)
	_suggest_manager_name()
	_sync_voli_controls()
	_refresh_preview()
	_show_step()


func _build_step_rail() -> void:
	for child in step_rail.get_children():
		child.queue_free()
	step_labels.clear()
	for step_name in STEPS:
		var label := Label.new()
		label.text = step_name
		label.custom_minimum_size = Vector2(170, 38)
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.add_theme_font_size_override("font_size", 14)
		step_rail.add_child(label)
		step_labels.append(label)


## ## The voli you are
##
## Every axis here already existed and was a hash of a player id: the body type,
## the produce a Vegi grows as, the colourway, the coat, the face. That is right
## for the forty volis the world generates and wrong for the one the player is,
## so the picker's whole job is to name what the hash was choosing anyway.
##
## Height, arm length and leg length are the three the rig reads as geometry.
## They are **drawn and nothing else** -- the manager never steps on court, so
## none of them reaches the simulator, and a body here is what you look like
## rather than what you are good at.
func _build_voli_choices() -> void:
	_manager_name_edit = LineEdit.new()
	_manager_name_edit.placeholder_text = "Your name"
	_manager_name_edit.custom_minimum_size = Vector2(0, 32)
	_manager_name_edit.text_changed.connect(func(text: String) -> void:
		manager_name = text
		manager_name_tracks_region = false
	)
	_row("Name", [_manager_name_edit], true)

	## One row of six, at the width that leaves the rail on screen.
	##
	## This was three columns for a while, which fitted horizontally and cost a
	## row of height -- and height was the binding constraint, not width: the
	## last control fell under the fold of a 720-high window, which is what this
	## project's own `viewport_height` is set to. Both dimensions are tight
	## enough here that a change to either has to be checked against the other.
	_body_row = GridContainer.new()
	_body_row.columns = 6
	_body_row.add_theme_constant_override("h_separation", 6)
	_body_row.add_theme_constant_override("v_separation", 6)
	var body_group := ButtonGroup.new()
	for body_type in BodyTypesScript.MODELLED:
		var button := Button.new()
		button.toggle_mode = true
		button.button_group = body_group
		button.custom_minimum_size = Vector2(84, 36)
		button.text = "%s\n%s" % [body_type, str(BODY_BLURBS.get(body_type, ""))]
		button.add_theme_font_size_override("font_size", 11)
		button.set_meta("value", body_type)
		button.pressed.connect(_select_body_type.bind(body_type))
		_body_row.add_child(button)
	_row("Body", [_body_row], false)

	## Variety is a Vegi question and only a Vegi question, so the row is hidden
	## for the five animal types rather than shown empty. Its label goes with it
	## -- a heading over nothing is worse than no heading.
	_produce_row = HBoxContainer.new()
	_produce_row.add_theme_constant_override("separation", 6)
	var produce_group := ButtonGroup.new()
	for produce_name in BodyTypesScript.PRODUCE:
		var button := Button.new()
		button.toggle_mode = true
		button.button_group = produce_group
		button.custom_minimum_size = Vector2(76, 30)
		## The produce names stay internal everywhere a player can read them --
		## see `BodyTypeModels.PRODUCE`. A Vegi is not "a Tomato", so the
		## varieties are numbered here rather than named.
		button.text = "Variety %d" % (BodyTypesScript.PRODUCE.find(produce_name) + 1)
		button.set_meta("value", produce_name)
		button.pressed.connect(_select_produce.bind(produce_name))
		_produce_row.add_child(button)
	_produce_line = _row("Build", [_produce_row], false)

	## Rebuilt whenever the palette table changes, which is whenever the body
	## type or the produce does -- a Feli's four colourways and a Pepper's five
	## are different tables and a row of stale swatches is a row that lies.
	_palette_row = HBoxContainer.new()
	_palette_row.add_theme_constant_override("separation", 6)
	_marking_row = HBoxContainer.new()
	_marking_row.add_theme_constant_override("separation", 6)
	_row("Colour", [_palette_row], false)
	_row("Coat", [_marking_row], false)

	_face_option = OptionButton.new()
	_face_option.custom_minimum_size = Vector2(170, 32)
	for face_name in FaceExpressionsScript.names():
		_face_option.add_item(face_name.capitalize())
		_face_option.set_item_metadata(_face_option.item_count - 1, face_name)
	_face_option.item_selected.connect(func(index: int) -> void:
		appearance["expression"] = str(_face_option.get_item_metadata(index))
		_refresh_preview()
	)

	## **Paired, and the pairing is by width rather than by meaning.**
	##
	## Nine full-width rows put the last three under the fold of a 720-high
	## window, which is the size this project's own `viewport_height` is set to --
	## so the controls that were hardest to find were the ones a player is most
	## likely to want. Two short controls on one line is the cheapest fix that
	## does not shrink anything below a comfortable target.
	_row("Height", [
		_slider("height_cm", ManagerProfile.HEIGHT_CM.x, ManagerProfile.HEIGHT_CM.y, 1.0),
		_inline_label("Arms"),
		_slider("arm_ratio", ManagerProfile.ARM_RATIO.x, ManagerProfile.ARM_RATIO.y, 0.005),
	], false)
	_row("Legs", [
		_slider("leg_ratio", ManagerProfile.LEG_RATIO.x, ManagerProfile.LEG_RATIO.y, 0.005),
	], false)

	_hand_row = HBoxContainer.new()
	_hand_row.add_theme_constant_override("separation", 6)
	var hand_group := ButtonGroup.new()
	for hand in ManagerProfile.HANDS:
		var button := Button.new()
		button.toggle_mode = true
		button.button_group = hand_group
		button.custom_minimum_size = Vector2(96, 32)
		button.text = hand.capitalize()
		button.set_meta("value", hand)
		button.pressed.connect(func() -> void:
			appearance["hand"] = hand
			_refresh_preview()
		)
		_hand_row.add_child(button)
	## Handedness is not decoration -- it is the hand the clipboard is mirrored
	## for -- which is why it sits with the body rather than in an options menu.
	_row("Face", [_face_option, _inline_label("Hand"), _hand_row], false)
	_build_preview_world()


## A second heading inside a row, for the pairs that share one.
func _inline_label(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.custom_minimum_size = Vector2(46, 30)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	return label


## One labelled row of the body form.
##
## Returns the row so a caller can hide the heading and the control together --
## a control with no heading and a heading with no control are both worse than
## an absent row.
func _row(label_text: String, controls: Array, stretch: bool) -> Control:
	var line := HBoxContainer.new()
	line.add_theme_constant_override("separation", 10)
	var label := Label.new()
	label.text = label_text
	label.custom_minimum_size = Vector2(78, 30)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	line.add_child(label)
	for control in controls:
		var node := control as Control
		if stretch:
			node.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		line.add_child(node)
	voli_controls.add_child(line)
	return line


## A slider over one appearance value, with the number beside it.
##
## The number is there because the ends of these ranges are not obvious: 150 cm
## and 220 cm are the bounds `PlayerActor3D` itself clamps to, and a slider whose
## value is invisible cannot be compared against a squad the player has yet to
## meet.
func _slider(key: String, low: float, high: float, step: float) -> Control:
	var line := HBoxContainer.new()
	line.add_theme_constant_override("separation", 10)
	line.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var slider := HSlider.new()
	slider.min_value = low
	slider.max_value = high
	slider.step = step
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.custom_minimum_size = Vector2(150, 28)
	slider.set_meta("appearance_key", key)
	var value_label := Label.new()
	value_label.custom_minimum_size = Vector2(84, 28)
	value_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	slider.value_changed.connect(func(value: float) -> void:
		appearance[key] = value
		value_label.text = _slider_caption(key, value)
		_refresh_preview()
	)
	line.add_child(slider)
	line.add_child(value_label)
	_slider_labels[key] = {"slider": slider, "label": value_label}
	return line


## What a slider's number says. Height is a measurement; the two proportions are
## not, and printing "1.05" beside "arm length" says nothing to anybody.
func _slider_caption(key: String, value: float) -> String:
	match key:
		"height_cm":
			return "%d cm" % roundi(value)
		"arm_ratio":
			return "%d cm span" % roundi(float(appearance.height_cm) * value)
		_:
			return "%+d%%" % roundi((value - 1.0) * 100.0)


## The little stage the body stands on.
##
## Built in code rather than in the scene because it is three nodes and a camera
## and none of them wants authoring: what the scene has to own is the
## `SubViewport`, which it does.
func _build_preview_world() -> void:
	var world := Node3D.new()
	world.name = "PreviewWorld"
	preview_viewport.add_child(world)
	preview_viewport.transparent_bg = true

	var environment := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_CANVAS
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("6d7d94")
	env.ambient_light_energy = 1.1
	environment.environment = env
	world.add_child(environment)

	var key_light := DirectionalLight3D.new()
	key_light.rotation_degrees = Vector3(-34.0, 142.0, 0.0)
	key_light.light_energy = 1.35
	world.add_child(key_light)

	var camera := Camera3D.new()
	## Framed on a 1.86 m default body with room above and below for the two
	## metres a slider can reach -- a camera framed on the default alone would
	## crop the tallest choice, which is the choice most worth looking at.
	camera.position = Vector3(0.0, 1.10, 3.55)
	camera.rotation_degrees = Vector3(-2.0, 0.0, 0.0)
	camera.fov = 36.0
	world.add_child(camera)

	_preview_pivot = Node3D.new()
	_preview_pivot.name = "Turntable"
	## PlayerActor3D faces -Z on court while this camera looks in from +Z. Turn
	## the body toward the person creating it before applying the small showroom
	## swing in `_process`.
	_preview_pivot.rotation_degrees.y = PREVIEW_FRONT_YAW_DEGREES
	world.add_child(_preview_pivot)
	_preview_actor = PlayerActorScene.instantiate()
	_preview_pivot.add_child(_preview_actor)


## Redraw the body from the current answers.
##
## Goes through `PlayerActor3D.configure` rather than reaching into the rig,
## which is the whole point of routing the appearance through the physical
## profile: the preview is the same code path the match court uses, so a body
## that looks right here looks right there.
func _refresh_preview() -> void:
	if _preview_actor == null:
		return
	var profile := ManagerProfile.appearance_profile(appearance)
	_preview_actor.configure(
		0, true, "", ManagerProfile.actor_hand(appearance), profile
	)


func _select_body_type(body_type: String) -> void:
	appearance["body_type"] = body_type
	## A palette index and a coat both belong to a table that just changed, and
	## an index carried across tables is a colour nobody chose. Reset to the
	## first entry, which is at least a colour this body has.
	appearance["palette_index"] = 0
	appearance["marking"] = "none"
	_sync_voli_controls()
	_refresh_preview()


func _select_produce(produce_name: String) -> void:
	appearance["produce"] = produce_name
	appearance["palette_index"] = 0
	_sync_voli_controls()
	_refresh_preview()


## Put the controls where the answers are.
##
## Called after any change that moves more than one row, and on reset. Rebuilds
## the two tables that depend on the body -- colourways and coats -- and leaves
## everything else to be selected rather than recreated.
func _sync_voli_controls() -> void:
	appearance = ManagerProfile.sanitise_appearance(appearance)
	var body_type := str(appearance.body_type)
	var is_vegi := body_type == "Vegi"
	_produce_line.visible = is_vegi
	_select_button_with_metadata(_produce_row, str(appearance.produce))

	var palette_key := BodyTypesScript.palette_key(
		body_type, str(appearance.produce)
	)
	for child in _palette_row.get_children():
		child.queue_free()
	var palette_group := ButtonGroup.new()
	for index in range(BodyTypesScript.palette_count(palette_key)):
		var colours: Dictionary = BodyTypesScript.chosen_palette(
			palette_key, 0, {"palette_index": index}
		)
		var swatch := Button.new()
		swatch.toggle_mode = true
		swatch.button_group = palette_group
		swatch.custom_minimum_size = Vector2(42, 30)
		swatch.set_meta("value", index)
		for state in ["normal", "hover", "pressed", "focus"]:
			swatch.add_theme_stylebox_override(state, _swatch_style(
				colours.get("skin", Color.WHITE),
				colours.get("crown", Color.BLACK),
				state == "pressed",
			))
		swatch.pressed.connect(func() -> void:
			appearance["palette_index"] = index
			_refresh_preview()
		)
		_palette_row.add_child(swatch)
		swatch.button_pressed = index == int(appearance.palette_index)

	for child in _marking_row.get_children():
		child.queue_free()
	var marking_group := ButtonGroup.new()
	for marking in BodyTypesScript.marking_options(body_type):
		var button := Button.new()
		button.toggle_mode = true
		button.button_group = marking_group
		button.custom_minimum_size = Vector2(70, 30)
		button.text = "Plain" if marking == "none" else marking.capitalize()
		button.set_meta("value", marking)
		button.pressed.connect(func() -> void:
			appearance["marking"] = marking
			_refresh_preview()
		)
		_marking_row.add_child(button)
	_select_button_with_metadata(_marking_row, str(appearance.marking))

	_select_button_with_metadata(_body_row, str(appearance.body_type))
	_select_button_with_metadata(_hand_row, str(appearance.hand))
	for index in range(_face_option.item_count):
		if str(_face_option.get_item_metadata(index)) == str(appearance.expression):
			_face_option.select(index)
	for key in _slider_labels:
		var entry: Dictionary = _slider_labels[key]
		var slider := entry.slider as HSlider
		slider.set_block_signals(true)
		slider.value = float(appearance.get(key, slider.value))
		slider.set_block_signals(false)
		(entry.label as Label).text = _slider_caption(key, slider.value)
	if _manager_name_edit != null and _manager_name_edit.text != manager_name:
		_manager_name_edit.set_block_signals(true)
		_manager_name_edit.text = manager_name
		_manager_name_edit.set_block_signals(false)


## A colourway drawn as itself.
##
## Skin fills and crown edges, which is the pairing the palette actually is --
## a swatch showing only the skin cannot tell a Tomato from a Pepper wearing the
## same red.
func _swatch_style(skin: Color, crown: Color, selected: bool) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = skin
	style.border_color = crown
	style.set_border_width_all(4)
	style.set_corner_radius_all(4)
	if selected:
		style.border_color = UIPalette.color(&"accent", light_mode_enabled)
		style.set_border_width_all(3)
		style.expand_margin_top = 3.0
		style.expand_margin_bottom = 3.0
	return style


## ## Major or minor, and then which one
##
## The tier was a suffix on six of fourteen tiles -- a "· minor" appended to a
## name -- and it is the largest single fact about a save: how many clubs there
## are, whether founding is on the table, whether your best volis are watched by
## academies that are not yours. A question answered by reading a badge is a
## question the interface declined to ask.
func _build_tier_choices() -> void:
	var group := ButtonGroup.new()
	for tier in [VolleyballRegions.TIER_MAJOR, VolleyballRegions.TIER_MINOR]:
		var button := Button.new()
		button.toggle_mode = true
		button.button_group = group
		button.custom_minimum_size = Vector2(300, 62)
		button.text = (
			"A MAJOR REGION\nSixnet programmes, real clubs, resources"
			if tier == VolleyballRegions.TIER_MAJOR else
			"A MINOR REGION\nNo bracket, one small club, and academies that are not yours"
		)
		button.set_meta("value", str(tier))
		button.pressed.connect(_select_tier.bind(tier))
		tier_row.add_child(button)


func _build_region_choices() -> void:
	region_grid.columns = 4


## Fill the grid with the chosen tier's regions.
##
## Rebuilt rather than filtered, because the two lists are different lengths and
## a grid of hidden tiles leaves holes in the rows.
func _fill_region_grid() -> void:
	for child in region_grid.get_children():
		child.queue_free()
	var group := ButtonGroup.new()
	var names := VolleyballRegions.names_in_tier(selected_tier)
	if not names.has(selected_region):
		selected_region = names[0]
		if identity_tracks_region:
			_set_principles(
				VolleyballRegions.preferred_principles(selected_region), true
			)
		_suggest_manager_name()
	for region_name in names:
		var button := Button.new()
		button.toggle_mode = true
		button.button_group = group
		button.custom_minimum_size = Vector2(190, 66)
		## The tier no longer needs saying on the tile: it is the question that
		## was just answered, and repeating it here is what made it read as
		## decoration the first time.
		button.text = "%s\n%s" % [region_name, _region_signature(region_name)]
		button.set_meta("value", region_name)
		button.pressed.connect(_select_region.bind(region_name))
		region_grid.add_child(button)
	_select_button_with_metadata(region_grid, selected_region)
	tier_hint.text = VolleyballRegions.definition(selected_region).tagline


func _build_type_choices() -> void:
	var group := ButtonGroup.new()
	## **Not club versus academy.** That pair described two clubs -- an
	## established one and a young one -- under a word that now means the region's
	## selection body, which is a thing you are chosen *by* and never a thing you
	## manage. `CLUBS_REGIONS_AND_THE_ROSTER_DECISION.md` §3 recuts it as the seat
	## you take, and the region you took it in supplies the rest of the
	## difficulty.
	##
	## Founding is the hard route and it belongs where the resources are: in a
	## major region you can take a berth at a club that has a squad, dorms and a
	## history, or start from nothing against clubs that have all three. In a
	## minor region you inherit the small club, and the difficulty there is a
	## different one -- your best volis are watched by academies that are not
	## yours.
	for type_name in ["Established", "Founded"]:
		var button := Button.new()
		button.toggle_mode = true
		button.button_group = group
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.custom_minimum_size = Vector2(280, 150)
		button.text = (
			"TAKE OVER A CLUB\nInherit a squad you did not pick\n10 volis · a going concern"
			if type_name == "Established" else
			"FOUND YOUR OWN\nFrom nothing, against clubs that have everything\n12 volis · younger, less standing, less money"
		)
		button.set_meta("value", type_name)
		button.pressed.connect(_select_type.bind(type_name))
		type_row.add_child(button)


func _build_identity_choices() -> void:
	preset_option.add_item("Regional Tradition")
	for preset_name in TeamPrinciplesModel.PRESET_NAMES:
		preset_option.add_item(preset_name)
	preset_option.add_item("Custom")
	preset_option.item_selected.connect(_preset_selected)
	identity_name_edit.text_changed.connect(func(_text: String) -> void:
		if preset_option.get_item_text(preset_option.selected) != "Custom":
			preset_option.select(preset_option.item_count - 1)
		identity_tracks_region = false
	)
	career_name_edit.text_changed.connect(func(_text: String) -> void:
		if current_step == step_panels.size() - 1: _refresh_review()
	)
	organization_name_edit.text_changed.connect(func(_text: String) -> void:
		if current_step == step_panels.size() - 1: _refresh_review()
	)
	for question in AXIS_QUESTIONS:
		var question_label := Label.new()
		question_label.text = str(question.question)
		question_label.custom_minimum_size = Vector2(220, 38)
		question_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		identity_tag_grid.add_child(question_label)
		var group := ButtonGroup.new()
		var axis_buttons: Array[Button] = []
		for choice in [
			{"label": question.low, "value": 0.2},
			{"label": question.middle, "value": 0.5},
			{"label": question.high, "value": 0.8},
		]:
			var button := Button.new()
			button.toggle_mode = true
			button.button_group = group
			button.custom_minimum_size = Vector2(104, 38)
			button.text = str(choice.label)
			button.pressed.connect(_tag_selected.bind(
				str(question.key), float(choice.value)
			))
			identity_tag_grid.add_child(button)
			axis_buttons.append(button)
		tag_buttons[str(question.key)] = axis_buttons


func _show_step() -> void:
	for index in range(step_panels.size()):
		step_panels[index].visible = index == current_step
		step_labels[index].modulate = UIPalette.color(
			&"accent" if index == current_step else &"ink_faint", light_mode_enabled
		)
	step_kicker.text = "QUESTION %d OF %d" % [current_step + 1, STEPS.size()]
	match current_step:
		0:
			question_title.text = "Who are you?"
			question_hint.text = "A voli like any other. None of this changes what your team can do -- it is what the rest of the game is looking at when it talks to you."
		1:
			question_title.text = "What should your team believe?"
			question_hint.text = "Choose a shortcut, then challenge any principle. Geography comes next; first say what you believe on its own terms."
		2:
			question_title.text = "Where does your volleyball begin?"
			question_hint.text = "First the kind of place, then the place. Review what that choice means for the principles you already chose."
			tier_hint.text = VolleyballRegions.definition(selected_region).tagline
			_refresh_alignment_preview()
		3:
			question_title.text = "What are you taking responsibility for?"
			question_hint.text = "A club is judged immediately. Founding one gets you nothing you did not build."
		4:
			question_title.text = "Put a name on the project."
			question_hint.text = "This is the signature attached to every result that follows."
			_refresh_review()
	previous_button.text = "Back to title" if current_step == 0 else "Previous"
	next_button.text = "Create career" if current_step == step_panels.size() - 1 \
		else ("Confirm region" if current_step == 2 else "Continue")


func _select_tier(tier: StringName) -> void:
	selected_tier = tier
	## Synced here rather than left to the button that was clicked, so a caller
	## setting the tier in code -- a probe, a restored save -- gets a row that
	## agrees with the grid under it.
	_select_button_with_metadata(tier_row, str(tier))
	_fill_region_grid()
	_refresh_alignment_preview()


func _select_region(region_name: String) -> void:
	selected_region = region_name
	if identity_tracks_region:
		_set_principles(VolleyballRegions.preferred_principles(selected_region), true)
	if manager_name_tracks_region:
		_suggest_manager_name()
	tier_hint.text = VolleyballRegions.definition(selected_region).tagline
	_refresh_alignment_preview()


## A name from the region you just said you were from.
##
## Offered rather than imposed, which is the whole of `suggested_name`'s
## contract: it is in the field when you arrive and you can type over it.
func _suggest_manager_name() -> void:
	manager_name = ManagerProfile.suggested_name(
		selected_region, absi(hash(selected_region))
	)
	if _manager_name_edit != null:
		_manager_name_edit.set_block_signals(true)
		_manager_name_edit.text = manager_name
		_manager_name_edit.set_block_signals(false)


func _select_type(type_name: String) -> void:
	selected_type = type_name


func _preset_selected(index: int) -> void:
	var choice := preset_option.get_item_text(index)
	if choice == "Custom":
		identity_tracks_region = false
		return
	if choice == "Regional Tradition":
		identity_tracks_region = true
		_set_principles(VolleyballRegions.preferred_principles(selected_region), true)
	else:
		identity_tracks_region = false
		_set_principles(TeamPrinciplesModel.for_identity(choice), true)


func _tag_selected(axis_name: String, value: float) -> void:
	selected_values[axis_name] = value
	identity_tracks_region = false
	preset_option.select(preset_option.item_count - 1)


func _set_principles(principles: TeamPrinciples, update_name: bool) -> void:
	selected_values = principles.to_dict()
	selected_values.erase("preset_name")
	if update_name:
		identity_name_edit.set_block_signals(true)
		identity_name_edit.text = str(principles.preset_name)
		identity_name_edit.set_block_signals(false)
	_sync_tag_buttons()


func _sync_tag_buttons() -> void:
	for axis_name in tag_buttons:
		var value := float(selected_values.get(axis_name, 0.5))
		var target_index := 0 if value < 0.35 else (2 if value > 0.65 else 1)
		var buttons: Array = tag_buttons[axis_name]
		for index in range(buttons.size()):
			(buttons[index] as Button).button_pressed = index == target_index


func _refresh_alignment_preview() -> void:
	var principles := TeamPrinciplesModel.custom(_identity_name(), selected_values)
	var state := VolleyballRegions.starting_identity_state(selected_region, principles)
	%AlignmentPreview.text = "CONFIRM %s\nYour principles begin at %d%% regional alignment · %d%% tactical familiarity · %d%% squad cohesion.\nContinue to accept this starting relationship." % [
		selected_region.to_upper(),
		roundi(float(state.alignment) * 100.0),
		roundi(float(state.familiarity) * 100.0),
		roundi(float(state.cohesion) * 100.0),
	]


func _refresh_review() -> void:
	var principles := TeamPrinciplesModel.custom(_identity_name(), selected_values)
	var state := VolleyballRegions.starting_identity_state(selected_region, principles)
	review_text.text = "[font_size=24][b]%s[/b][/font_size]\n%s · %s · %s\n\n[b]%s[/b]\n%s\n\n[b]%s[/b] of %s\nRegional alignment %d%%\nTactical familiarity %d%% · Cohesion %d%%" % [
		organization_name_edit.text if not organization_name_edit.text.is_empty() else "Unnamed organization",
		selected_region,
		"major region" if VolleyballRegions.is_major(selected_region) else "minor region",
		selected_type, principles.preset_name, _identity_summary(),
		manager_name if not manager_name.is_empty() else "Unnamed manager",
		VolleyballRegions.demonym(selected_region),
		roundi(float(state.alignment) * 100.0),
		roundi(float(state.familiarity) * 100.0), roundi(float(state.cohesion) * 100.0),
	]


func _identity_summary() -> String:
	var tags: Array[String] = []
	for question in AXIS_QUESTIONS:
		var value := float(selected_values.get(str(question.key), 0.5))
		tags.append(str(question.low) if value < 0.35 else (
			str(question.high) if value > 0.65 else str(question.middle)
		))
	return " · ".join(tags)


func _identity_name() -> String:
	var identity_name := identity_name_edit.text.strip_edges()
	return identity_name if not identity_name.is_empty() else "Custom Identity"


func _previous() -> void:
	error_label.text = ""
	if current_step == 0:
		back_requested.emit()
		return
	current_step -= 1
	_show_step()


func _next() -> void:
	error_label.text = ""
	if current_step < step_panels.size() - 1:
		current_step += 1
		_show_step()
		return
	_create_career()


func _create_career() -> void:
	var error := CareerManager.create_career(
		career_name_edit.text, organization_name_edit.text,
		selected_region, selected_type, _identity_name(), selected_values,
		{
			"name": manager_name,
			## One region answers both questions today. `CHARACTER_CREATION.md`
			## wants them to differ often -- a Landavoli managing in Taktikã is
			## the position most managers in a real league are in -- and this is
			## the seam a second picker would land on.
			"region": selected_region,
			"hand": str(appearance.hand),
			"appearance": appearance.duplicate(true),
		},
	)
	error_label.text = error
	if error.is_empty():
		career_created.emit()


func _select_button_with_metadata(container: Container, value: String) -> void:
	for child in container.get_children():
		if child is Button:
			(child as Button).button_pressed = str(child.get_meta("value", "")) == value


func _region_signature(region_name: String) -> String:
	match region_name:
		"Spëddigh": return "work · tempo"
		"Pāwa Hitō": return "stamina · transition"
		"Blôc du Larg": return "structure · block"
		"Xérvu": return "serve · variation"
		"Taktikã": return "intellect · discipline"
		"Ĭspayk": return "power · pins"
		"A'ace": return "stars · ambition"
		"Tãul ys Feynt": return "wrists · patience"
		"Lo-ong Ralī": return "legs · altitude"
		"Bompaçao": return "first contact"
		"Rhėn Tempaol": return "early · one tempo"
		"Kutré Lyn": return "corners · touch"
		"Zaitgaist": return "whatever just won"
		_: return "balance · breadth"


func set_light_mode(enabled: bool) -> void:
	light_mode_enabled = enabled
	%Background.color = UIPalette.color(&"canvas", enabled)
	%AccentBand.color = UIPalette.color(&"accent", enabled)
	question_hint.modulate = UIPalette.color(&"ink_muted", enabled)
	tier_hint.modulate = UIPalette.color(&"ink_muted", enabled)
	step_kicker.modulate = UIPalette.color(&"accent", enabled)
	error_label.modulate = UIPalette.color(&"danger", enabled)
	%AlignmentPreview.modulate = UIPalette.color(&"accent_alt", enabled)
	if not step_labels.is_empty():
		_show_step()
