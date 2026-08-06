class_name VolleyballUIStyleSystem
extends RefCounted

const UIPalette := preload("res://scripts/data/ui_palette.gd")
const UIHalftone := preload("res://scripts/data/ui_halftone.gd")
const UIInkOutline := preload("res://scenes/components/ink_outline.gd")

## Which surfaces get a drawn edge.
##
## Every panel tier, and the completeness is the point. This started as three of
## the four on the theory that the largest surface wanted the quietest edge --
## which was a guess, and wrong in the direction that matters: with the cards
## drawn by hand and the frame around them cut by machine, the *mixture* is what
## the eye catches. One instrument drew the page or it did not.
##
## `FrontmostPanel` is the exception and cannot be otherwise: it dresses
## `PopupPanel`, which derives from `Window`, has no `CanvasItem` to draw
## through, and keeps its stylebox border for that reason.
const INKED_TIERS: Array[StringName] = [
	&"CardPanel", &"DashboardCard", &"InsetPanel", &"RaisedPanel",
	&"PrimaryAction", &"SecondaryAction", &"QuietAction", &"DangerAction",
	&"NavAction", &"ChoiceChip",
]

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
		## Not screened, and it cannot be: `PopupPanel` derives from `Window`, so
		## it is not a `CanvasItem` and has no material to draw itself through.
		## Its contents are ordinary panels and get the treatment on their own.
		return
	if node is ColorRect:
		_style_color_rect(node as ColorRect, light_mode)
	if not node is Control:
		return
	var control := node as Control
	## Opted out, and the escape hatch is deliberate.
	##
	## This pass strips *every* colour override in the tree on the theory that a
	## hand-set colour is legacy presentation the theme should own. That is right
	## for a label someone tinted once and forgot, and wrong for a colour that
	## carries meaning -- a grade band, a severity, a per-datum state. Those have
	## to be overrides, because a theme variation is per widget *kind* and the
	## whole point is that two identical widgets differ by their data.
	##
	## The roster's attribute band was the case that found this. Every value
	## carried its grade colour and every one was wiped and repainted the same
	## teal, because the labels are named "Value" and this file gives anything
	## containing "Value" the StatLabel variation. The numbers looked styled and
	## said nothing.
	##
	## The guard has to sit **above the strip**, not between the strip and the
	## variation. Placed below it, an exempt label still had its colours wiped
	## and merely avoided being repainted teal -- so whether the grade colours
	## survived came down to whether the roster happened to refill after the
	## styling pass ran, which is not a thing to leave to ordering.
	if control.has_meta("ui_style_exempt"):
		return
	_clear_legacy_presentation_overrides(control)
	if control is Button:
		_style_button(control as Button)
		_screen_surface(control, light_mode)
	elif control is Label:
		_style_label(control as Label)
	elif control is PanelContainer:
		_style_panel(control as PanelContainer)
		_screen_surface(control, light_mode)
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


## Lay the halftone screen over a surface, reading the tier the lines above just
## assigned to it.
##
## Deliberately after the variation rather than beside it, so there is exactly
## one place that decides what a panel *is* and this only asks. A tier with no
## entry in `UIHalftone.TIERS` clears the material instead of leaving whatever
## was there, because the style pass runs again on every theme switch and a
## surface that stops being screened has to actually stop.
static func _screen_surface(control: Control, light_mode: bool) -> void:
	control.material = UIHalftone.material_for(
		control.theme_type_variation, light_mode
	)
	_ink_surface(control)


## Give this surface a drawn edge, once.
##
## Added as a child rather than painted by the panel itself, because a
## `PanelContainer` draws its stylebox *under* its contents and an edge drawn
## there would be covered by whatever the card holds. The outline is marked
## exempt so the next style pass walks straight past it, and reused rather than
## recreated so repeated passes -- a theme switch, a resize -- do not stack
## twenty of them on one card.
static func _ink_surface(control: Control) -> void:
	var wanted := control.theme_type_variation in INKED_TIERS
	var existing := control.get_node_or_null("InkOutline") as UIInkOutline
	if not wanted:
		if existing != null:
			existing.queue_free()
		return
	if existing != null:
		existing.queue_redraw()
		return
	var outline := UIInkOutline.new()
	outline.name = "InkOutline"
	## Seeded from the panel's own name, so a card's edge is stable across runs
	## and two cards side by side never draw the same imperfection.
	outline.ink_seed = int(String(control.name).hash() & 0x7FFFFFFF)
	control.add_child(outline)


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
	elif button.has_method("set_summary") or node_name.ends_with("Card"):
		## Matched on what the button *is*, not on what the scene file called it.
		##
		## This read `node_name == "DashboardCard"`, which is the name of the root
		## node inside `dashboard_card.tscn` -- and an instanced scene takes the
		## name its parent gives it. Every card on the dashboard is called
		## `RosterCard`, `TeamCard`, `ClubCard` and so on, so the condition never
		## fired once and all seven rendered as ordinary secondary buttons. The
		## `DashboardCard` variation is defined in both themes and had never been
		## reachable.
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
		label.rotation_degrees = -1.0 if node_name.length() % 2 == 0 else 0.8
	elif node_name.ends_with("Title") or node_name in ["SectionTitle", "CaptionLabel"]:
		label.theme_type_variation = &"SectionHeading"
	elif node_name.contains("Kicker") or node_name.contains("Eyebrow") \
			or node_name in ["Edition", "Mark", "Prompt", "ModeLabel"]:
		label.theme_type_variation = &"EyebrowLabel"
		label.rotation_degrees = -0.7 if node_name.length() % 2 == 0 else 0.7
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
	elif node_name.ends_with("Strip") or node_name.ends_with("Bar"):
		## A bar is where a control lives, not a surface in its own right.
		##
		## `NavStrip` holds one button and a line of hint text, and drawing an
		## edge around it put a second pen line 12 px outside the button's own --
		## the doubled-line problem again, arriving from the opposite direction
		## this time. The button has to keep its edge, because the edge is what
		## says it can be pressed; so the wrapper gives up its own.
		##
		## Matched on the suffix rather than on the one node that has the problem,
		## because the mistake is structural -- a panel whose only content is a
		## control -- and the next one will be named the same way.
		panel.theme_type_variation = &"BareRegion"
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
