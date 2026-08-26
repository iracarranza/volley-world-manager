class_name VolleyballTitleScreen
extends Control

signal new_career_requested
signal career_load_requested(save_id: String)
signal theme_requested(theme_name: String)
signal exit_requested

const CareerManagerScript := preload("res://scripts/managers/career_manager.gd")
const UIPalette := preload("res://scripts/data/ui_palette.gd")

const BRAND_VEIL_OPACITY_DARK := 0.895
const BRAND_VEIL_OPACITY_LIGHT := 0.87
const BACKDROP_WASH_OPACITY := 0.08
const RIGHT_BAND_OPACITY := 0.035

@onready var CareerManager: CareerManagerScript = get_node("/root/CareerManager")
@onready var save_list: ItemList = %SaveList
@onready var save_detail: Label = %SaveDetail
@onready var load_selected_button: Button = %LoadSelectedButton
@onready var delete_button: Button = %DeleteButton
@onready var load_menu_button: Button = %LoadMenuButton
@onready var continue_button: Button = %ContinueButton
@onready var theme_option: OptionButton = %ThemeOption
@onready var desk_surface: TitleDeskSurface = %TitleDeskSurface
@onready var content: MarginContainer = %Content

var saves: Array[Dictionary] = []
var _brand_veil: ColorRect = null
var _light_mode := false


func _ready() -> void:
	_install_live_office_overlay()
	%NewCareerButton.pressed.connect(func() -> void: new_career_requested.emit())
	load_menu_button.pressed.connect(_open_load_menu)
	continue_button.pressed.connect(_continue_last_played)
	%OptionsButton.pressed.connect(func() -> void: %OptionsDialog.popup_centered())
	%ExitButton.pressed.connect(func() -> void: exit_requested.emit())
	load_selected_button.pressed.connect(_load_selected)
	%LoadDialog.close_requested.connect(%LoadDialog.hide)
	delete_button.pressed.connect(_confirm_delete)
	%DeleteConfirmation.confirmed.connect(_delete_selected)
	save_list.item_selected.connect(_select_save)
	theme_option.add_item("Mikasa")
	theme_option.add_item("Molten")
	theme_option.item_selected.connect(_theme_selected)
	refresh_saves()
	call_deferred("enforce_live_office_overlay")


func _install_live_office_overlay() -> void:
	if desk_surface != null:
		desk_surface.visible = false
	%CourtLineA.visible = false
	%CourtLineB.visible = false
	_brand_veil = ColorRect.new()
	_brand_veil.name = "BrandVeil"
	_brand_veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_brand_veil.set_anchors_preset(Control.PRESET_FULL_RECT)
	_brand_veil.anchor_right = 0.56
	_brand_veil.grow_horizontal = Control.GROW_DIRECTION_END
	add_child(_brand_veil)
	move_child(_brand_veil, 1)


func enforce_live_office_overlay() -> void:
	# UIStyleSystem owns broad screen styling and can touch the old decorative
	# controls after this screen first configures itself. Reassert the title-only
	# exceptions after that pass: no duplicate desk, and translucent room veils.
	if desk_surface != null:
		desk_surface.visible = false
	%CourtLineA.visible = false
	%CourtLineB.visible = false
	_apply_overlay_palette()


func refresh_saves() -> void:
	saves = CareerManager.list_save_metadata()
	save_list.clear()
	for metadata in saves:
		save_list.add_item("%s  /  %s" % [
			metadata.get("career_name", "Career"),
			metadata.get("organization_name", "Organization"),
		])
	load_menu_button.disabled = saves.is_empty()
	load_selected_button.disabled = saves.is_empty()
	delete_button.disabled = saves.is_empty()
	%SaveCount.text = "%02d ACTIVE FILES" % saves.size()
	_refresh_continue()
	if saves.is_empty():
		save_detail.text = "No careers have been written yet."
	else:
		save_list.select(0)
		_select_save(0)


func _refresh_continue() -> void:
	continue_button.visible = not saves.is_empty()
	if saves.is_empty():
		return
	var metadata := saves[0]
	%ContinueTitle.text = str(metadata.get("organization_name", "Organization"))
	%ContinueDetail.text = "%s  ·  next: %s" % [
		metadata.get("date", "Week 1"), metadata.get("next_fixture", "None"),
	]


func _continue_last_played() -> void:
	if saves.is_empty():
		return
	career_load_requested.emit(str(saves[0].save_id))


func set_theme_name(theme_name: String) -> void:
	_light_mode = theme_name == "light"
	theme_option.select(1 if _light_mode else 0)
	_apply_overlay_palette()
	%AccentBar.color = UIPalette.color(&"accent", _light_mode)
	%Title.modulate = UIPalette.color(&"ink", _light_mode)
	%Edition.modulate = UIPalette.color(&"accent", _light_mode)
	_tint_menu(_light_mode)
	# Application's style walk follows this call. Reapply the deliberate alpha
	# values one frame later so generic ColorRect styling cannot make them opaque.
	call_deferred("enforce_live_office_overlay")


