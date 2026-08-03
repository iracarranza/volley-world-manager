class_name VolleyballUIStyleSystem
extends RefCounted

const UIPalette := preload("res://scripts/data/ui_palette.gd")

const PRIMARY_ACTIONS := [
	"NewCareerButton", "NextButton", "CreateCareerButton", "AdvanceWeekButton",
	"PlayMatchButton", "CallPlayButton", "SavePlayButton", "ApplyTrainingButton",
	"SignButton", "LoadSelectedButton",
]
const QUIET_ACTIONS := [
	"CancelButton", "PreviousButton", "CloseButton", "TitleButton", "SaveButton",
	"CloseAttributeWheelButton", "ClosePlayerDossierButton", "ReplayButton",
]
const DANGER_ACTIONS := ["DeleteButton", "ExitButton"]


static func apply(root: Node, light_mode: bool) -> void:
	_style_node(root, light_mode)
	for child in root.get_children():
		apply(child, light_mode)


static func reveal(screen: Control) -> void:
	var resting_position := screen.position
	screen.modulate.a = 0.0
	screen.position = resting_position + Vector2(0.0, 10.0)
	var tween := screen.create_tween().set_parallel(true)
	tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(screen, "modulate:a", 1.0, 0.20)
	tween.tween_property(screen, "position", resting_position, 0.26)


static func _style_node(node: Node, light_mode: bool) -> void:
	if node is PopupPanel:
		(node as PopupPanel).theme_type_variation = &"FrontmostPanel"
		return
	if node is ColorRect:
		_style_color_rect(node as ColorRect, light_mode)
	if not node is Control:
		return
	var control := node as Control
	_clear_legacy_presentation_overrides(control)
	if control is Button:
		_style_button(control as Button)
	elif control is Label:
		_style_label(control as Label)
	elif control is PanelContainer:
		_style_panel(control as PanelContainer)
	elif control is RichTextLabel:
		control.theme_type_variation = &"BodyCopy"
	elif control is ItemList:
		control.theme_type_variation = &"DataList"


static func _clear_legacy_presentation_overrides(control: Control) -> void:
	for property in control.get_property_list():
		var property_name := str(property.name)
		if property_name.begins_with("theme_override_colors/"):
			control.remove_theme_color_override(
				StringName(property_name.trim_prefix("theme_override_colors/"))
			)
		elif property_name.begins_with("theme_override_styles/"):
			control.remove_theme_stylebox_override(
				StringName(property_name.trim_prefix("theme_override_styles/"))
			)


static func _style_button(button: Button) -> void:
	var node_name := String(button.name)
	if node_name in PRIMARY_ACTIONS:
		button.theme_type_variation = &"PrimaryAction"
	elif node_name in DANGER_ACTIONS:
		button.theme_type_variation = &"DangerAction"
	elif node_name in QUIET_ACTIONS:
		button.theme_type_variation = &"QuietAction"
	elif node_name.ends_with("Nav") or node_name in ["CurrentSectionButton", "ThemeToggle"]:
		button.theme_type_variation = &"NavAction"
	elif node_name == "DashboardCard":
		button.theme_type_variation = &"DashboardCard"
	elif button.toggle_mode:
		button.theme_type_variation = &"ChoiceChip"
	else:
		button.theme_type_variation = &"SecondaryAction"


static func _style_label(label: Label) -> void:
	var node_name := String(label.name)
	if node_name in ["Title", "RailTitle", "QuestionTitle", "OrganizationLabel"] \
			or node_name.ends_with("ScreenTitle"):
		label.theme_type_variation = &"DisplayHeading"
	elif node_name.ends_with("Title") or node_name in ["SectionTitle", "CaptionLabel"]:
		label.theme_type_variation = &"SectionHeading"
	elif node_name.contains("Kicker") or node_name.contains("Eyebrow") \
			or node_name in ["Edition", "Mark", "Prompt", "ModeLabel"]:
		label.theme_type_variation = &"EyebrowLabel"
	elif node_name.contains("Status") or node_name.contains("Score") \
			or node_name.contains("Date") or node_name.contains("Value"):
		label.theme_type_variation = &"StatLabel"
	elif node_name.contains("Hint") or node_name.contains("Summary") \
			or node_name.contains("Detail") or node_name.contains("Context"):
		label.theme_type_variation = &"MutedLabel"


static func _style_panel(panel: PanelContainer) -> void:
	var node_name := String(panel.name)
	if node_name in ["ContentPanel", "QuestionPanel", "MenuPanel"]:
		panel.theme_type_variation = &"RaisedPanel"
	elif node_name.contains("Preview") or node_name.contains("News") \
			or node_name.contains("Placeholder"):
		panel.theme_type_variation = &"InsetPanel"
	else:
		panel.theme_type_variation = &"CardPanel"


static func _style_color_rect(rect: ColorRect, light_mode: bool) -> void:
	var node_name := String(rect.name)
	if node_name in ["Background", "Backdrop"]:
		rect.color = UIPalette.color(&"canvas", light_mode)
	elif node_name in ["CourtBand"]:
		rect.color = UIPalette.color(&"canvas_alt", light_mode)
	elif node_name in ["AccentBar", "AccentBand"]:
		rect.color = UIPalette.color(&"accent", light_mode)
	elif node_name.contains("Underlay"):
		rect.color = UIPalette.color(&"scrim", light_mode)
	elif node_name.contains("Rule"):
		rect.color = UIPalette.color(&"accent_alt", light_mode)