func _apply_overlay_palette() -> void:
	var canvas := UIPalette.color(&"canvas", _light_mode)
	var canvas_alt := UIPalette.color(&"canvas_alt", _light_mode)
	%Background.color = Color(canvas, BACKDROP_WASH_OPACITY)
	%CourtBand.color = Color(canvas_alt, RIGHT_BAND_OPACITY)
	if _brand_veil != null:
		_brand_veil.color = Color(canvas, BRAND_VEIL_OPACITY_LIGHT if _light_mode else BRAND_VEIL_OPACITY_DARK)


func play_desk_departure() -> void:
	if not visible:
		return
	var tween := create_tween().set_parallel(true)
	tween.set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(%MenuPanel, "modulate:a", 0.0, 0.82).set_delay(0.18)
	tween.tween_property(%Brand, "modulate:a", 0.0, 0.78).set_delay(0.28)
	if _brand_veil != null:
		tween.tween_property(_brand_veil, "modulate:a", 0.0, 1.18).set_delay(0.12)
	tween.tween_property(%Background, "modulate:a", 0.0, 1.10)
	tween.tween_property(%CourtBand, "modulate:a", 0.0, 0.92)
	await tween.finished


func reset_departure() -> void:
	%MenuPanel.modulate = Color.WHITE
	%Brand.modulate = Color.WHITE
	%Background.modulate = Color.WHITE
	%CourtBand.modulate = Color.WHITE
	if _brand_veil != null:
		_brand_veil.modulate = Color.WHITE
	enforce_live_office_overlay()


func _tint_menu(light_mode: bool) -> void:
	var ink := UIPalette.color(&"ink", light_mode)
	var muted := UIPalette.color(&"ink_muted", light_mode)
	var accent := UIPalette.color(&"accent", light_mode)
	var stitch := UIPalette.color(&"accent_alt", light_mode)
	var panel: StyleBoxFlat = %MenuPanel.get_theme_stylebox(&"panel")
	if panel != null:
		panel.bg_color = Color(UIPalette.color(&"canvas", light_mode), 0.965)
		panel.border_color = Color(accent, 0.45)
	for button: Button in [%NewCareerButton, %LoadMenuButton, %OptionsButton, %ExitButton]:
		var normal: StyleBoxFlat = button.get_theme_stylebox(&"normal")
		if normal != null:
			normal.bg_color = Color(UIPalette.color(&"surface", light_mode), 0.97)
			normal.border_color = Color(accent, 0.65)
		var hover: StyleBoxFlat = button.get_theme_stylebox(&"hover")
		if hover != null:
			hover.bg_color = UIPalette.color(&"surface_hover", light_mode)
			hover.border_color = accent
		button.add_theme_color_override(&"font_color", ink)
		button.add_theme_color_override(&"font_hover_color", ink)
		button.add_theme_color_override(&"font_pressed_color", ink)
	var card: StyleBoxFlat = continue_button.get_theme_stylebox(&"normal")
	if card != null:
		card.bg_color = Color(UIPalette.color(&"surface", light_mode), 0.97)
		card.border_color = Color(stitch, 0.5)
	var card_hover: StyleBoxFlat = continue_button.get_theme_stylebox(&"hover")
	if card_hover != null:
		card_hover.bg_color = UIPalette.color(&"surface_hover", light_mode)
		card_hover.border_color = stitch
	%MenuKicker.add_theme_color_override(&"font_color", accent)
	%MenuTitle.add_theme_color_override(&"font_color", ink)
	%Subtitle.add_theme_color_override(&"font_color", muted)
	%SaveCount.add_theme_color_override(&"font_color", UIPalette.color(&"ink_faint", light_mode))
	%ContinueKicker.add_theme_color_override(&"font_color", accent)
	%ContinueTitle.add_theme_color_override(&"font_color", ink)
	%ContinueDetail.add_theme_color_override(&"font_color", muted)


func _open_load_menu() -> void:
	refresh_saves()
	%LoadDialog.popup_centered_ratio(0.68)


func _select_save(index: int) -> void:
	if index < 0 or index >= saves.size():
		return
	var metadata := saves[index]
	save_detail.text = "%s · %s\n%s identity · Reputation %d\n%s · Next: %s" % [
		metadata.get("organization_type", "Club"), metadata.get("region", "Region"),
		metadata.get("identity", "Balanced"), int(metadata.get("reputation", 0)),
		metadata.get("date", "Week 1"), metadata.get("next_fixture", "None"),
	]


func _load_selected() -> void:
	var selected := save_list.get_selected_items()
	if not selected.is_empty():
		%LoadDialog.hide()
		career_load_requested.emit(str(saves[selected[0]].save_id))


func _confirm_delete() -> void:
	if not save_list.get_selected_items().is_empty():
		%DeleteConfirmation.popup_centered()


func _delete_selected() -> void:
	var selected := save_list.get_selected_items()
	if selected.is_empty():
		return
	var error: String = CareerManager.delete_save(str(saves[selected[0]].save_id))
	if not error.is_empty():
		save_detail.text = error
	else:
		refresh_saves()


func _theme_selected(index: int) -> void:
	theme_requested.emit("light" if index == 1 else "dark")
